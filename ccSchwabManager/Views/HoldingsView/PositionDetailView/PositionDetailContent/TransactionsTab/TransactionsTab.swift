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

#Preview("TransactionsTab - With Data", traits: .landscapeLeft) {
    GeometryReader { geometry in
        TransactionsTab(
            isLoading: false,
            symbol: "AAPL",
            geometry: geometry
        )
    }
    .frame(width: 800, height: 600)
    .padding()
}

#Preview("TransactionsTab - Loading State", traits: .landscapeLeft) {
    GeometryReader { geometry in
        TransactionsTab(
            isLoading: true,
            symbol: "AAPL",
            geometry: geometry
        )
    }
    .frame(width: 800, height: 600)
    .padding()
}

#Preview("TransactionsTab - Different Symbol", traits: .landscapeLeft) {
    GeometryReader { geometry in
        TransactionsTab(
            isLoading: false,
            symbol: "MSFT",
            geometry: geometry
        )
    }
    .frame(width: 800, height: 600)
    .padding()
} 
