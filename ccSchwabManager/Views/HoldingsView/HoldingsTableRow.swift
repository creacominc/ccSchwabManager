import SwiftUI

struct HoldingsTableRow: View {
    let position: Position
    let accountNumber: String
    let onTap: () -> Void
    let tradeDate: String
    let orderStatus: ActiveOrderStatus?
    let dte: String
    let isEvenRow: Bool
    let isSelected: Bool
    let copyToClipboard: (String) -> Void
    let copyToClipboardValue: (Double, String) -> Void
    
    public static let columnWidths: [CGFloat] = [0.12, 0.07, 0.07,
                                                 0.10, 0.08,
                                                 0.08,
                                                 0.08, 0.06,
                                                 0.12, 0.09, 0.09]

    // Helper function to get column width with adjustment for narrow layout
    public static func getColumnWidth(_ index: Int, viewWidth: CGFloat, isWide: Bool) -> CGFloat
    {
        let baseWidth = HoldingsTableRow.columnWidths[index] * viewWidth

        // For narrow layouts, some columns are hidden, so we need to redistribute the width
        if !isWide
        {
            // Columns 3, 4, 6, 7 are hidden in narrow layout
            let hiddenColumns = [3, 4, 6, 7]
            if hiddenColumns.contains(index) {
                return 0 // Hidden columns get 0 width
            }

            // Calculate total width of visible columns in narrow layout
            let visibleColumns = [0, 1, 2, 5, 8, 9, 10]
            let totalVisibleWidth = visibleColumns.reduce(0) { $0 + HoldingsTableRow.columnWidths[$1] }

            // Redistribute the hidden columns' width proportionally
            let hiddenWidth = 1.0 - totalVisibleWidth
            let redistributionFactor = hiddenWidth / totalVisibleWidth

            return baseWidth * (1.0 + redistributionFactor)
        }

        return baseWidth
    }

    // Helper function to show gain/loss dollar amount
    private func showGainLossDollar() -> String {
        return String(format: "%.2f", position.longOpenProfitLoss ?? 0.0)
    }

    private var plPercent: Double {
        let pl = position.longOpenProfitLoss ?? 0
        let mv = position.marketValue ?? 0
        let costBasis = mv - pl
        return costBasis != 0 ? (pl / costBasis) * 100 : 0
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 1024
            HStack(spacing: 4) {
                // symbol
                Text(position.instrument?.symbol ?? "N/A")
                    .tableCellFont(weight: .medium)
                    .foregroundColor(.primary)
                    .frame(width: HoldingsTableRow.getColumnWidth(0, viewWidth: geometry.size.width, isWide: isWide),
                           alignment: .leading )
                // copy button
                Button(action: {
                    copyToClipboard(position.instrument?.symbol ?? "")
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                // quantity
                Text("\(Int(position.longQuantity ?? 0))")
                    .tableCellFont()
                    .foregroundColor(.primary)
                    .frame(width: HoldingsTableRow.getColumnWidth(1, viewWidth: geometry.size.width, isWide: isWide),
                           alignment: .trailing)
                // average
                Text(String(format: "%.2f", position.averagePrice ?? 0.0))
                    .tableCellFont()
                    .foregroundColor(.primary)
                    .frame(width: HoldingsTableRow.getColumnWidth(2, viewWidth: geometry.size.width, isWide: isWide),
                           alignment: .trailing)
                // market and PL
                if isWide
                {
                    Text(String(format: "%.2f", position.marketValue ?? 0.0))
                        .tableCellFont()
                        .foregroundColor(.primary)
                        .frame(width: HoldingsTableRow.getColumnWidth(3, viewWidth: geometry.size.width, isWide: isWide),
                               alignment: .trailing)
                    Text(showGainLossDollar())
                        .tableCellFont()
                        .foregroundColor(plPercent >= 0 ? .green : .red)
                        .frame(width: HoldingsTableRow.getColumnWidth(4, viewWidth: geometry.size.width, isWide: isWide),
                               alignment: .trailing)
                }
                // P/L%
                Text(String(format: "%.2f%%", plPercent))
                    .tableCellFont()
                    .foregroundColor(plPercent >= 0 ? .green : .red)
                    .frame(width: HoldingsTableRow.getColumnWidth(5, viewWidth: geometry.size.width, isWide: isWide),
                           alignment: .trailing)
                // type and account
                if isWide
                {
                    Text(position.instrument?.assetType?.shortDisplayName ?? "N/A")
                        .tableCellFont()
                        .foregroundColor(.primary)
                        .frame(width: HoldingsTableRow.getColumnWidth(6, viewWidth: geometry.size.width, isWide: isWide),
                               alignment: .leading)
                    Text(accountNumber)
                        .tableCellFont()
                        .foregroundColor(.primary)
                        .frame(width: HoldingsTableRow.getColumnWidth(7, viewWidth: geometry.size.width, isWide: isWide),
                               alignment: .leading)
                }
                // last trade
                Text(tradeDate)
                    .tableCellFont()
                    .foregroundColor(.primary)
                    .frame(width: HoldingsTableRow.getColumnWidth(8, viewWidth: geometry.size.width, isWide: isWide),
                           alignment: .leading)
                // order
                Text(orderStatus?.shortDisplayName ?? "N/A")
                    .tableCellFont()
                    .foregroundColor(.primary)
                    .frame(width: HoldingsTableRow.getColumnWidth(9, viewWidth: geometry.size.width, isWide: isWide),
                           alignment: .leading)
                // dte
                Text(dte)
                    .tableCellFont()
                    .foregroundColor(.primary)
                    .frame(width: HoldingsTableRow.getColumnWidth(10, viewWidth: geometry.size.width, isWide: isWide),
                           alignment: .trailing)
            } // HStack
            .background(isEvenRow ? Color.clear : Color.gray.opacity(0.15))
            .onTapGesture {
                onTap()
            }
        } // GeometryReader
    } // View
}

// MARK: - Preview
#Preview("HoldingsTableRow", traits: .landscapeLeft) {
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
    
    return VStack(alignment: .center, spacing: 8) {
        ForEach(Array(samplePositions.enumerated()), id: \.element.id) { index, position in
            let orderStatus: ActiveOrderStatus = index == 0 ? .working : (index == 1 ? .accepted : .awaitingManualReview)
            let dte = index == 1 ? "45 / 100" : "N/A"
            let isEvenRow = index % 2 == 0
            let isSelected = index == 1

            HoldingsTableRow(
                position: position,
                accountNumber: "123456",
                onTap: { print("Row \(index) tapped") },
                tradeDate: "2024/01/\(15 + index)",
                orderStatus: orderStatus,
                dte: dte,
                isEvenRow: isEvenRow,
                isSelected: isSelected,
                copyToClipboard: { text in print("Copied: \(text)") },
                copyToClipboardValue: { value, format in print("Copied value: \(String(format: format, value))") }
            )
        }
    }
    .padding(.horizontal, 20)
    .padding(.trailing, 30)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}
