import SwiftUI

struct PositionDetailView: View
{
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let symbol: String
    let atrValue: Double // Initial value from parent, will be recomputed
    @Binding var sharesAvailableForTrading: Double // Initial value from parent, will be recomputed
    @Binding var marketValue: Double
    let onNavigate: (Int) -> Void
    let getAdjacentSymbols: () -> (previous1: String?, previous2: String?, next1: String?, next2: String?) // Closure to get adjacent position symbols (2 in each direction)
    @Binding var selectedTab: Int
    @State private var priceHistory: CandleList?
    @State private var isLoadingPriceHistory = false
    @State private var isLoadingTransactions = false
    @State private var quoteData: QuoteData?
    @State private var taxLotData: [SalesCalcPositionsRecord] = []
    @State private var isLoadingTaxLots = false
    @State private var computedATRValue: Double = 0.0
    @State private var computedSharesAvailableForTrading: Double = 0.0
    @State private var transactions: [Transaction] = []
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var viewSize: CGSize = .zero
    @StateObject private var loadingState = LoadingState()
    @State private var isRefreshing = false
    @State private var loadStates: [SecurityDataGroup: SecurityDataLoadState] = [:]
    @State private var dataLoadTask: Task<Void, Never>? = nil
    @State private var prefetchTasks: [String: Task<Void, Never>] = [:] // NEW: Track prefetch tasks
    @State private var showPerformanceSummary = false
    @Environment(\.dismiss) private var dismiss

