import SwiftUI

struct TransactionHistorySection: View {
    let isLoading: Bool
    let symbol: String
    let transactions: [Transaction]
    @State private var currentSort: TransactionSortConfig? = TransactionSortConfig(column: .date, ascending: TransactionSortableColumn.date.defaultAscending)
    @State private var copiedValue: String = "TBD"
    @State private var sortedTransactions: [TransactionWithComputedPrice] = []
    @State private var isProcessing: Bool = false
    
    // Track when transactions or sort config changes to trigger reprocessing
    @State private var lastProcessedTransactions: [Transaction] = []
    @State private var lastProcessedSort: TransactionSortConfig?
    
    private func processTransactions() {
        // Check if we need to reprocess
        let transactionsChanged = transactions.count != lastProcessedTransactions.count || 
                                 transactions.first?.activityId != lastProcessedTransactions.first?.activityId
        let sortChanged = currentSort?.column != lastProcessedSort?.column || 
                         currentSort?.ascending != lastProcessedSort?.ascending
        
        guard transactionsChanged || sortChanged else { return }
        
        // Show loading indicator for processing
        isProcessing = true
        
        // Capture values before detached task
        let transactionsToProcess = transactions
        let sortConfig = currentSort
        let symbolToProcess = symbol
        
        Task.detached(priority: .userInitiated) {
            print("=== Processing transactions for \(symbolToProcess) ===")
            
            // Compute prices for all transactions
            let withPrices = transactionsToProcess.map { TransactionWithComputedPrice(transaction: $0, symbol: symbolToProcess) }
            
            // Sort transactions
            let sorted: [TransactionWithComputedPrice]
            if let sortConfig = sortConfig {
                print("=== Sorting transactions ===  \(symbolToProcess)")
                sorted = withPrices.sorted { t1, t2 in
                    let ascending = sortConfig.ascending
                    switch sortConfig.column {
                    case .date:
                        let date1 = t1.transaction.tradeDate ?? ""
                        let date2 = t2.transaction.tradeDate ?? ""
                        return ascending ? date1 < date2 : date1 > date2
                    case .type:
                        let type1 = t1.transactionType
                        let type2 = t2.transactionType
                        return ascending ? type1 < type2 : type1 > type2
                    case .quantity:
                        let qty1 = t1.amount
                        let qty2 = t2.amount
                        return ascending ? qty1 < qty2 : qty1 > qty2
                    case .price:
                        let price1 = t1.computedPrice
                        let price2 = t2.computedPrice
                        return ascending ? price1 < price2 : price1 > price2
                    case .netAmount:
                        let amount1 = t1.transaction.netAmount ?? 0
                        let amount2 = t2.transaction.netAmount ?? 0
                        return ascending ? amount1 < amount2 : amount1 > amount2
                    }
                }
            } else {
                sorted = withPrices
            }
            
            // Update UI on main thread
            await MainActor.run {
                self.sortedTransactions = sorted
                self.lastProcessedTransactions = transactionsToProcess
                self.lastProcessedSort = sortConfig
                self.isProcessing = false
                print("=== Finished processing \(sorted.count) transactions for \(symbolToProcess) ===")
            }
        }
    }

    private func copyToClipboard(value: Double, format: String) {
        let formattedValue = String(format: format, value)
#if os(visionOS)
        UIPasteboard.general.string = formattedValue
        copiedValue = UIPasteboard.general.string ?? "no value"
#elseif os(iOS)
        UIPasteboard.general.string = formattedValue
        copiedValue = UIPasteboard.general.string ?? "no value"
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedValue, forType: .string)
        copiedValue = NSPasteboard.general.string(forType: .string) ?? "no value"
#endif
    }
    
    private func copyToClipboard(text: String) {
#if os(visionOS)
        UIPasteboard.general.string = text
        copiedValue = UIPasteboard.general.string ?? "no value"
#elseif os(iOS)
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
            // Trigger reprocessing when sort changes
            processTransactions()
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
                // Note: Global loading overlay from PositionDetailView handles all loading states
                // No need for local loading indicator to avoid duplicate spinners
                if transactions.isEmpty && !isLoading {
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
                                    CSVExporter.exportTransactions(sortedTransactions.map { $0.transaction }, symbol: symbol)
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
                                ForEach(Array(sortedTransactions.enumerated()), id: \.element.transaction.id) { index, transactionWithPrice in
                                    TransactionRow(
                                        transaction: transactionWithPrice.transaction,
                                        symbol: symbol,
                                        calculatedWidths: calculatedWidths,
                                        formatDate: formatDate,
                                        copyToClipboard: copyToClipboard,
                                        copyToClipboardValue: copyToClipboard,
                                        isEvenRow: index % 2 == 0,
                                        computedPrice: transactionWithPrice.computedPrice
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
        .onAppear {
            // Process transactions when view first appears
            processTransactions()
        }
        .onChange(of: transactions.count) { oldValue, newValue in
            // Reprocess when transactions change
            processTransactions()
        }
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
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

