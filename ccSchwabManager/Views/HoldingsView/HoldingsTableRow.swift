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
    let availableWidth: CGFloat

    public static let columnWidths: [CGFloat] = [0.12, 0.07, 0.07, 0.10, 0.08, 0.08, 0.08, 0.06, 0.12, 0.09, 0.09]

    // iPad Mini landscape width is 1024, so we'll use that as the breakpoint
    private let iPadBreakpoint: CGFloat = 1024

//    @State private var isHovered = false

    private var plPercent: Double {
        let pl = position.longOpenProfitLoss ?? 0
        let mv = position.marketValue ?? 0
        let costBasis = mv - pl
        return costBasis != 0 ? (pl / costBasis) * 100 : 0
    }

    private var plColor: Color {
        if plPercent < 0 {
            return .red
        } else if plPercent < 6 {
            return .orange // Amber-like color
        } else {
            return .primary
        }
    }

//    private var orderStatusText: String {
//        let text = orderStatus?.shortDisplayName ?? "None"
//        return text
//    }

    private var orderStatusColor: Color {
        guard let status = orderStatus else { return .secondary }
        
        switch status {
        case .working:
            return .green
        case .awaitingSellStopCondition, .awaitingBuyStopCondition, .awaitingCondition:
            return .orange
        case .awaitingManualReview:
            return .red
        default:
            return .blue
        }
    }

//    private var isWideLayout: Bool {
//        // This will be computed in the GeometryReader
//        return false // Placeholder, will be set in body
//    }

    var body: some View {
        let isWide = availableWidth >= iPadBreakpoint
        
        HStack(spacing: 4) {
            symbolColumn(isWide: isWide)
            quantityColumn(isWide: isWide)
            averageColumn(isWide: isWide)
            
            if isWide {
                marketColumn(isWide: isWide)
                plColumn(isWide: isWide)
            }
            
            plPercentColumn(isWide: isWide)
            
            if isWide {
                typeColumn(isWide: isWide)
                accountColumn(isWide: isWide)
            }
            
            lastTradeColumn(isWide: isWide)
            orderColumn(isWide: isWide)
            dteColumn(isWide: isWide)
        }
        .frame(maxWidth: .infinity)
        .background(isEvenRow ? Color.clear : Color.gray.opacity(0.15))
        .onTapGesture {
            onTap()
        }
        .frame(maxWidth: .infinity, minHeight: 18)
    }
    
    // MARK: - Column Views
    @ViewBuilder
    private func symbolColumn(isWide: Bool) -> some View {
        HStack {
            Text(position.instrument?.symbol ?? "N/A")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                copyToClipboard(position.instrument?.symbol ?? "")
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .frame(width: getColumnWidth(0, isWide: isWide) * availableWidth)
    }
    
    @ViewBuilder
    private func quantityColumn(isWide: Bool) -> some View {
        Text("\(Int(position.longQuantity ?? 0))")
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(1, isWide: isWide) * availableWidth, alignment: .trailing)
    }
    
    @ViewBuilder
    private func averageColumn(isWide: Bool) -> some View {
        Text(String(format: "%.2f", position.averagePrice ?? 0.0))
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(2, isWide: isWide) * availableWidth, alignment: .trailing)
    }
    
    @ViewBuilder
    private func marketColumn(isWide: Bool) -> some View {
        Text(String(format: "%.2f", position.marketValue ?? 0.0))
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(3, isWide: isWide) * availableWidth, alignment: .trailing)
    }
    
    @ViewBuilder
    private func plColumn(isWide: Bool) -> some View {
        Text(showGainLossDollar())
            .font(.system(size: 14))
            .foregroundColor(plPercent >= 0 ? .green : .red)
            .frame(width: getColumnWidth(4, isWide: isWide) * availableWidth, alignment: .trailing)
    }
    
    @ViewBuilder
    private func plPercentColumn(isWide: Bool) -> some View {
        Text(String(format: "%.2f%%", plPercent))
            .font(.system(size: 14))
            .foregroundColor(plPercent >= 0 ? .green : .red)
            .frame(width: getColumnWidth(5, isWide: isWide) * availableWidth, alignment: .trailing)
    }
    
    @ViewBuilder
    private func typeColumn(isWide: Bool) -> some View {
        Text(position.instrument?.assetType?.rawValue ?? "N/A")
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(6, isWide: isWide) * availableWidth, alignment: .leading)
    }
    
    @ViewBuilder
    private func accountColumn(isWide: Bool) -> some View {
        Text(accountNumber)
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(7, isWide: isWide) * availableWidth, alignment: .leading)
    }
    
    @ViewBuilder
    private func lastTradeColumn(isWide: Bool) -> some View {
        Text(tradeDate)
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(8, isWide: isWide) * availableWidth, alignment: .leading)
    }
    
    @ViewBuilder
    private func orderColumn(isWide: Bool) -> some View {
        Text(orderStatus?.rawValue ?? "N/A")
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(9, isWide: isWide) * availableWidth, alignment: .leading)
    }
    
    @ViewBuilder
    private func dteColumn(isWide: Bool) -> some View {
        Text(dte)
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(10, isWide: isWide) * availableWidth, alignment: .trailing)
    }
    
    // Helper function to get column width with adjustment for narrow layout
    private func getColumnWidth(_ index: Int, isWide: Bool) -> CGFloat {
        let baseWidth = HoldingsTableRow.columnWidths[index]
        
        // For narrow layouts, some columns are hidden, so we need to redistribute the width
        if !isWide {
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
    
    return VStack(spacing: 1) {
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
                copyToClipboardValue: { value, format in print("Copied value: \(String(format: format, value))") },
                availableWidth: 1024 // Assuming a fixed width for preview
            )
        }
    }
    //.padding()
    .background(Color.gray.opacity(0.05))
}
