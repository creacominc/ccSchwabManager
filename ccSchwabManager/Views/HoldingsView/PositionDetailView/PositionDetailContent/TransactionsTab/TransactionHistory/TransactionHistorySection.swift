import SwiftUI

struct TransactionHistorySection: View {
    let isLoading: Bool
    let symbol: String
    let transactions: [Transaction]
    @State private var currentSort: TransactionSortConfig? = TransactionSortConfig(column: .date, ascending: TransactionSortableColumn.date.defaultAscending)
    @State private var copiedValue: String = "TBD"

    private var sortedTransactions: [Transaction] {
        guard let sortConfig = currentSort else { return transactions }
        print( "=== Sorting transactions ===  \(symbol)" )
        return transactions.sorted { t1, t2 in
            let ascending = sortConfig.ascending
            switch sortConfig.column {
            case .date:
                let date1 = t1.tradeDate ?? ""
                let date2 = t2.tradeDate ?? ""
                return ascending ? date1 < date2 : date1 > date2
            case .type:
                let type1 = (t1.netAmount ?? 0) < 0 ? "Buy" : (t1.netAmount ?? 0) > 0 ? "Sell" : "Unknown"
                let type2 = (t2.netAmount ?? 0) < 0 ? "Buy" : (t2.netAmount ?? 0) > 0 ? "Sell" : "Unknown"
                return ascending ? type1 < type2 : type1 > type2
            case .quantity:
                // get the amount from the first transferItem with instrumentSymbol matching symbol
                let transferItem1 = t1.transferItems.first(where: { $0.instrument?.symbol == symbol })
                let transferItem2 = t2.transferItems.first(where: { $0.instrument?.symbol == symbol })
                let qty1 = transferItem1?.amount ?? 0
                let qty2 = transferItem2?.amount ?? 0
                return ascending ? qty1 < qty2 : qty1 > qty2
            case .price:
                // get the price from the first transferItem with instrumentSymbol matching symbol
                let transferItem1 = t1.transferItems.first(where: { $0.instrument?.symbol == symbol })
                let transferItem2 = t2.transferItems.first(where: { $0.instrument?.symbol == symbol })
                let price1 = transferItem1?.price ?? 0
                let price2 = transferItem2?.price ?? 0
                return ascending ? price1 < price2 : price1 > price2
            case .netAmount:
                let amount1 = t1.netAmount ?? 0
                let amount2 = t2.netAmount ?? 0
                return ascending ? amount1 < amount2 : amount1 > amount2
            }
        }
    }

    private func copyToClipboard(value: Double, format: String) {
        let formattedValue = String(format: format, value)
#if os(iOS)
        UIPasteboard.general.string = formattedValue
        copiedValue = UIPasteboard.general.string ?? "no value"
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedValue, forType: .string)
        copiedValue = NSPasteboard.general.string(forType: .string) ?? "no value"
#endif
    }
    
    private func copyToClipboard(text: String) {
#if os(iOS)
        UIPasteboard.general.string = text
        copiedValue = UIPasteboard.general.string ?? "no value"
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedValue = NSPasteboard.general.string(forType: .string) ?? "no value"
#endif
    }

    @ViewBuilder
    private func columnHeader(title: String, column: TransactionSortableColumn, alignment: Alignment = .leading) -> some View {
        Button(action: {
            if currentSort?.column == column {
                currentSort?.ascending.toggle()
            } else {
                currentSort = TransactionSortConfig(column: column, ascending: column.defaultAscending)
            }
        }) {
            HStack {
                if alignment == .trailing {
                    Spacer()
                }
                Text(title)
                if alignment == .leading {
                    Spacer()
                }
                if currentSort?.column == column {
                    Image(systemName: currentSort?.ascending ?? true ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    static func round(_ value: Double, precision: Int) -> Double {
        let multiplier = pow(10.0, Double(precision))
        return (value * multiplier).rounded() / multiplier
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 16 * 2 
            let interColumnSpacing = (CGFloat(TransactionRow.columnProportions.count - 1) * 8)
            let availableWidthForColumns = geometry.size.width - interColumnSpacing - horizontalPadding
            let calculatedWidths = TransactionRow.columnProportions.map { $0 * availableWidthForColumns }
            
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle( CircularProgressViewStyle( tint: .accentColor ) )
                        .scaleEffect(2.0, anchor: .center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding()
                } else if transactions.isEmpty {
                    Text("No transactions available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding()
                } else {
                    VStack(spacing: 0) {
                        // Header row
                        HStack(spacing: 8) {
                            HStack {
                                columnHeader(title: "Date", column: .date)
                                Button(action: {
                                    CSVExporter.exportTransactions(sortedTransactions, symbol: symbol)
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(width: calculatedWidths[0])
                            
                            columnHeader(title: "Type", column: .type).frame(width: calculatedWidths[1])
                            columnHeader(title: "Quantity", column: .quantity, alignment: .trailing).frame(width: calculatedWidths[2])
                            columnHeader(title: "Price", column: .price, alignment: .trailing).frame(width: calculatedWidths[3])
                            columnHeader(title: "Net Amount", column: .netAmount, alignment: .trailing).frame(width: calculatedWidths[4])
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.1))
                        
                        Divider()

                        // Content area with calculated widths passed down
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(sortedTransactions.enumerated()), id: \.element.id) { index, transaction in
                                    TransactionRow(
                                        transaction: transaction,
                                        symbol: symbol,
                                        calculatedWidths: calculatedWidths,
                                        formatDate: formatDate,
                                        copyToClipboard: copyToClipboard,
                                        copyToClipboardValue: copyToClipboard,
                                        isEvenRow: index % 2 == 0
                                    )
                                }
                            }
                        }
                    }
                    
                    if copiedValue != "TBD" {
                        Text("Copied: \(copiedValue)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Preview Helpers
#Preview("TransactionHistorySection", traits: .landscapeLeft) {
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
    
    return TransactionHistorySection(
        isLoading: false,
        symbol: "AAPL",
        transactions: sampleTransactions
    )
    .padding()
}


#Preview("TransactionHistorySection - Loading", traits: .landscapeLeft) {
    TransactionHistorySection(
        isLoading: true,
        symbol: "AAPL",
        transactions: []
    )
    .padding()
}

#Preview("TransactionHistorySection - No Data", traits: .landscapeLeft) {
    TransactionHistorySection(
        isLoading: false,
        symbol: "AAPL",
        transactions: []
    )
    .padding()
}

