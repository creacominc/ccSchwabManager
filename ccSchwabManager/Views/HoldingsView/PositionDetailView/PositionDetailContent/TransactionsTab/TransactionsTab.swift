import SwiftUI

struct TransactionsTab: View
{
    let isLoading: Bool
    let symbol: String
    let transactions: [Transaction]
    let atrValue: Double
    let position: Position
    @Binding var sharesAvailableForTrading: Double
    @Binding var marketValue: Double
    let lastPrice: Double

    var body: some View
    {
        GeometryReader
        { geometry in
            VStack(alignment: .leading, spacing: 0)
            {
                // Section Header
                HStack
                {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.blue)
                    Text("Transactions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()

                    // Critical information on the same line
                    CriticalInfoRow(
                        sharesAvailableForTrading: sharesAvailableForTrading,
                        marketValue: marketValue,
                        position: position,
                        lastPrice: lastPrice,
                        atrValue: atrValue
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))

                // TransactionHistorySection has its own ScrollView for the rows
                TransactionHistorySection(
                    isLoading: isLoading,
                    symbol: symbol,
                    transactions: transactions
                )
                .frame(height: geometry.size.height - 50) // Subtract approximate header height
            }
        }
    }
}

#Preview("TransactionsTab - With Data", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 500
    @Previewable @State var marketValue: Double = 300.0
    @Previewable @State var lastPrice: Double = 50.50
    let atrValue: Double = 2.45 // Initial value from parent, will be recomputed

    let sampleTransactions = [
        Transaction(
            activityId: 12345,
            time: "2024-12-15T10:30:00+0000",
            tradeDate: "2024-12-15T10:30:00+0000",
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
            time: "2024-12-20T14:45:00+0000",
            tradeDate: "2024-12-20T14:45:00+0000",
            netAmount: -2500.00,
            transferItems: [
                TransferItem(
                    instrument: Instrument(
                        assetType: .EQUITY,
                        symbol: "AAPL",
                        instrumentId: 12346
                    ),
                    amount: 15.0,
                    price: 166.67
                )
            ]
        ),
        Transaction(
            activityId: 12347,
            time: "2025-01-05T09:15:00+0000",
            tradeDate: "2025-01-05T09:15:00+0000",
            netAmount: 1800.00,
            transferItems: [
                TransferItem(
                    instrument: Instrument(
                        assetType: .EQUITY,
                        symbol: "AAPL",
                        instrumentId: 12347
                    ),
                    amount: -10.0,
                    price: 180.00
                )
            ]
        ),
        Transaction(
            activityId: 12348,
            time: "2025-01-10T11:20:00+0000",
            tradeDate: "2025-01-10T11:20:00+0000",
            netAmount: -3200.00,
            transferItems: [
                TransferItem(
                    instrument: Instrument(
                        assetType: .EQUITY,
                        symbol: "AAPL",
                        instrumentId: 12348
                    ),
                    amount: 20.0,
                    price: 160.00
                )
            ]
        ),
        Transaction(
            activityId: 12349,
            time: "2025-01-18T13:45:00+0000",
            tradeDate: "2025-01-18T13:45:00+0000",
            netAmount: 2700.00,
            transferItems: [
                TransferItem(
                    instrument: Instrument(
                        assetType: .EQUITY,
                        symbol: "AAPL",
                        instrumentId: 12349
                    ),
                    amount: -15.0,
                    price: 180.00
                )
            ]
        )
    ]
    
    GeometryReader { geometry in
        VStack{
            createMockTabBar()
            TransactionsTab(
                isLoading: false,
                symbol: "AAPL",
                transactions: sampleTransactions,
                atrValue: atrValue,
                position: Position(shortQuantity: 0, longQuantity: 0,
                                   marketValue: marketValue, longOpenProfitLoss: 0.0),
                sharesAvailableForTrading: $sharesAvailableForTrading,
                marketValue: $marketValue,
                lastPrice: lastPrice
            )
        }
    }
    .padding()
}

#Preview("TransactionsTab - Loading State", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 500
    @Previewable @State var marketValue: Double = 300.0
    @Previewable @State var lastPrice: Double = 50.50
    let atrValue: Double = 2.45 // Initial value from parent, will be recomputed

    return GeometryReader { geometry in
        VStack{
            createMockTabBar()
            TransactionsTab(
                isLoading: true,
                symbol: "AAPL",
                transactions: [],
                atrValue: atrValue,
                position: Position(shortQuantity: 0, longQuantity: 0,
                                   marketValue: marketValue, longOpenProfitLoss: 0.0),
                sharesAvailableForTrading: $sharesAvailableForTrading,
                marketValue: $marketValue,
                lastPrice: lastPrice
            )
        }
    }
    .padding()
}

#Preview("TransactionsTab - Different Symbol", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 500
    @Previewable @State var marketValue: Double = 300.0
    @Previewable @State var lastPrice: Double = 50.50
    let atrValue: Double = 2.45 // Initial value from parent, will be recomputed
    
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
                transactions: sampleTransactions,
                atrValue: atrValue,
                position: Position(shortQuantity: 0, longQuantity: 0,
                                   marketValue: marketValue, longOpenProfitLoss: 0.0),
                sharesAvailableForTrading: $sharesAvailableForTrading,
                marketValue: $marketValue,
                lastPrice: lastPrice
            )
        }
    }
    .padding()
}

@MainActor
private func createMockTabBar() -> some View
{
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
            icon: "number.circle.fill",
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
