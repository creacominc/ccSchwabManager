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
    @State private var isLoadingQuote = false
    @State private var taxLotData: [SalesCalcPositionsRecord] = []
    @State private var isLoadingTaxLots = false
    @State private var computedATRValue: Double = 0.0
    @State private var computedSharesAvailableForTrading: Double = 0.0
    @State private var transactions: [Transaction] = []
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var viewSize: CGSize = .zero
    @StateObject private var loadingState = LoadingState()
    @State private var isRefreshing = false

    private func formatDate(_ timestamp: Int64?) -> String
    {
        guard let timestamp = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func fetchDataForSymbol()
    {
        guard let symbol = position.instrument?.symbol else {
            AppLogger.shared.debug("PositionDetailView: No symbol found for position")
            return
        }
        
        AppLogger.shared.debug("PositionDetailView: Fetching data for symbol \(symbol)")
        
        // Show loading indicator immediately
        loadingState.setLoading(true)
        
        // Connect loading state to SchwabClient
        SchwabClient.shared.loadingDelegate = loadingState
        
        isLoadingPriceHistory = true
        isLoadingTransactions = true
        isLoadingQuote = true
        isLoadingTaxLots = true
        
        // Run data fetching in background thread to allow UI to update
        DispatchQueue.global(qos: .userInitiated).async
        {
            // Clear caches to ensure fresh data
            SchwabClient.shared.clearATRCache()
            SchwabClient.shared.clearPriceHistoryCache()
            
            // Fetch all position-related data
            let fetchedPriceHistory = SchwabClient.shared.fetchPriceHistory(symbol: symbol)
            let fetchedTransactions = SchwabClient.shared.getTransactionsFor(symbol: symbol)
            let fetchedQuote = SchwabClient.shared.fetchQuote(symbol: symbol)
            
            // Compute ATR from price history
            let fetchedATRValue = SchwabClient.shared.computeATR(symbol: symbol)
            AppLogger.shared.debug("PositionDetailView: Computed ATR for \(symbol): \(fetchedATRValue)")
            
            // Fetch tax lot data as part of the main data fetch
            // Get current price from quote for tax lot calculations
            let currentPrice = fetchedQuote?.quote?.lastPrice ?? 
                              fetchedQuote?.extended?.lastPrice ?? 
                              fetchedQuote?.regular?.regularMarketLastPrice
            let fetchedTaxLots = SchwabClient.shared.computeTaxLots(symbol: symbol, currentPrice: currentPrice)
            AppLogger.shared.debug("PositionDetailView: Fetched \(fetchedTaxLots.count) tax lots for \(symbol)")
            
            // Compute shares available for trading using the tax lots
            let fetchedSharesAvailable = SchwabClient.shared.computeSharesAvailableForTrading(symbol: symbol, taxLots: fetchedTaxLots)
            AppLogger.shared.debug("PositionDetailView: Computed shares available for \(symbol): \(fetchedSharesAvailable)")
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.priceHistory = fetchedPriceHistory
                self.transactions = fetchedTransactions
                self.quoteData = fetchedQuote
                self.computedATRValue = fetchedATRValue
                self.taxLotData = fetchedTaxLots
                self.computedSharesAvailableForTrading = fetchedSharesAvailable
                
                self.isLoadingPriceHistory = false
                self.isLoadingTransactions = false
                self.isLoadingQuote = false
                self.isLoadingTaxLots = false
                
                // Clear loading state
                self.loadingState.setLoading(false)
            }
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
                        fetchDataForSymbol()
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
            SchwabClient.shared.loadingDelegate = nil
        }
        .withLoadingState(loadingState)
    }
} 
