import SwiftUI

struct PositionDetailContent: View {
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let symbol: String
    let atrValue: Double
    let onNavigate: (Int) -> Void
    let priceHistory: CandleList?
    let isLoadingPriceHistory: Bool
    let isLoadingTransactions: Bool
    let formatDate: (Int64?) -> String
    let quoteData: QuoteData?
    let taxLotData: [SalesCalcPositionsRecord]
    let isLoadingTaxLots: Bool
    @Binding var viewSize: CGSize
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 0) {
            PositionDetailsHeader(
                position: position,
                accountNumber: accountNumber,
                currentIndex: currentIndex,
                totalPositions: totalPositions,
                onNavigate: onNavigate,
                symbol: symbol,
                atrValue: atrValue,
                lastPrice: priceHistory?.candles.last?.close ?? 0.0,
                quoteData: quoteData,
            )
            .padding(.bottom, 4)
            
            Divider()
                .padding(.vertical, 4)
            
            GeometryReader { geometry in
                TabView(selection: $selectedTab) {
                    PriceHistoryTab(
                        priceHistory: priceHistory,
                        isLoading: isLoadingPriceHistory,
                        formatDate: formatDate,
                        geometry: geometry
                    )
                    .tag(0)
                    
                    TransactionsTab(
                        isLoading: isLoadingTransactions,
                        symbol: position.instrument?.symbol ?? "",
                        geometry: geometry
                    )
                    .tag(1)
                    
                    SalesCalcTab(
                        symbol: symbol,
                        atrValue: atrValue,
                        taxLotData: taxLotData,
                        isLoadingTaxLots: isLoadingTaxLots,
                        geometry: geometry
                    )
                    .tag(2)
                }
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { oldValue, newValue in
                    viewSize = newValue
                }
            }
        }
    }
} 
