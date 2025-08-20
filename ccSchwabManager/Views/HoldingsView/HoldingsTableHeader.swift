import SwiftUI

struct HoldingsTableHeader: View {
    @Binding var currentSort: SortConfig?
    let columnWidths: [CGFloat]
    let sortedHoldings: [Position]
    let accountPositions: [(Position, String, String)]
    let tradeDateCache: [String: String]
    let orderStatusCache: [String: ActiveOrderStatus?]
    let availableWidth: CGFloat
    
    // iPad Mini landscape width is 1024, so we'll use that as the breakpoint
    private let iPadBreakpoint: CGFloat = 1024

    @ViewBuilder
    private func columnHeader(title: String, column: SortableColumn, alignment: Alignment = .leading) -> some View {
        Button(action: {
            if currentSort?.column == column {
                currentSort?.ascending.toggle()
            } else {
                currentSort = SortConfig(column: column, ascending: column.defaultAscending)
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

    var body: some View {
        let isWide = availableWidth >= iPadBreakpoint
        
        HStack(spacing: 4) {
            // Symbol column (always shown)
            HStack {
                columnHeader(title: "Symbol", column: .symbol)
                Button(action: {
                    CSVExporter.exportHoldings(sortedHoldings, accountPositions: accountPositions, tradeDates: tradeDateCache, orderStatuses: orderStatusCache)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .frame(width: getColumnWidth(0) * availableWidth)
            
            // Quantity column (always shown)
            columnHeader(title: "Qty", column: .quantity, alignment: .trailing)
                .frame(width: getColumnWidth(1) * availableWidth)
            
            // Average column (always shown)
            columnHeader(title: "Avg", column: .avgPrice, alignment: .trailing)
                .frame(width: getColumnWidth(2) * availableWidth)
            
            // Market column (only shown in wide layout)
            if isWide {
                columnHeader(title: "Market", column: .marketValue, alignment: .trailing)
                    .frame(width: getColumnWidth(3) * availableWidth)
            }
            
            // P/L column (only shown in wide layout)
            if isWide {
                columnHeader(title: "P/L", column: .pl, alignment: .trailing)
                    .frame(width: getColumnWidth(4) * availableWidth)
            }
            
            // P/L% column (always shown)
            columnHeader(title: "P/L%", column: .plPercent, alignment: .trailing)
                .frame(width: getColumnWidth(5) * availableWidth)
            
            // Type column (only shown in wide layout)
            if isWide {
                columnHeader(title: "Type", column: .assetType)
                    .frame(width: getColumnWidth(6) * availableWidth)
            }
            
            // Account column (only shown in wide layout)
            if isWide {
                columnHeader(title: "Acnt", column: .account)
                    .frame(width: getColumnWidth(7) * availableWidth)
            }
            
            // Last Trade column (always shown)
            columnHeader(title: "Last Trade", column: .lastTradeDate)
                .frame(width: getColumnWidth(8) * availableWidth)
            
            // Order column (always shown)
            columnHeader(title: "Order", column: .orderStatus)
                .frame(width: getColumnWidth(9) * availableWidth)
            
            // DTE/# column (always shown)
            columnHeader(title: "DTE/#", column: .dte, alignment: .trailing)
                .frame(width: getColumnWidth(10) * availableWidth)
        }
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .frame(maxWidth: .infinity, minHeight: 25)
    }
    
    // Helper function to get column width with adjustment for narrow layout
    private func getColumnWidth(_ index: Int) -> CGFloat {
        let baseWidth = columnWidths[index]
        let isWide = availableWidth >= iPadBreakpoint
        
        // For narrow layouts, some columns are hidden, so we need to redistribute the width
        if !isWide {
            // Columns 3, 4, 6, 7 are hidden in narrow layout
            let hiddenColumns = [3, 4, 6, 7]
            if hiddenColumns.contains(index) {
                return 0 // Hidden columns get 0 width
            }
            
            // Calculate total width of visible columns in narrow layout
            let visibleColumns = [0, 1, 2, 5, 8, 9, 10]
            let totalVisibleWidth = visibleColumns.reduce(0) { $0 + columnWidths[$1] }
            
            // Redistribute the hidden columns' width proportionally
            let hiddenWidth = 1.0 - totalVisibleWidth
            let redistributionFactor = hiddenWidth / totalVisibleWidth
            
            return baseWidth * (1.0 + redistributionFactor)
        }
        
        return baseWidth
    }
}

// MARK: - Preview
#Preview("HoldingsTableHeader", traits: .landscapeLeft) {
    let samplePositions = [
        Position(
            shortQuantity: 0.0,
            averagePrice: 150.0,
            longQuantity: 100.0,
            instrument: Instrument(
                assetType: .EQUITY,
                symbol: "AAPL",
                description: "Apple Inc."
            ),
            marketValue: 15500.0,
            longOpenProfitLoss: 500.0
        ),
        Position(
            shortQuantity: 0.0,
            averagePrice: 25.0,
            longQuantity: 50.0,
            instrument: Instrument(
                assetType: .OPTION,
                symbol: "AAPL240119C00150000",
                description: "AAPL Jan 19 2024 150 Call"
            ),
            marketValue: 1000.0,
            longOpenProfitLoss: -250.0
        ),
        Position(
            shortQuantity: 0.0,
            averagePrice: 75.0,
            longQuantity: 200.0,
            instrument: Instrument(
                assetType: .EQUITY,
                symbol: "MSFT",
                description: "Microsoft Corporation"
            ),
            marketValue: 15000.0,
            longOpenProfitLoss: 0.0
        )
    ]
    
    let sampleAccountPositions = samplePositions.map { position in
        (position, "123456", "Main Account")
    }
    
    let sampleTradeDateCache = [
        "AAPL": "2024/01/15",
        "AAPL240119C00150000": "2024/01/16",
        "MSFT": "2024/01/17"
    ]
    
    let sampleOrderStatusCache = [
        "AAPL": ActiveOrderStatus.working,
        "AAPL240119C00150000": ActiveOrderStatus.accepted,
        "MSFT": ActiveOrderStatus.awaitingManualReview
    ]
    
    return VStack(spacing: 0) {
            HoldingsTableHeader(
                currentSort: .constant(SortConfig(column: .symbol, ascending: true)),
                columnWidths: HoldingsTableRow.columnWidths,
                sortedHoldings: samplePositions,
                accountPositions: sampleAccountPositions,
                tradeDateCache: sampleTradeDateCache,
                orderStatusCache: sampleOrderStatusCache,
                availableWidth: 1024 // Assuming a fixed width for preview
            )

            ForEach(Array(samplePositions.enumerated()), id: \.element.id) { index, position in
                HoldingsTableRow(
                    position: position,
                    accountNumber: "123456",
                    onTap: { print("Row \(index) tapped") },
                    tradeDate: sampleTradeDateCache[position.instrument?.symbol ?? ""] ?? "0000",
                    orderStatus: sampleOrderStatusCache[position.instrument?.symbol ?? ""],
                    dte: index == 1 ? "45 / 100" : "N/A",
                    isEvenRow: index % 2 == 0,
                    isSelected: false,
                    copyToClipboard: { text in print("Copied: \(text)") },
                    copyToClipboardValue: { value, format in print("Copied value: \(String(format: format, value))") },
                    availableWidth: 1024 // Assuming a fixed width for preview
                )
            }
    }
}
