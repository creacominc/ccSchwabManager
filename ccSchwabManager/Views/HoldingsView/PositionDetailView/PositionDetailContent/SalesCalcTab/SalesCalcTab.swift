import SwiftUI

struct SalesCalcTab: View {
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let isLoadingTaxLots: Bool
    let geometry: GeometryProxy

    var body: some View {
        ScrollView {
            SalesCalcView(
                symbol: symbol,
                atrValue: atrValue,
                taxLotData: taxLotData,
                isLoadingTaxLots: isLoadingTaxLots
            )
            .frame(width: geometry.size.width * 0.96, height: geometry.size.height * 0.9)
        }
        .tabItem {
            Label("Sales Calc", systemImage: "calculator")
        }
    }
} 
