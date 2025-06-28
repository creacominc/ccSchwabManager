import SwiftUI

struct TransactionsTab: View {
    let isLoading: Bool
    let symbol: String
    let geometry: GeometryProxy
    
    var body: some View {
        ScrollView {
            TransactionHistorySection(
                isLoading: isLoading,
                symbol: symbol
            )
            .frame(width: geometry.size.width * 0.88, height: geometry.size.height * 0.90)
        }
        .tabItem {
            Label("Transactions", systemImage: "list.bullet")
        }
    }
}

struct SalesCalcTab: View {
    let symbol: String
    let atrValue: Double
    let geometry: GeometryProxy

    var body: some View {
        ScrollView {

            SalesCalcView(
                symbol: symbol,
                atrValue: atrValue
            )
            .frame(width: geometry.size.width * 0.96, height: geometry.size.height * 0.45)

            Divider()

            SellListView(
                symbol: symbol,
                atrValue: atrValue
                )
            .frame(width: geometry.size.width * 0.96, height: geometry.size.height * 0.45)

        }
        .tabItem {
            Label("Sales Calc", systemImage: "calculator")
        }
    }
} 