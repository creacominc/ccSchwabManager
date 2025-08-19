import SwiftUI


struct TransactionRow: View {
    let transaction: Transaction
    let symbol: String
    let calculatedWidths: [CGFloat]
    let formatDate: (String?) -> String
    let copyToClipboard: (String) -> Void
    let copyToClipboardValue: (Double, String) -> Void
    let isEvenRow: Bool
    
    @State private var isHovered = false
    public static let columnProportions: [CGFloat] = [0.30, 0.10, 0.20, 0.20, 0.20] // Date, Type, Qty, Price, Net Amount

    
    private var isSell: Bool {
        return transaction.netAmount ?? 0 > 0
    }
    
    private func round(_ value: Double, precision: Int) -> Double {
        let multiplier = pow(10.0, Double(precision))
        return (value * multiplier).rounded() / multiplier
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(formatDate(transaction.tradeDate))
                .frame(width: calculatedWidths[0], alignment: .leading)
                .onTapGesture {
                    copyToClipboard(formatDate(transaction.tradeDate))
                }
            Text(transaction.netAmount ?? 0 < 0 ? "Buy" : transaction.netAmount ?? 0 > 0 ? "Sell" : "Unknown")
                .frame(width: calculatedWidths[1], alignment: .leading)
                .onTapGesture {
                    copyToClipboard(transaction.netAmount ?? 0 < 0 ? "Buy" : transaction.netAmount ?? 0 > 0 ? "Sell" : "Unknown")
                }
            if let transferItem = transaction.transferItems.first(where: { $0.instrument?.symbol == symbol }) {
                let amount = round(transferItem.amount ?? 0, precision: 4)
                // Use computed price for merged/renamed securities
                let computedPrice = SchwabClient.shared.getComputedPriceForTransaction(transaction, symbol: symbol)
                let price = round(computedPrice, precision: 2)
                Text(String(format: "%.4f", amount))
                    .frame(width: calculatedWidths[2], alignment: .trailing)
                    .onTapGesture {
                        copyToClipboardValue(amount, "%.4f")
                    }
                Text(String(format: "%.2f", price))
                    .frame(width: calculatedWidths[3], alignment: .trailing)
                    .onTapGesture {
                        copyToClipboardValue(price, "%.2f")
                    }
            } else {
                Text("").frame(width: calculatedWidths[2])
                Text("").frame(width: calculatedWidths[3])
            }
            Text(String(format: "%.2f", transaction.netAmount ?? 0))
                .frame(width: calculatedWidths[4], alignment: .trailing)
                .onTapGesture {
                    copyToClipboardValue(transaction.netAmount ?? 0, "%.2f")
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 3)
        .background(rowBackgroundColor)
        .foregroundColor(isSell ? .red : .primary)
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
        Divider()
    }
    
    private var rowBackgroundColor: Color {
        if isHovered {
            return Color.gray.opacity(0.1)
        } else if isEvenRow {
            return Color.clear
        } else {
            return Color.gray.opacity(0.05)
        }
    }
}


// MARK: - Preview Helper
struct TransactionRowPreviewHelper {
    static func calculateWidths(for containerWidth: CGFloat) -> [CGFloat] {
        let horizontalPadding: CGFloat = 16 * 2
        let interColumnSpacing = (CGFloat(TransactionRow.columnProportions.count - 1) * 8)
        let availableWidthForColumns = containerWidth - interColumnSpacing - horizontalPadding
        return TransactionRow.columnProportions.map { $0 * availableWidthForColumns }
    }
}

#Preview("TransactionRows w/ Header", traits: .landscapeLeft) {
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
        ),
        Transaction(
            activityId: 12347,
            time: "2025-01-17T09:15:00+0000",
            tradeDate: "2025-01-17T09:15:00+0000",
            netAmount: -750.00,
            transferItems: [
                TransferItem(
                    instrument: Instrument(
                        assetType: .EQUITY,
                        symbol: "AAPL",
                        instrumentId: 12347
                    ),
                    amount: 5.0,
                    price: 150.00
                )
            ]
        )
    ]

    return GeometryReader { geometry in
        let calculatedWidths = TransactionRowPreviewHelper.calculateWidths(for: geometry.size.width)
        
        VStack(spacing: 0) {
            // Header row (simulating the actual header)
            HStack(spacing: 8) {
                HStack {
                    Text("Date")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: calculatedWidths[0])
                
                Text("Type").frame(width: calculatedWidths[1])
                Text("Quantity").frame(width: calculatedWidths[2], alignment: .trailing)
                Text("Price").frame(width: calculatedWidths[3], alignment: .trailing)
                Text("Net Amount").frame(width: calculatedWidths[4], alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.1))
            
            Divider()

            ForEach(Array(sampleTransactions.enumerated()), id: \.element.id) { index, transaction in
                // Transaction row
                TransactionRow(
                    transaction: transaction,
                    symbol: "AAPL",
                    calculatedWidths: calculatedWidths,
                    formatDate: { dateString in
                        guard let dateString = dateString,
                              let date = ISO8601DateFormatter().date(from: dateString) else {
                            return ""
                        }
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        return formatter.string(from: date)
                    },
                    copyToClipboard: { _ in },
                    copyToClipboardValue: { _, _ in },
                    isEvenRow: false
                )
            }
        }
    }
    .padding()
}

#Preview("TransactionRow - Buy Transaction", traits: .landscapeLeft) {
    let sampleTransaction = Transaction(
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
    )
    
    return GeometryReader { geometry in
        let calculatedWidths = TransactionRowPreviewHelper.calculateWidths(for: geometry.size.width)
        
        TransactionRow(
            transaction: sampleTransaction,
            symbol: "AAPL",
            calculatedWidths: calculatedWidths,
            formatDate: { dateString in
                guard let dateString = dateString,
                      let date = ISO8601DateFormatter().date(from: dateString) else {
                    return ""
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter.string(from: date)
            },
            copyToClipboard: { _ in },
            copyToClipboardValue: { _, _ in },
            isEvenRow: false
        )
    }
    .padding()
}

#Preview("TransactionRow - Sell Transaction", traits: .landscapeLeft) {
    let sampleTransaction = Transaction(
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
    
    return GeometryReader { geometry in
        let calculatedWidths = TransactionRowPreviewHelper.calculateWidths(for: geometry.size.width)
        
        TransactionRow(
            transaction: sampleTransaction,
            symbol: "AAPL",
            calculatedWidths: calculatedWidths,
            formatDate: { dateString in
                guard let dateString = dateString,
                      let date = ISO8601DateFormatter().date(from: dateString) else {
                    return ""
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter.string(from: date)
            },
            copyToClipboard: { _ in },
            copyToClipboardValue: { _, _ in },
            isEvenRow: true
        )
    }
    .padding()
}
