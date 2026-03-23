import Foundation

// AppLogger is available globally, no import needed

enum SecurityDataGroup: CaseIterable {
    case details
    case priceHistory
    case transactions
    case taxLots
    case orderRecommendations
}

/// Tab / toolbar icon tint for a security data group (foreground load vs prefetch vs done).
enum SecurityGroupLoadIndicator: Equatable {
    case foregroundInFlight
    case prefetchInFlight
    case ready
}

enum SecurityDataLoadState: Equatable {
    case idle
    /// User-visible / foreground fetch (e.g. current symbol or tab-on-demand).
    case loading(Date)
    /// Background prefetch for cache; shown as a distinct tab icon state.
    case loadingPrefetch(Date)
    case loaded(Date)
    case failed(Date, message: String)

    var isLoading: Bool {
        switch self {
        case .loading, .loadingPrefetch:
            return true
        default:
            return false
        }
    }

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

/// Snapshot of the data required to render the position detail tabs for a security.
struct SecurityDataSnapshot {
    let symbol: String
    var fetchedAt: Date
    var priceHistory: CandleList?
    var transactions: [Transaction]?
    var quoteData: QuoteData?
    var atrValue: Double?
    var taxLotData: [SalesCalcPositionsRecord]?
    var sharesAvailableForTrading: Double?
    var recommendedSellOrders: [SalesCalcResultsRecord]?
    var recommendedBuyOrders: [BuyOrderRecord]?
    var loadStates: [SecurityDataGroup: SecurityDataLoadState]

    init(symbol: String,
         fetchedAt: Date = Date(),
         priceHistory: CandleList? = nil,
         transactions: [Transaction]? = nil,
         quoteData: QuoteData? = nil,
         atrValue: Double? = nil,
         taxLotData: [SalesCalcPositionsRecord]? = nil,
         sharesAvailableForTrading: Double? = nil,
         recommendedSellOrders: [SalesCalcResultsRecord]? = nil,
         recommendedBuyOrders: [BuyOrderRecord]? = nil,
         loadStates: [SecurityDataGroup: SecurityDataLoadState] = [:]) {
        self.symbol = symbol
        self.fetchedAt = fetchedAt
        self.priceHistory = priceHistory
        self.transactions = transactions
        self.quoteData = quoteData
        self.atrValue = atrValue
        self.taxLotData = taxLotData
        self.sharesAvailableForTrading = sharesAvailableForTrading
        self.recommendedSellOrders = recommendedSellOrders
        self.recommendedBuyOrders = recommendedBuyOrders

        var resolvedStates = loadStates
        for group in SecurityDataGroup.allCases {
            if resolvedStates[group] == nil {
                resolvedStates[group] = .idle
            }
        }
        self.loadStates = resolvedStates
    }

    func loadState(for group: SecurityDataGroup) -> SecurityDataLoadState {
        loadStates[group] ?? .idle
    }

    func hasData(for group: SecurityDataGroup) -> Bool {
        switch group {
        case .details:
            return quoteData != nil
        case .priceHistory:
            return priceHistory != nil
        case .transactions:
            return transactions != nil
        case .taxLots:
            return taxLotData != nil && sharesAvailableForTrading != nil
        case .orderRecommendations:
            return recommendedSellOrders != nil && recommendedBuyOrders != nil
        }
    }

    func isLoaded(_ group: SecurityDataGroup) -> Bool {
        if case .loaded = loadState(for: group) { return true }
        return false
    }

    func isLoading(_ group: SecurityDataGroup) -> Bool {
        switch loadState(for: group) {
        case .loading, .loadingPrefetch:
            return true
        case .idle:
            return !hasData(for: group)
        case .failed, .loaded:
            return false
        }
    }

    /// Priority: foreground work (red) > prefetch (amber) > ready (green), for tab icons.
    func groupLoadIndicator(for group: SecurityDataGroup) -> SecurityGroupLoadIndicator {
        switch loadState(for: group) {
        case .loading:
            return .foregroundInFlight
        case .loadingPrefetch:
            return .prefetchInFlight
        case .loaded:
            return .ready
        case .failed:
            return .foregroundInFlight
        case .idle:
            return hasData(for: group) ? .ready : .foregroundInFlight
        }
    }

    func combinedGroupLoadIndicator(groups: [SecurityDataGroup]) -> SecurityGroupLoadIndicator {
        let parts = groups.map { groupLoadIndicator(for: $0) }
        if parts.contains(.foregroundInFlight) { return .foregroundInFlight }
        if parts.contains(.prefetchInFlight) { return .prefetchInFlight }
        return .ready
    }

    var isFullyLoaded: Bool {
        SecurityDataGroup.allCases.allSatisfy { isLoaded($0) }
    }
}

/// LRU cache that keeps recently loaded security detail data in memory.
final class SecurityDataCacheManager {
    static let shared = SecurityDataCacheManager()

    // Cache size: 5 securities to improve responsiveness and reduce memory usage
    // Reduced from 10 to prioritize GUI responsiveness over cache size
    private let maxCacheSize = 5
    private var cache: [String: SecurityDataSnapshot] = [:]
    private var accessOrder: [String] = []
    private let lock = NSLock()

    /// When true, background prefetch must not mutate this cache — holdings list order/symbol membership may be inconsistent until async sort finishes.
    private var suppressPrefetchCacheWrites = false

    private init() {}

