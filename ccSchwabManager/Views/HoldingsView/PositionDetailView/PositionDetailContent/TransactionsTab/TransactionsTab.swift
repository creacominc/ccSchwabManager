import SwiftUI

struct TransactionsTab: View {
    let isLoading: Bool
    let symbol: String
    let geometry: GeometryProxy
    let transactions: [Transaction]
    
    var body: some View {
        ScrollView {
            TransactionHistorySection(
                isLoading: isLoading,
                symbol: symbol,
                transactions: transactions
            )
            .frame(width: geometry.size.width * 0.88, height: geometry.size.height * 0.90)
        }
        .tabItem {
            Label("Transactions", systemImage: "list.bullet")
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
        TransactionsTab(
            isLoading: false,
            symbol: "AAPL",
            geometry: geometry,
            transactions: sampleTransactions
        )
    }
    .padding()
}

#Preview("TransactionsTab - Loading State", traits: .landscapeLeft) {
    return GeometryReader { geometry in
        TransactionsTab(
            isLoading: true,
            symbol: "AAPL",
            geometry: geometry,
            transactions: []
        )
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
        TransactionsTab(
            isLoading: false,
            symbol: "MSFT",
            geometry: geometry,
            transactions: sampleTransactions
        )
    }
    .padding()
}
 
