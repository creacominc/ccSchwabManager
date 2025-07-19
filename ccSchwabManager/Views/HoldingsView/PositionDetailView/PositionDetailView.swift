import SwiftUI

struct PositionDetailView: View {
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let onNavigate: (Int) -> Void
    @Binding var selectedTab: Int
    @State private var priceHistory: CandleList?
    @State private var isLoadingPriceHistory = false
    @State private var isLoadingTransactions = false
    @State private var quoteData: QuoteData?
    @State private var isLoadingQuote = false
    @State private var taxLotData: [SalesCalcPositionsRecord] = []
    @State private var isLoadingTaxLots = false
    @State private var computedSharesAvailableForTrading: Double = 0.0
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var viewSize: CGSize = .zero
    @StateObject private var loadingState = LoadingState()


    private func formatDate(_ timestamp: Int64?) -> String {
        guard let timestamp = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func fetchDataForSymbol() {
        //print("🔍 PositionDetailView.fetchDataForSymbol - Setting loading to TRUE")
        loadingState.isLoading = true
        defer { 
            //print("🔍 PositionDetailView.fetchDataForSymbol - Setting loading to FALSE")
            loadingState.isLoading = false
        }
        
        // Connect loading state to SchwabClient
        //print("🔗 PositionDetailView - Setting SchwabClient.loadingDelegate")
        SchwabClient.shared.loadingDelegate = loadingState
        
        isLoadingPriceHistory = true
        isLoadingTransactions = true
        isLoadingQuote = true
        isLoadingTaxLots = true
        
        if let symbol = position.instrument?.symbol {
            // Fetch all position-related data in parallel
            priceHistory = SchwabClient.shared.fetchPriceHistory(symbol: symbol)
            _ = SchwabClient.shared.getTransactionsFor(symbol: symbol)
            quoteData = SchwabClient.shared.fetchQuote(symbol: symbol)
            
            // Fetch tax lot data as part of the main data fetch
            taxLotData = SchwabClient.shared.computeTaxLots(symbol: symbol)
            
            // Compute shares available for trading using the tax lots
            computedSharesAvailableForTrading = SchwabClient.shared.computeSharesAvailableForTrading(symbol: symbol, taxLots: taxLotData)
            print("PositionDetailView: Computed shares available for \(symbol): \(computedSharesAvailableForTrading)")
            
            // print( "   ---- fetched \(taxLotData.count) tax lots for symbol \(symbol)" )
        }
        
        isLoadingPriceHistory = false
        isLoadingTransactions = false
        isLoadingQuote = false
        isLoadingTaxLots = false
    }

    var body: some View {
        ZStack {
            PositionDetailContent(
                position: position,
                accountNumber: accountNumber,
                currentIndex: currentIndex,
                totalPositions: totalPositions,
                symbol: symbol,
                atrValue: atrValue,
                sharesAvailableForTrading: computedSharesAvailableForTrading,
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
                viewSize: $viewSize,
                selectedTab: $selectedTab,
            )
            .padding(.horizontal)
        }
        .onAppear {
            loadingState.isLoading = true
            fetchDataForSymbol()
        }
        .onDisappear {
            //print("🔗 PositionDetailView - Clearing SchwabClient.loadingDelegate")
            SchwabClient.shared.loadingDelegate = nil
        }
        .onChange(of: position) { oldValue, newValue in
            loadingState.isLoading = true
            fetchDataForSymbol()
        }
        .withLoadingState(loadingState)
    }
} 
