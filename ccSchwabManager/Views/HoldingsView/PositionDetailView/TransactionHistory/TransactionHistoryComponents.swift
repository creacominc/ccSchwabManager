import SwiftUI

// ADD Definitions for Transaction Sorting
struct TransactionSortConfig: Equatable {
    var column: TransactionSortableColumn
    var ascending: Bool
}

enum TransactionSortableColumn: String, CaseIterable, Identifiable {
    case date = "Date"
    case type = "Type" // Buy/Sell derived from netAmount
    case quantity = "Quantity"
    case price = "Price"
    case netAmount = "Net Amount"

    var id: String { self.rawValue }

    var defaultAscending: Bool {
        switch self {
        case .date, .quantity, .price:
            return false // Typically newest first
        case .type, .netAmount:
            return true
        }
    }
}

struct TransactionHistorySection: View {
    let isLoading: Bool
    let symbol: String
    @State private var currentSort: TransactionSortConfig? = TransactionSortConfig(column: .date, ascending: TransactionSortableColumn.date.defaultAscending)
    @State private var copiedValue: String = "TBD"

    private var sortedTransactions: [Transaction] {
        guard let sortConfig = currentSort else { return SchwabClient.shared.getTransactionsFor( symbol: symbol ) }
        print( "=== Sorting transactions ===  \(symbol)" )
        return SchwabClient.shared.getTransactionsFor( symbol: symbol ).sorted { t1, t2 in
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

    // Define proportional widths for columns
    private let columnProportions: [CGFloat] = [0.25, 0.15, 0.20, 0.20, 0.20] // Date, Type, Qty, Price, Net Amount

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

    private static func round(_ value: Double, precision: Int) -> Double {
        let multiplier = pow(10.0, Double(precision))
        return (value * multiplier).rounded() / multiplier
    }

    struct TransactionRow: View {
        let transaction: Transaction
        let symbol: String
        let calculatedWidths: [CGFloat]
        let formatDate: (String?) -> String
        let copyToClipboard: (String) -> Void
        let copyToClipboardValue: (Double, String) -> Void
        let isEvenRow: Bool
        
        @State private var isHovered = false
        
        private var isSell: Bool {
            return transaction.netAmount ?? 0 > 0
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
                    let amount = TransactionHistorySection.round(transferItem.amount ?? 0, precision: 4)
                    // Use computed price for merged/renamed securities
                    let computedPrice = SchwabClient.shared.getComputedPriceForTransaction(transaction, symbol: symbol)
                    let price = TransactionHistorySection.round(computedPrice, precision: 2)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView()
                    .progressViewStyle( CircularProgressViewStyle( tint: .accentColor ) )
                    .scaleEffect(2.0, anchor: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if SchwabClient.shared.getTransactionsFor( symbol: symbol ).isEmpty {
                Text("No transactions available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                GeometryReader { geometry in
                    // Account for HStack spacing AND its horizontal padding (assuming default ~16pts per side)
                    let horizontalPadding: CGFloat = 16 * 2 
                    let interColumnSpacing = (CGFloat(columnProportions.count - 1) * 8) // 8 is the HStack spacing
                    let availableWidthForColumns = geometry.size.width - interColumnSpacing - horizontalPadding
                    let calculatedWidths = columnProportions.map { $0 * availableWidthForColumns }

                    VStack(spacing: 0) {
                        HStack(spacing: 4) {
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
                            // right justify the Quantity column header
                            columnHeader(title: "Quantity", column: .quantity, alignment: .trailing).frame(width: calculatedWidths[2])
                            // right justify the Price column header
                            columnHeader(title: "Price", column: .price, alignment: .trailing).frame(width: calculatedWidths[3])
                            // right justify the Net Amount column header
                            columnHeader(title: "Net Amount", column: .netAmount, alignment: .trailing).frame(width: calculatedWidths[4])
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.1))
                        
                        Divider()

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
        .padding(.vertical)
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
