import Foundation

enum SecurityDataGroup: CaseIterable {
    case details
    case priceHistory
    case transactions
    case taxLots
    case orderRecommendations
}

enum SecurityDataLoadState: Equatable {
    case idle
    case loading(Date)
    case loaded(Date)
    case failed(Date, message: String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
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
        case .loading:
            return true
        case .idle:
            return !hasData(for: group)
        case .failed, .loaded:
            return false
        }
    }

    var isFullyLoaded: Bool {
        SecurityDataGroup.allCases.allSatisfy { isLoaded($0) }
    }
}

/// LRU cache that keeps recently loaded security detail data in memory.
final class SecurityDataCacheManager {
    static let shared = SecurityDataCacheManager()

    private let maxCacheSize = 10
    private var cache: [String: SecurityDataSnapshot] = [:]
    private var accessOrder: [String] = []
    private let lock = NSLock()

    private init() {}

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
