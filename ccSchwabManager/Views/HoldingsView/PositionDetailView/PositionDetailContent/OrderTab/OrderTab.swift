import SwiftUI

struct OrderTab: View {
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let geometry: GeometryProxy
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Section 1: Current Orders
                CurrentOrdersSection(symbol: symbol)
                    .frame(width: geometry.size.width * 0.96, height: geometry.size.height * 0.30)
                
                Divider()
                
                // Section 2: Recommended OCO Orders
                RecommendedSellOrdersSection(
                    symbol: symbol,
                    atrValue: atrValue,
                    taxLotData: taxLotData,
                    sharesAvailableForTrading: sharesAvailableForTrading
                )
                .frame(width: geometry.size.width * 0.96, height: geometry.size.height * 0.55)
            }
        }
        .tabItem {
            Label("Orders", systemImage: "list.clipboard")
        }
    }
} 