    private func formatDate(_ timestamp: Int64?) -> String
    {
        guard let timestamp = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    @MainActor
    private func clearAllData() {
        // Clear all data-related state to prevent showing stale values when switching securities
        priceHistory = nil
        transactions = []
        quoteData = nil
        computedATRValue = 0.0
        taxLotData = []
        computedSharesAvailableForTrading = 0.0
        loadStates = [:]
        isLoadingPriceHistory = false
        isLoadingTransactions = false
        isLoadingTaxLots = false
    }
    
    @MainActor
    private func applySnapshot(_ snapshot: SecurityDataSnapshot)
    {
        let priceHistoryBefore = priceHistory?.candles.count ?? 0
        
        if let history = snapshot.priceHistory {
            self.priceHistory = history
            AppLogger.shared.debug("📊 PositionDetailView: Applied price history - \(history.candles.count) candles for \(history.symbol ?? "unknown") (was: \(priceHistoryBefore) candles)")
        } else {
            // Snapshot has no price history data
            AppLogger.shared.debug("📊 PositionDetailView: Snapshot has no price history data")
        }

        if let transactions = snapshot.transactions {
            self.transactions = transactions
        }

        if let quote = snapshot.quoteData {
            self.quoteData = quote
        }

        if let atrValue = snapshot.atrValue {
            self.computedATRValue = atrValue
        }

        if let taxLots = snapshot.taxLotData {
            self.taxLotData = taxLots
        }

        if let shares = snapshot.sharesAvailableForTrading {
            self.computedSharesAvailableForTrading = shares
        }

        loadStates = snapshot.loadStates

        let wasLoading = isLoadingPriceHistory
        isLoadingPriceHistory = snapshot.isLoading(.priceHistory)
        isLoadingTransactions = snapshot.isLoading(.transactions)
        isLoadingTaxLots = snapshot.isLoading(.taxLots)
        
        if wasLoading != isLoadingPriceHistory {
            AppLogger.shared.debug("📊 PositionDetailView: isLoadingPriceHistory changed from \(wasLoading) to \(isLoadingPriceHistory)")
        }

        let anyGroupLoading = snapshot.loadStates.values.contains { $0.isLoading }
        loadingState.setLoading(anyGroupLoading)
    }

    private func fetchDataForSymbol(forceRefresh: Bool = false)
    {
        guard let symbol = position.instrument?.symbol else {
            AppLogger.shared.debug("PositionDetailView: No symbol found for position")
            return
        }

        AppLogger.shared.debug("PositionDetailView: Fetching data for symbol \(symbol)")

        dataLoadTask?.cancel()
        
        // Clear all old data immediately to prevent showing stale values
        clearAllData()

        if forceRefresh {
            SecurityDataCacheManager.shared.remove(symbol: symbol)
        }

        let cachedSnapshot = SecurityDataCacheManager.shared.snapshot(for: symbol)

        if let cachedSnapshot {
            AppLogger.shared.debug("PositionDetailView: Using cached data for symbol \(symbol)")
            // Apply cached data immediately for instant display
            applySnapshot(cachedSnapshot)
            
            // Record cache hits for loaded groups
            for group in SecurityDataGroup.allCases {
                if cachedSnapshot.isLoaded(group) {
                    PerformanceBenchmark.shared.recordCacheHit(for: "\(symbol)_\(group)")
                }
            }
        } else {
            // Record cache miss
            PerformanceBenchmark.shared.recordCacheMiss(for: "\(symbol)_all")
        }

        // Always send the user back to the details tab when switching securities
        selectedTab = 0

        // Determine which groups to load based on cache
        // Strategy: Load everything upfront so tabs are ready when user clicks them sequentially
        // This maximizes network/compute utilization and ensures data is ready by the time user reaches each tab
        let groupsToLoad: [SecurityDataGroup]
        if forceRefresh || cachedSnapshot == nil {
            // Load everything if forcing refresh or no cache
            groupsToLoad = SecurityDataGroup.allCases
        } else {
            // Load all missing groups - we'll prioritize them in loadSecurityData
            // This ensures all tabs are ready when user clicks through them sequentially
            groupsToLoad = SecurityDataGroup.allCases.filter { !cachedSnapshot!.isLoaded($0) }
        }

        if groupsToLoad.isEmpty {
            loadingState.setLoading(false)
            return
        }

        let loadingSnapshot = SecurityDataCacheManager.shared.markLoading(symbol: symbol, groups: groupsToLoad)
        applySnapshot(loadingSnapshot)

        SchwabClient.shared.loadingDelegate = loadingState

        dataLoadTask = Task.detached(priority: .userInitiated) {
            await loadSecurityData(for: symbol, groups: groupsToLoad)
        }
    }

    private func resolveCurrentPrice(quote: QuoteData?, history: CandleList?) -> Double? {
        if let price = quote?.quote?.lastPrice { return price }
        if let price = quote?.extended?.lastPrice { return price }
        if let price = quote?.regular?.regularMarketLastPrice { return price }
        if let price = history?.candles.last?.close { return price }
        return nil
    }
    
    /// Ensures transactions are loaded when Transactions tab is selected
    /// This provides immediate feedback when user clicks on the Transactions tab
    @MainActor
    private func ensureTransactionsLoaded() {
        guard let symbol = position.instrument?.symbol else { return }
        
        let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol)
        
        // Check if transactions are already loaded or loading
        if let snapshot = snapshot {
            if snapshot.isLoaded(.transactions) || snapshot.isLoading(.transactions) {
                AppLogger.shared.debug("📊 Transactions already loaded or loading for \(symbol)")
                return
            }
        }
        
        // Start loading transactions immediately
        AppLogger.shared.debug("📊 Triggering transaction load for \(symbol) (Transactions tab selected)")
        let loadingSnapshot = SecurityDataCacheManager.shared.markLoading(symbol: symbol, groups: [.transactions])
        applySnapshot(loadingSnapshot)
        
        Task.detached(priority: .userInitiated) {
            let fetchedTransactions = SchwabClient.shared.getTransactionsFor(symbol: symbol)
            if Task.isCancelled { return }
            
            let updatedSnapshot = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .transactions) { snapshot in
                snapshot.transactions = fetchedTransactions
            }
            
            await MainActor.run {
                applySnapshot(updatedSnapshot)
            }
        }
    }

    private func loadSecurityData(for symbol: String, groups: [SecurityDataGroup]) async {
        var localQuote: QuoteData? = SecurityDataCacheManager.shared.snapshot(for: symbol)?.quoteData
        var localHistory: CandleList? = SecurityDataCacheManager.shared.snapshot(for: symbol)?.priceHistory

        // STRATEGY: Load everything upfront in optimal order for sequential tab navigation
        // Tab order: Details(0) -> Price History(1) -> Transactions(2) -> Sales Calc(3) -> Current(4) -> OCO(5) -> Sequence(6)
        // Goal: Have data ready by the time user clicks each tab
        
        // PHASE 1: Load details (quote) first - Tab 0 needs this immediately
        if groups.contains(.details) {
            let wasCached = SecurityDataCacheManager.shared.snapshot(for: symbol)?.isLoaded(.details) ?? false
            PerformanceBenchmark.shared.startTiming("load_details_\(symbol)", metadata: ["symbol": symbol, "group": "details"])
            
            AppLogger.shared.debug("📊 [Phase 1] Loading details (quote) for \(symbol)")
            let fetchedQuote = SchwabClient.shared.fetchQuote(symbol: symbol)
            if Task.isCancelled { return }
            localQuote = fetchedQuote

            if let fetchedQuote {
                let updatedSnapshot = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .details) { snapshot in
                    snapshot.quoteData = fetchedQuote
                }

                await MainActor.run {
                    applySnapshot(updatedSnapshot)
                }
                
                if let duration = PerformanceBenchmark.shared.endTiming("load_details_\(symbol)") {
                    PerformanceBenchmark.shared.recordDataLoad(symbol: symbol, group: .details, duration: duration, fromCache: wasCached)
                }
            } else {
                let failedSnapshot = SecurityDataCacheManager.shared.markFailed(symbol: symbol, group: .details, message: "Quote unavailable")
                await MainActor.run {
                    applySnapshot(failedSnapshot)
                }
                _ = PerformanceBenchmark.shared.endTiming("load_details_\(symbol)")
            }
        }

        if Task.isCancelled { return }

        // PHASE 2: Load Price History and Transactions in parallel - Tabs 1 & 2
        // These are independent and can load simultaneously to maximize network/compute utilization
        AppLogger.shared.debug("📊 [Phase 2] Starting parallel load: Price History + Transactions for \(symbol)")
        
        let priceHistoryTask: Task<Void, Never>? = groups.contains(.priceHistory) ? Task {
            let wasCached = SecurityDataCacheManager.shared.snapshot(for: symbol)?.isLoaded(.priceHistory) ?? false
            PerformanceBenchmark.shared.startTiming("load_priceHistory_\(symbol)", metadata: ["symbol": symbol, "group": "priceHistory"])
            
            AppLogger.shared.debug("📊 Loading price history for \(symbol)")
            let fetchedPriceHistory = SchwabClient.shared.fetchPriceHistory(symbol: symbol)
            if Task.isCancelled { return }
            
            if let fetchedPriceHistory {
                AppLogger.shared.debug("📊 Fetched price history for \(symbol): \(fetchedPriceHistory.candles.count) candles")
                let fetchedATRValue = SchwabClient.shared.computeATR(symbol: symbol)
                if Task.isCancelled { return }

                let updatedSnapshot = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .priceHistory) { snapshot in
                    snapshot.priceHistory = fetchedPriceHistory
                    snapshot.atrValue = fetchedATRValue
                }

                await MainActor.run {
                    applySnapshot(updatedSnapshot)
                }
                
                if let duration = PerformanceBenchmark.shared.endTiming("load_priceHistory_\(symbol)") {
                    PerformanceBenchmark.shared.recordDataLoad(symbol: symbol, group: .priceHistory, duration: duration, fromCache: wasCached)
                }
            } else {
                AppLogger.shared.warning("📊 Failed to fetch price history for \(symbol)")
                let failedSnapshot = SecurityDataCacheManager.shared.markFailed(symbol: symbol, group: .priceHistory, message: "Price history unavailable")
                await MainActor.run {
                    applySnapshot(failedSnapshot)
                }
                _ = PerformanceBenchmark.shared.endTiming("load_priceHistory_\(symbol)")
            }
        } : nil
        
        let transactionsTask: Task<Void, Never>? = groups.contains(.transactions) ? Task {
            let wasCached = SecurityDataCacheManager.shared.snapshot(for: symbol)?.isLoaded(.transactions) ?? false
            PerformanceBenchmark.shared.startTiming("load_transactions_\(symbol)", metadata: ["symbol": symbol, "group": "transactions"])
            
            AppLogger.shared.debug("📊 Loading transactions for \(symbol)")
            let fetchedTransactions = SchwabClient.shared.getTransactionsFor(symbol: symbol)
            if Task.isCancelled { return }

            let updatedSnapshot = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .transactions) { snapshot in
                snapshot.transactions = fetchedTransactions
            }

            await MainActor.run {
                applySnapshot(updatedSnapshot)
            }
            
            if let duration = PerformanceBenchmark.shared.endTiming("load_transactions_\(symbol)") {
                PerformanceBenchmark.shared.recordDataLoad(symbol: symbol, group: .transactions, duration: duration, fromCache: wasCached)
            }
        } : nil
        
        // PHASE 3: Start Tax Lots loading as soon as we have price (can use cached or wait for quote)
        // Tab 3 (Sales Calc) needs this, and it can start with cached price or wait for quote
        let taxLotsTask: Task<Void, Never>? = groups.contains(.taxLots) ? Task {
            // Wait for quote to be available (either from cache or Phase 1)
            var effectivePrice: Double?
            var attempts = 0
            while effectivePrice == nil && attempts < 10 {
                await MainActor.run {
                    let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol)
                    effectivePrice = resolveCurrentPrice(quote: snapshot?.quoteData ?? localQuote, history: snapshot?.priceHistory ?? localHistory)
                }
                if effectivePrice == nil {
                    // Wait a bit for quote to load
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    attempts += 1
                }
            }
            
            if Task.isCancelled { return }
            
            if let price = effectivePrice {
                // Check cache first before starting timer
                let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol)
                let wasCached = snapshot?.isLoaded(.taxLots) ?? false
                
                // If already cached, skip computation
                if wasCached, let cachedTaxLots = snapshot?.taxLotData, let cachedShares = snapshot?.sharesAvailableForTrading {
                    AppLogger.shared.debug("📊 Tax lots already cached for \(symbol)")
                    PerformanceBenchmark.shared.recordCacheHit(for: "\(symbol)_taxLots")
                    // Still update the snapshot to ensure UI is in sync
                    await MainActor.run {
                        let updatedSnapshot = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .taxLots) { snapshot in
                            snapshot.taxLotData = cachedTaxLots
                            snapshot.sharesAvailableForTrading = cachedShares
                        }
                        applySnapshot(updatedSnapshot)
                    }
                } else {
                    PerformanceBenchmark.shared.startTiming("load_taxLots_\(symbol)", metadata: ["symbol": symbol, "group": "taxLots"])
                    
                    AppLogger.shared.debug("📊 [Phase 3] Loading tax lots for \(symbol) with price \(price)")
                    // Use optimized version with better caching
                    let fetchedTaxLots = SchwabClient.shared.computeTaxLotsOptimized(symbol: symbol, currentPrice: price)
                    if Task.isCancelled { return }
                    let fetchedSharesAvailable = SchwabClient.shared.computeSharesAvailableForTrading(symbol: symbol, taxLots: fetchedTaxLots)

                    let updatedSnapshot = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .taxLots) { snapshot in
                        snapshot.taxLotData = fetchedTaxLots
                        snapshot.sharesAvailableForTrading = fetchedSharesAvailable
                    }

                    await MainActor.run {
                        applySnapshot(updatedSnapshot)
                    }
                    
                    if let duration = PerformanceBenchmark.shared.endTiming("load_taxLots_\(symbol)") {
                        PerformanceBenchmark.shared.recordDataLoad(symbol: symbol, group: .taxLots, duration: duration, fromCache: false)
                    }
                }
            } else {
                AppLogger.shared.warning("📊 Could not resolve price for tax lots calculation")
            }
        } : nil
        
        // Wait for Phase 2 parallel tasks to complete
        await priceHistoryTask?.value
        await transactionsTask?.value
        
        // Update local history from cache after parallel load completes
        if let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol) {
            localHistory = snapshot.priceHistory
        }
        
        // Wait for tax lots to complete (it may have already finished if price was cached)
        await taxLotsTask?.value
        
        if Task.isCancelled { return }
        
        // Compute and cache order recommendations once we have all the necessary data
        if Task.isCancelled { return }
        
        // PHASE 4: Compute order recommendations if needed (after tax lots and price history are ready)
        // Only compute if explicitly requested - tabs 4, 5, 6 will request this group when needed
        if groups.contains(.orderRecommendations) {
            // Check cache first before starting timer
            let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol)
            let wasCached = snapshot?.isLoaded(.orderRecommendations) ?? false
            
            // If already cached, skip computation
            if wasCached {
                AppLogger.shared.debug("📊 Order recommendations already cached for \(symbol)")
                PerformanceBenchmark.shared.recordCacheHit(for: "\(symbol)_orderRecommendations")
            } else {
                PerformanceBenchmark.shared.startTiming("load_orderRecommendations_\(symbol)", metadata: ["symbol": symbol, "group": "orderRecommendations"])
                
                await computeAndCacheOrderRecommendations(symbol: symbol, localQuote: localQuote, localHistory: localHistory)
                
                if let duration = PerformanceBenchmark.shared.endTiming("load_orderRecommendations_\(symbol)") {
                    PerformanceBenchmark.shared.recordDataLoad(symbol: symbol, group: .orderRecommendations, duration: duration, fromCache: false)
                }
            }
        }
        
        // After all data is loaded, trigger prefetching of adjacent securities
        if Task.isCancelled { return }
        
        // Check if current security is fully loaded
        if let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol),
           snapshot.isFullyLoaded {
            AppLogger.shared.debug("✅ \(symbol) fully loaded, triggering prefetch of adjacent securities")
            await MainActor.run {
                prefetchAdjacentSecurities()
            }
        }
    }
    
    private func computeAndCacheOrderRecommendations(symbol: String, localQuote: QuoteData?, localHistory: CandleList?) async {
        // Get the current snapshot to check if we have all required data
        guard let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol),
              let atrValue = snapshot.atrValue,
              let taxLotData = snapshot.taxLotData,
              let sharesAvailableForTrading = snapshot.sharesAvailableForTrading,
              !taxLotData.isEmpty,
              sharesAvailableForTrading > 0 else {
            AppLogger.shared.debug("PositionDetailView: Missing required data for order recommendations for \(symbol)")
            return
        }
        
        // Check if already cached in SecurityDataCacheManager first
        if snapshot.isLoaded(.orderRecommendations),
           let cachedSellOrders = snapshot.recommendedSellOrders,
           let cachedBuyOrders = snapshot.recommendedBuyOrders,
           !cachedSellOrders.isEmpty || !cachedBuyOrders.isEmpty {
            AppLogger.shared.debug("PositionDetailView: Using cached order recommendations for \(symbol)")
            PerformanceBenchmark.shared.recordCacheHit(for: "\(symbol)_orderRecommendations")
            return
        }
        
        // Get the current price
        guard let currentPrice = resolveCurrentPrice(quote: localQuote, history: localHistory) else {
            AppLogger.shared.debug("PositionDetailView: No current price available for \(symbol)")
            return
        }
        
        // Calculate position values from Position object
        let totalShares = (position.longQuantity ?? 0) + (position.shortQuantity ?? 0)
        let avgCostPerShare = position.averagePrice ?? 0
        let totalCost = avgCostPerShare * totalShares
        let pl = position.longOpenProfitLoss ?? 0
        let mv = position.marketValue ?? 0
        let costBasis = mv - pl
        let currentProfitPercent = costBasis != 0 ? (pl / costBasis) * 100 : 0
        
        AppLogger.shared.debug("PositionDetailView: Computing order recommendations for \(symbol)")
        
        // Mark as loading
        let loadingSnapshot = SecurityDataCacheManager.shared.markLoading(symbol: symbol, groups: [.orderRecommendations])
        await MainActor.run {
            applySnapshot(loadingSnapshot)
        }
        
        if Task.isCancelled { return }
        
        // Create a temporary order service to compute recommendations
        let orderService = OrderRecommendationService()
        
        // Calculate sell and buy orders in parallel
        async let sellOrders = orderService.calculateRecommendedSellOrders(
            symbol: symbol,
            atrValue: atrValue,
            taxLotData: taxLotData,
            sharesAvailableForTrading: sharesAvailableForTrading,
            currentPrice: currentPrice
        )
        
        async let buyOrders = orderService.calculateRecommendedBuyOrders(
            symbol: symbol,
            atrValue: atrValue,
            taxLotData: taxLotData,
            sharesAvailableForTrading: sharesAvailableForTrading,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        if Task.isCancelled { return }
        
        // Wait for both to complete
        let (sellResults, buyResults) = await (sellOrders, buyOrders)
        
        AppLogger.shared.debug("PositionDetailView: Order recommendations computed for \(symbol) - \(sellResults.count) sell, \(buyResults.count) buy")
        
        // Cache the results
        let updatedSnapshot = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .orderRecommendations) { snapshot in
            snapshot.recommendedSellOrders = sellResults
            snapshot.recommendedBuyOrders = buyResults
        }
        
        await MainActor.run {
            applySnapshot(updatedSnapshot)
        }
    }
    
    // MARK: - Prefetching Methods
    
    /// Checks if a symbol needs to be prefetched (not in cache or not fully loaded)
    private func shouldPrefetch(symbol: String) -> Bool {
        guard let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol) else {
            return true // Not in cache at all
        }
        
        // Check if all critical data groups are loaded (including transactions per user request)
        let criticalGroups: [SecurityDataGroup] = [.details, .priceHistory, .transactions, .taxLots]
        return !criticalGroups.allSatisfy { snapshot.isLoaded($0) }
    }
    
    /// Prefetches data for a single security in the background
    private func prefetchSecurity(symbol: String, position: Position) {
        // Cancel any existing prefetch task for this symbol
        prefetchTasks[symbol]?.cancel()
        
        AppLogger.shared.debug("🔮 Prefetching data for adjacent security: \(symbol)")
        
        let task = Task.detached(priority: .low) {
            // Check if this symbol needs prefetching
            await MainActor.run {
                guard shouldPrefetch(symbol: symbol) else {
                    AppLogger.shared.debug("✅ \(symbol) already cached, skipping prefetch")
                    return
                }
            }
            
            // Mark as loading in cache (including transactions per user request)
            let loadingGroups: [SecurityDataGroup] = [.details, .priceHistory, .transactions, .taxLots, .orderRecommendations]
            _ = SecurityDataCacheManager.shared.markLoading(symbol: symbol, groups: loadingGroups)
            
            // Fetch quote data
            var localQuote: QuoteData? = nil
            if Task.isCancelled { return }
            let fetchedQuote = SchwabClient.shared.fetchQuote(symbol: symbol)
            if Task.isCancelled { return }
            localQuote = fetchedQuote
            
            if let fetchedQuote {
                _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .details) { snapshot in
                    snapshot.quoteData = fetchedQuote
                }
            }
            
            // Fetch price history
            var localHistory: CandleList? = nil
            if Task.isCancelled { return }
            let fetchedPriceHistory = SchwabClient.shared.fetchPriceHistory(symbol: symbol)
            if Task.isCancelled { return }
            localHistory = fetchedPriceHistory
            
            if let fetchedPriceHistory {
                let fetchedATRValue = SchwabClient.shared.computeATR(symbol: symbol)
                if Task.isCancelled { return }
                
                _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .priceHistory) { snapshot in
                    snapshot.priceHistory = fetchedPriceHistory
                    snapshot.atrValue = fetchedATRValue
                }
            }
            
            // Fetch transactions
            if Task.isCancelled { return }
            let fetchedTransactions = SchwabClient.shared.getTransactionsFor(symbol: symbol)
            if Task.isCancelled { return }
            
            _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .transactions) { snapshot in
                snapshot.transactions = fetchedTransactions
            }
            
            // Fetch tax lots
            if Task.isCancelled { return }
            let effectivePrice: Double? = {
                if let price = localQuote?.quote?.lastPrice { return price }
                if let price = localQuote?.extended?.lastPrice { return price }
                if let price = localQuote?.regular?.regularMarketLastPrice { return price }
                if let price = localHistory?.candles.last?.close { return price }
                return nil
            }()
            let fetchedTaxLots = SchwabClient.shared.computeTaxLots(symbol: symbol, currentPrice: effectivePrice)
            if Task.isCancelled { return }
            let fetchedSharesAvailable = SchwabClient.shared.computeSharesAvailableForTrading(symbol: symbol, taxLots: fetchedTaxLots)
            
            _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .taxLots) { snapshot in
                snapshot.taxLotData = fetchedTaxLots
                snapshot.sharesAvailableForTrading = fetchedSharesAvailable
            }
            
            //  Skip order recommendations prefetch - these can be computed quickly when user navigates to OCO tab
            // The main value of prefetching is caching tax lots and price history data
            AppLogger.shared.debug("✅ Basic prefetch complete for \(symbol) (order recommendations computed on-demand)")
        }
        
        prefetchTasks[symbol] = task
    }
    
    /// Triggers prefetching of adjacent securities once current security is fully loaded
    /// Prefetches 2 securities in each direction with prioritization: immediate adjacents first, then second-level
    private func prefetchAdjacentSecurities() {
        // Get adjacent symbols from parent (2 before, 2 after)
        let adjacent = getAdjacentSymbols()
        
        AppLogger.shared.debug("🔮 Checking adjacent securities for prefetch - prev2: \(adjacent.previous2 ?? "none"), prev1: \(adjacent.previous1 ?? "none"), next1: \(adjacent.next1 ?? "none"), next2: \(adjacent.next2 ?? "none")")
        
        // PRIORITY 1: Prefetch immediate adjacents (N-1 and N+1) first
        let immediateAdjacents: [(symbol: String, label: String)] = [
            (adjacent.previous1, "previous (N-1)"),
            (adjacent.next1, "next (N+1)")
        ].compactMap { symbol, label in
            guard let sym = symbol else { return nil }
            return (sym, label)
        }
        
        for (symbol, label) in immediateAdjacents {
            if shouldPrefetch(symbol: symbol) {
                AppLogger.shared.debug("🔮 [Priority 1] Scheduling prefetch for \(label) security: \(symbol)")
                Task.detached(priority: .low) {
                    await self.prefetchSecurityDataOnly(symbol: symbol)
                }
            } else {
                AppLogger.shared.debug("✅ \(symbol) (\(label)) already cached, skipping prefetch")
            }
        }
        
        // PRIORITY 2: Prefetch second-level adjacents (N-2 and N+2) after a short delay
        // This ensures immediate adjacents complete first
        let secondLevelAdjacents: [(symbol: String, label: String)] = [
            (adjacent.previous2, "previous (N-2)"),
            (adjacent.next2, "next (N+2)")
        ].compactMap { symbol, label in
            guard let sym = symbol else { return nil }
            return (sym, label)
        }
        
        if !secondLevelAdjacents.isEmpty {
            Task.detached(priority: .low) {
                // Small delay to let immediate adjacents start first
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                for (symbol, label) in secondLevelAdjacents {
                    if await MainActor.run(body: { self.shouldPrefetch(symbol: symbol) }) {
                        AppLogger.shared.debug("🔮 [Priority 2] Scheduling prefetch for \(label) security: \(symbol)")
                        await self.prefetchSecurityDataOnly(symbol: symbol)
                    } else {
                        AppLogger.shared.debug("✅ \(symbol) (\(label)) already cached, skipping prefetch")
                    }
                }
            }
        }
    }
    
    /// Prefetches basic security data (without order recommendations) for a symbol
    private func prefetchSecurityDataOnly(symbol: String) async {
        AppLogger.shared.debug("🔮 Prefetching basic data for: \(symbol)")
        
        // Mark as loading in cache (including transactions per user request)
        let loadingGroups: [SecurityDataGroup] = [.details, .priceHistory, .transactions, .taxLots]
        _ = SecurityDataCacheManager.shared.markLoading(symbol: symbol, groups: loadingGroups)
        
        // Fetch quote data
        if Task.isCancelled { return }
        let fetchedQuote = SchwabClient.shared.fetchQuote(symbol: symbol)
        if Task.isCancelled { return }
        
        if let fetchedQuote {
            _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .details) { snapshot in
                snapshot.quoteData = fetchedQuote
            }
        }
        
        // Fetch price history
        if Task.isCancelled { return }
        let fetchedPriceHistory = SchwabClient.shared.fetchPriceHistory(symbol: symbol)
        if Task.isCancelled { return }
        
        if let fetchedPriceHistory {
            let fetchedATRValue = SchwabClient.shared.computeATR(symbol: symbol)
            if Task.isCancelled { return }
            
            _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .priceHistory) { snapshot in
                snapshot.priceHistory = fetchedPriceHistory
                snapshot.atrValue = fetchedATRValue
            }
        }
        
        // Fetch transactions (added per user request to ensure transaction history is prefetched)
        if Task.isCancelled { return }
        AppLogger.shared.debug("🔮 Fetching transactions for prefetch: \(symbol)")
        let fetchedTransactions = SchwabClient.shared.getTransactionsFor(symbol: symbol)
        if Task.isCancelled { return }
        
        _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .transactions) { snapshot in
            snapshot.transactions = fetchedTransactions
        }
        AppLogger.shared.debug("🔮 Transactions prefetch complete for \(symbol): \(fetchedTransactions.count) transactions")
        
        // Fetch tax lots
        if Task.isCancelled { return }
        let currentPrice = fetchedQuote?.quote?.lastPrice ?? fetchedQuote?.extended?.lastPrice ?? fetchedPriceHistory?.candles.last?.close
        let fetchedTaxLots = SchwabClient.shared.computeTaxLots(symbol: symbol, currentPrice: currentPrice)
        if Task.isCancelled { return }
        let fetchedSharesAvailable = SchwabClient.shared.computeSharesAvailableForTrading(symbol: symbol, taxLots: fetchedTaxLots)
        
        _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .taxLots) { snapshot in
            snapshot.taxLotData = fetchedTaxLots
            snapshot.sharesAvailableForTrading = fetchedSharesAvailable
        }
        
        AppLogger.shared.debug("✅ Basic prefetch complete for \(symbol) (including transactions)")
    }

    var body: some View
    {
        ZStack
        {
            VStack(spacing: 0)
            {
                // Close and Refresh buttons at the top
                HStack
                {
                    #if !os(macOS)
                    // Close button for iOS and visionOS
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                            Text("Close")
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    #endif
                    
                    Spacer()
                    
                    Button(action: {
                        isRefreshing = true
                        fetchDataForSymbol(forceRefresh: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isRefreshing = false
                        }
                    }) {
                        HStack {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.accentColor)
                            }
                            Text(isRefreshing ? "Refreshing..." : "Refresh")
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                .background(Color.gray.opacity(0.1))

                PositionDetailContent(
                    position: position,
                    accountNumber: accountNumber,
                    currentIndex: currentIndex,
                    totalPositions: totalPositions,
                    symbol: symbol,
                    atrValue: computedATRValue > 0 ? computedATRValue : atrValue,
                    sharesAvailableForTrading: $computedSharesAvailableForTrading,
                    marketValue: $marketValue,
                    onNavigate: { newIndex in
                        guard newIndex >= 0 && newIndex < totalPositions else { return }
                        loadingState.isLoading = true
                        onNavigate(newIndex)
                    },
                    priceHistory: priceHistory,
                    isLoadingPriceHistory: isLoadingPriceHistory,
                    isLoadingTransactions: isLoadingTransactions,
                    formatDate: formatDate,
                    quoteData: quoteData,
                    taxLotData: taxLotData,
                    isLoadingTaxLots: isLoadingTaxLots,
                    transactions: transactions,
                    selectedTab: $selectedTab,
                )
                .padding(.horizontal)
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Record tab switch for benchmarking
            PerformanceBenchmark.shared.recordTabSwitch(to: newValue, symbol: position.instrument?.symbol)
            
            // When Transactions tab is selected, ensure transactions are loading/loaded
            if newValue == 2 { // Transactions tab
                ensureTransactionsLoaded()
            }
        }
        .onAppear {
            // Initialize computed values with parent values
            computedATRValue = atrValue
            computedSharesAvailableForTrading = sharesAvailableForTrading
            marketValue = position.marketValue ?? 0.0
            
            // Fetch data asynchronously
            fetchDataForSymbol()
            
            // Add a safety timeout to clear loading state if it gets stuck
            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                if loadingState.isLoading {
                    AppLogger.shared.debug("PositionDetailView: Loading timeout - clearing stuck loading state")
                    loadingState.forceClearLoading()
                }
            }
        }
        .onChange(of: position.instrument?.symbol) { oldValue, newValue in
            // Refetch data when position changes (navigation)
            if oldValue != newValue {
                AppLogger.shared.debug("PositionDetailView: Position changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
                marketValue = position.marketValue ?? 0.0
                fetchDataForSymbol()
                
                // Add a safety timeout to clear loading state if it gets stuck
                DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                    if loadingState.isLoading {
                        AppLogger.shared.debug("PositionDetailView: Loading timeout - clearing stuck loading state")
                        loadingState.forceClearLoading()
                    }
                }
            }
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
            
            // Cancel all prefetch tasks
            for (symbol, task) in prefetchTasks {
                AppLogger.shared.debug("🔮 Cancelling prefetch task for \(symbol)")
                task.cancel()
            }
            prefetchTasks.removeAll()
            
            SchwabClient.shared.loadingDelegate = nil
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showPerformanceSummary = true
                } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Performance Benchmark")
            }
        }
        .sheet(isPresented: $showPerformanceSummary) {
            PerformanceSummaryView()
        }
        .withLoadingState(loadingState)
    }
} 
