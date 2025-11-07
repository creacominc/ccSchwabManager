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
        if let history = snapshot.priceHistory {
            self.priceHistory = history
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

        isLoadingPriceHistory = snapshot.isLoading(.priceHistory)
        isLoadingTransactions = snapshot.isLoading(.transactions)
        isLoadingTaxLots = snapshot.isLoading(.taxLots)

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
            let fetchedPriceHistory = SchwabClient.shared.fetchPriceHistory(symbol: symbol)
            if Task.isCancelled { return }
            localHistory = fetchedPriceHistory

            if let fetchedPriceHistory {
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

    var body: some View
    {
        ZStack
        {
            VStack(spacing: 0)
            {
                // Refresh button at the top
                HStack
                {
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
            SchwabClient.shared.loadingDelegate = nil
        }
        .withLoadingState(loadingState)
    }
} 
