import SwiftUI

struct HoldingsTableHeader: View {
    @Binding var currentSort: SortConfig?
    let columnWidths: [CGFloat]
    let sortedHoldings: [Position]
    let accountPositions: [(Position, String, String)]
    let tradeDateCache: [String: String]
    let orderStatusCache: [String: ActiveOrderStatus?]

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
                GeometryReader { geometry in
                    let isWide = geometry.size.width >= 1024
                    HStack(spacing: 4) {
                        // Symbol column (always shown)
                        columnHeader(title: "Symbol", column: .symbol)
                            .frame(width: HoldingsTableRow.getColumnWidth(0, viewWidth: geometry.size.width, isWide: isWide),
                                   alignment: .leading)
                        
                        // Export button (separate element like in data rows)
                        Button(action: {
                            CSVExporter.exportHoldings(sortedHoldings, accountPositions: accountPositions, tradeDates: tradeDateCache, orderStatuses: orderStatusCache)
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        // Quantity column (always shown)
                        columnHeader(title: "Qty", column: .quantity, alignment: .trailing)
                            .frame(width: HoldingsTableRow.getColumnWidth(1, viewWidth: geometry.size.width, isWide: isWide),
                                   alignment: .trailing)
                        
                        // Average column (always shown)
                        columnHeader(title: "Avg", column: .avgPrice, alignment: .trailing)
                            .frame(width: HoldingsTableRow.getColumnWidth(2, viewWidth: geometry.size.width, isWide: isWide),
                                   alignment: .trailing)
                        
                        if isWide
                        {
                            // Market column (only shown in wide layout)
                            columnHeader(title: "Market", column: .marketValue, alignment: .trailing)
                                .frame(width: HoldingsTableRow.getColumnWidth(3, viewWidth: geometry.size.width, isWide: isWide),
                                       alignment: .trailing)
                            
                            // P/L column (only shown in wide layout)
                            columnHeader(title: "P/L", column: .pl, alignment: .trailing)
                                .frame(width: HoldingsTableRow.getColumnWidth(4, viewWidth: geometry.size.width, isWide: isWide),
                                       alignment: .trailing)
                        }
                        
                        // P/L% column (always shown)
                        columnHeader(title: "P/L%", column: .plPercent, alignment: .trailing)
                            .frame(width: HoldingsTableRow.getColumnWidth(5, viewWidth: geometry.size.width, isWide: isWide),
                                   alignment: .trailing)
                        
                        if isWide {
                            // Type column (only shown in wide layout)
                            columnHeader(title: "Type", column: .assetType)
                                .frame(width: HoldingsTableRow.getColumnWidth(6, viewWidth: geometry.size.width, isWide: isWide),
                                       alignment: .leading)
                            
                            // Account column (only shown in wide layout)
                            columnHeader(title: "Acnt", column: .account)
                                .frame(width: HoldingsTableRow.getColumnWidth(7, viewWidth: geometry.size.width, isWide: isWide),
                                       alignment: .leading)
                        }
                        
                        // Last Trade column (always shown)
                        columnHeader(title: "Last", column: .lastTradeDate)
                            .frame(width: HoldingsTableRow.getColumnWidth(8, viewWidth: geometry.size.width, isWide: isWide),
                                   alignment: .leading)
                        
                        // Order column (always shown)
                        columnHeader(title: "Order", column: .orderStatus)
                            .frame(width: HoldingsTableRow.getColumnWidth(9, viewWidth: geometry.size.width, isWide: isWide),
                                   alignment: .leading)
                        
                        // DTE/# column (always shown)
                        columnHeader(title: "DTE/#", column: .dte, alignment: .trailing)
                            .frame(width: HoldingsTableRow.getColumnWidth(10, viewWidth: geometry.size.width, isWide: isWide),
                                   alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .frame(maxWidth: .infinity, minHeight: 25)
                }
                .padding(.trailing, 42)   // match typical scrollbar width
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
            )
    }
    .padding(.horizontal, 20)
    .padding(.trailing, 30)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}
