import SwiftUI

struct OrderTab: View {
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let quoteData: QuoteData?
    let geometry: GeometryProxy
    let accountNumber: String
    
    var body: some View {
        VStack(spacing: 8) {
            // Section 1: Current Orders
            CurrentOrdersSection(symbol: symbol)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Section 2: Recommended OCO Orders (Combined Buy and Sell)
            RecommendedOCOOrdersSection(
                symbol: symbol,
                atrValue: atrValue,
                taxLotData: taxLotData,
                sharesAvailableForTrading: sharesAvailableForTrading,
                quoteData: quoteData,
                accountNumber: accountNumber
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, geometry.size.width * 0.02)
        .tabItem {
            Image(systemName: "list.bullet")
            Text("Orders")
        }
    }
} 
