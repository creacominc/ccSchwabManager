import SwiftUI

struct TransactionsTab: View {
    let isLoading: Bool
    let symbol: String
    let transactions: [Transaction]
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                TransactionHistorySection(
                    isLoading: isLoading,
                    symbol: symbol,
                    transactions: transactions
                )
                .frame( width: geometry.size.width * 0.98, height: geometry.size.height * 0.95 )
            }
            .tabItem {
                Label("Transactions", systemImage: "list.bullet")
            }
        }
    }
}

#Preview("TransactionsTab - With Data", traits: .landscapeLeft) {
    let sampleTransactions = [
        Transaction(
            activityId: 12345,
            time: "2025-01-15T10:30:00+0000",
            tradeDate: "2025-01-15T10:30:00+0000",
            netAmount: -1500.00,
            transferItems: [
                TransferItem(
                    instrument: Instrument(
                        assetType: .EQUITY,
                        symbol: "AAPL",
                        instrumentId: 12345
                    ),
                    amount: 10.0,
                    price: 150.00
                )
            ]
        ),
        Transaction(
            activityId: 12346,
            time: "2025-01-16T14:45:00+0000",
            tradeDate: "2025-01-16T14:45:00+0000",
            netAmount: 2000.00,
            transferItems: [
                TransferItem(
                    instrument: Instrument(
                        assetType: .EQUITY,
                        symbol: "AAPL",
                        instrumentId: 12346
                    ),
                    amount: 8.0,
                    price: 250.00
                )
            ]
        )
    ]
    
    return GeometryReader { geometry in
        VStack{
            createMockTabBar()
            TransactionsTab(
                isLoading: false,
                symbol: "AAPL",
                transactions: sampleTransactions
            )
        }
    }
    .padding()
}

#Preview("TransactionsTab - Loading State", traits: .landscapeLeft) {
    return GeometryReader { geometry in
        VStack{
            createMockTabBar()
            TransactionsTab(
                isLoading: true,
                symbol: "AAPL",
                transactions: []
            )
        }
    }
    .padding()
}

#Preview("TransactionsTab - Different Symbol", traits: .landscapeLeft) {
    let sampleTransactions = [
        Transaction(
            activityId: 12347,
            time: "2025-01-17T09:15:00+0000",
            tradeDate: "2025-01-17T09:15:00+0000",
            netAmount: -750.00,
            transferItems: [
                TransferItem(
                    instrument: Instrument(
                        assetType: .EQUITY,
                        symbol: "MSFT",
                        instrumentId: 12347
                    ),
                    amount: 5.0,
                    price: 150.00
                )
            ]
        )
    ]
    
    return GeometryReader { geometry in
        VStack{
            createMockTabBar()
            TransactionsTab(
                isLoading: false,
                symbol: "MSFT",
                transactions: sampleTransactions
            )
        }
    }
    .padding()
}

@MainActor
private func createMockTabBar() -> some View {
    HStack(spacing: 0) {
        TabButton(
            title: "Details",
            icon: "info.circle",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Price History",
            icon: "chart.line.uptrend.xyaxis",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Transactions",
            icon: "list.bullet",
            isSelected: true,
            action: {}
        )
        TabButton(
            title: "Sales Calc",
            icon: "calculator",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Orders",
            icon: "doc.text",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "OCO",
            icon: "arrow.up.circle",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Sequence",
            icon: "arrow.up.circle",
            isSelected: false,
            action: {}
        )
    }
    .background(Color.gray.opacity(0.1))
    .padding(.horizontal)
    .padding(.bottom, 2)
}