    /// Called from `HoldingsView` around async `performSort` so prefetch does not compete with sorting.
    func setHoldingsListSortInProgress(_ inProgress: Bool) {
        lock.lock()
        defer { lock.unlock() }
        suppressPrefetchCacheWrites = inProgress
    }

    /// Prefetch consults this before `markLoading` / `markLoaded` / eviction side effects.
    var isPrefetchCacheSuppressed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return suppressPrefetchCacheWrites
    }

    /// When prefetch is aborted mid-flight (e.g. holdings list started sorting), drop `.loading` for groups that never received data so UI can retry.
    func revertPrefetchLoadingStates(symbol: String, groups: [SecurityDataGroup]) {
        update(symbol: symbol) { snapshot in
            for group in groups {
                switch snapshot.loadStates[group] ?? .idle {
                case .loading, .loadingPrefetch:
                    if !snapshot.hasData(for: group) {
                        snapshot.loadStates[group] = .idle
                    }
                default:
                    break
                }
            }
        }
    }

    func snapshot(for symbol: String) -> SecurityDataSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        guard var snapshot = cache[symbol] else {
            return nil
        }

        touch(symbol: symbol)
        snapshot.loadStates = normalizedStates(from: snapshot.loadStates)
        cache[symbol] = snapshot
        return snapshot
    }

    @discardableResult
    func update(symbol: String, updateBlock: (inout SecurityDataSnapshot) -> Void) -> SecurityDataSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = cache[symbol] ?? SecurityDataSnapshot(symbol: symbol)
        updateBlock(&snapshot)
        snapshot.loadStates = normalizedStates(from: snapshot.loadStates)
        cache[symbol] = snapshot
        touch(symbol: symbol)
        trimIfNeeded()
        return snapshot
    }

    @discardableResult
    func markLoading(symbol: String, groups: [SecurityDataGroup]) -> SecurityDataSnapshot {
        update(symbol: symbol) { snapshot in
            let now = Date()
            for group in groups {
                snapshot.loadStates[group] = .loading(now)
            }
        }
    }

    /// Marks groups as loading for background prefetch (amber tab icons vs red foreground loads).
    @discardableResult
    func markLoadingPrefetch(symbol: String, groups: [SecurityDataGroup]) -> SecurityDataSnapshot {
        update(symbol: symbol) { snapshot in
            let now = Date()
            for group in groups {
                snapshot.loadStates[group] = .loadingPrefetch(now)
            }
        }
    }

    @discardableResult
    func markLoaded(symbol: String, group: SecurityDataGroup, updateBlock: (inout SecurityDataSnapshot) -> Void) -> SecurityDataSnapshot {
        update(symbol: symbol) { snapshot in
            updateBlock(&snapshot)
            snapshot.loadStates[group] = .loaded(Date())
            snapshot.fetchedAt = Date()
        }
    }

    @discardableResult
    func markFailed(symbol: String, group: SecurityDataGroup, message: String) -> SecurityDataSnapshot {
        update(symbol: symbol) { snapshot in
            snapshot.loadStates[group] = .failed(Date(), message: message)
        }
    }

    func remove(symbol: String) {
        lock.lock()
        defer { lock.unlock() }

        cache.removeValue(forKey: symbol)
        accessOrder.removeAll { $0 == symbol }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll(keepingCapacity: false)
        accessOrder.removeAll(keepingCapacity: false)
        suppressPrefetchCacheWrites = false
    }
    
    /// Remove cache entries for symbols not in the provided list
    /// Used when filtering/sorting changes the visible list
    func invalidateSymbolsNotInList(_ validSymbols: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        
        let symbolsToRemove = cache.keys.filter { !validSymbols.contains($0) }
        for symbol in symbolsToRemove {
            cache.removeValue(forKey: symbol)
            accessOrder.removeAll { $0 == symbol }
        }
        
        if !symbolsToRemove.isEmpty {
            AppLogger.shared.debug("🗑️ Invalidated \(symbolsToRemove.count) cache entries not in current list")
        }
    }
    
    /// Get all currently cached symbols
    func getAllCachedSymbols() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(cache.keys)
    }

    /// Subset of `groups` that still need background work (including retry after `.failed`).
    /// Excludes groups that are `.loaded` and groups already `.loading` (another task is fetching).
    /// Read-only: does not change LRU order or cache contents.
    func groupsNeedingBackgroundWork(symbol: String, among groups: [SecurityDataGroup]) -> [SecurityDataGroup] {
        lock.lock()
        defer { lock.unlock() }

        guard var snap = cache[symbol] else {
            return groups
        }
        snap.loadStates = normalizedStates(from: snap.loadStates)
        return groups.filter { group in
            if snap.isLoaded(group) {
                return false
            }
            switch snap.loadState(for: group) {
            case .loading, .loadingPrefetch:
                return false
            default:
                break
            }
            return true
        }
    }

    private func touch(symbol: String) {
        accessOrder.removeAll { $0 == symbol }
        accessOrder.append(symbol)
    }

    private func trimIfNeeded() {
        while accessOrder.count > maxCacheSize {
            let symbolToRemove = accessOrder.removeFirst()
            cache.removeValue(forKey: symbolToRemove)
        }
    }

    private func normalizedStates(from states: [SecurityDataGroup: SecurityDataLoadState]) -> [SecurityDataGroup: SecurityDataLoadState] {
        var normalized = states
        for group in SecurityDataGroup.allCases where normalized[group] == nil {
            normalized[group] = .idle
        }
        return normalized
    }
}
