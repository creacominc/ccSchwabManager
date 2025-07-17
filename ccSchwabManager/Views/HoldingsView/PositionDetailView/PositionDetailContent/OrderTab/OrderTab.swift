import SwiftUI

struct OrderTab: View {
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let geometry: GeometryProxy
    
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
                sharesAvailableForTrading: sharesAvailableForTrading
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
