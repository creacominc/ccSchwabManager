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
    let getAdjacentSymbols: () -> (previous: String?, next: String?) // NEW: Closure to get adjacent position symbols
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
            applySnapshot(cachedSnapshot)
        }

        // Always send the user back to the details tab when switching securities
        selectedTab = 0

        let groupsToLoad: [SecurityDataGroup]
        if forceRefresh || cachedSnapshot == nil {
            groupsToLoad = SecurityDataGroup.allCases
        } else {
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

    private func loadSecurityData(for symbol: String, groups: [SecurityDataGroup]) async {
        var localQuote: QuoteData? = SecurityDataCacheManager.shared.snapshot(for: symbol)?.quoteData
        var localHistory: CandleList? = SecurityDataCacheManager.shared.snapshot(for: symbol)?.priceHistory

        if groups.contains(.details) {
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
            } else {
                let failedSnapshot = SecurityDataCacheManager.shared.markFailed(symbol: symbol, group: .details, message: "Quote unavailable")
                await MainActor.run {
                    applySnapshot(failedSnapshot)
                }
            }
        }

        if Task.isCancelled { return }

        if groups.contains(.priceHistory) {
            AppLogger.shared.debug("📊 Loading price history for \(symbol)")
            let fetchedPriceHistory = SchwabClient.shared.fetchPriceHistory(symbol: symbol)
            if Task.isCancelled { return }
            localHistory = fetchedPriceHistory

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
            } else {
                AppLogger.shared.warning("📊 Failed to fetch price history for \(symbol)")
                let failedSnapshot = SecurityDataCacheManager.shared.markFailed(symbol: symbol, group: .priceHistory, message: "Price history unavailable")
                await MainActor.run {
                    applySnapshot(failedSnapshot)
                }
            }
        }

        if Task.isCancelled { return }

        if groups.contains(.transactions) {
            let fetchedTransactions = SchwabClient.shared.getTransactionsFor(symbol: symbol)
            if Task.isCancelled { return }

            let updatedSnapshot = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .transactions) { snapshot in
                snapshot.transactions = fetchedTransactions
            }

            await MainActor.run {
                applySnapshot(updatedSnapshot)
            }
        }

        if Task.isCancelled { return }

        if groups.contains(.taxLots) {
            let effectivePrice = resolveCurrentPrice(quote: localQuote, history: localHistory)
            let fetchedTaxLots = SchwabClient.shared.computeTaxLots(symbol: symbol, currentPrice: effectivePrice)
            if Task.isCancelled { return }
            let fetchedSharesAvailable = SchwabClient.shared.computeSharesAvailableForTrading(symbol: symbol, taxLots: fetchedTaxLots)

            let updatedSnapshot = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .taxLots) { snapshot in
                snapshot.taxLotData = fetchedTaxLots
                snapshot.sharesAvailableForTrading = fetchedSharesAvailable
            }

            await MainActor.run {
                applySnapshot(updatedSnapshot)
            }
        }
        
        // Compute and cache order recommendations once we have all the necessary data
        if Task.isCancelled { return }
        
        if groups.contains(.orderRecommendations) || (groups.contains(.taxLots) && groups.contains(.priceHistory)) {
            await computeAndCacheOrderRecommendations(symbol: symbol, localQuote: localQuote, localHistory: localHistory)
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
        
        // Check if all critical data groups are loaded
        let criticalGroups: [SecurityDataGroup] = [.details, .priceHistory, .taxLots]
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
            
            // Mark as loading in cache
            let loadingGroups: [SecurityDataGroup] = [.details, .priceHistory, .taxLots, .orderRecommendations]
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
    private func prefetchAdjacentSecurities() {
        // Get adjacent symbols from parent
        let adjacent = getAdjacentSymbols()
        
        AppLogger.shared.debug("🔮 Checking adjacent securities for prefetch - previous: \(adjacent.previous ?? "none"), next: \(adjacent.next ?? "none")")
        
        // Prefetch previous security if it exists and needs it
        if let previousSymbol = adjacent.previous, shouldPrefetch(symbol: previousSymbol) {
            // We need to get the Position object for the previous security
            // Since we don't have direct access, we'll do a simpler prefetch without order recommendations for now
            AppLogger.shared.debug("🔮 Scheduling prefetch for previous security: \(previousSymbol)")
            Task.detached(priority: .low) {
                await self.prefetchSecurityDataOnly(symbol: previousSymbol)
            }
        }
        
        // Prefetch next security if it exists and needs it
        if let nextSymbol = adjacent.next, shouldPrefetch(symbol: nextSymbol) {
            AppLogger.shared.debug("🔮 Scheduling prefetch for next security: \(nextSymbol)")
            Task.detached(priority: .low) {
                await self.prefetchSecurityDataOnly(symbol: nextSymbol)
            }
        }
    }
    
    /// Prefetches basic security data (without order recommendations) for a symbol
    private func prefetchSecurityDataOnly(symbol: String) async {
        AppLogger.shared.debug("🔮 Prefetching basic data for: \(symbol)")
        
        // Mark as loading in cache
        let loadingGroups: [SecurityDataGroup] = [.details, .priceHistory, .taxLots]
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
        
        AppLogger.shared.debug("✅ Basic prefetch complete for \(symbol)")
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
        }
        .withLoadingState(loadingState)
    }
} 
