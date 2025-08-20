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

    public static let columnWidths: [CGFloat] = [0.12, 0.07, 0.07, 0.10, 0.08, 0.08, 0.08, 0.06, 0.13, 0.09, 0.06]
    
    // iPad Mini landscape width is 1024, so we'll use that as the breakpoint
    private let iPadBreakpoint: CGFloat = 1024

    @State private var isHovered = false
    
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
    
    private var orderStatusText: String {
        let text = orderStatus?.shortDisplayName ?? "None"
        // print("[HoldingsTable] Symbol: \(position.instrument?.symbol ?? "") shows order status: \(text) (\(orderStatus?.rawValue ?? "nil"))")
        return text
    }
    
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
    
    private var isWideLayout: Bool {
        // This will be computed in the GeometryReader
        return false // Placeholder, will be set in body
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= iPadBreakpoint
            
            VStack(spacing: 0) {
                // Main content row
                HStack(spacing: 4) {
                    symbolColumn(geometry: geometry)
                    quantityColumn(geometry: geometry)
                    averageColumn(geometry: geometry)
                    
                    if isWide {
                        marketColumn(geometry: geometry)
                        plColumn(geometry: geometry)
                    }
                    
                    plPercentColumn(geometry: geometry)
                    
                    if isWide {
                        typeColumn(geometry: geometry)
                        accountColumn(geometry: geometry)
                    }
                    
                    lastTradeColumn(geometry: geometry)
                    orderColumn(geometry: geometry)
                    dteColumn(geometry: geometry)
                }
                .padding(.vertical, 5)
                .background(isEvenRow ? Color.gray.opacity(0.05) : Color.clear)
                .onTapGesture {
                    onTap()
                }
            }
        }
        .frame(height: 20)
    }
    
    // MARK: - Column Views
    
    @ViewBuilder
    private func symbolColumn(geometry: GeometryProxy) -> some View {
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
        .frame(width: getColumnWidth(0, geometry: geometry) * geometry.size.width)
    }
    
    @ViewBuilder
    private func quantityColumn(geometry: GeometryProxy) -> some View {
        Text("\(Int(position.longQuantity ?? 0))")
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(1, geometry: geometry) * geometry.size.width, alignment: .trailing)
    }
    
    @ViewBuilder
    private func averageColumn(geometry: GeometryProxy) -> some View {
        Text(String(format: "%.2f", position.averagePrice ?? 0.0))
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(2, geometry: geometry) * geometry.size.width, alignment: .trailing)
    }
    
    @ViewBuilder
    private func marketColumn(geometry: GeometryProxy) -> some View {
        Text(String(format: "%.2f", position.marketValue ?? 0.0))
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: HoldingsTableRow.columnWidths[3] * geometry.size.width, alignment: .trailing)
    }
    
    @ViewBuilder
    private func plColumn(geometry: GeometryProxy) -> some View {
        Text(showGainLossDollar())
            .font(.system(size: 14))
            .foregroundColor(plPercent >= 0 ? .green : .red)
            .frame(width: HoldingsTableRow.columnWidths[4] * geometry.size.width, alignment: .trailing)
    }
    
    @ViewBuilder
    private func plPercentColumn(geometry: GeometryProxy) -> some View {
        Text(String(format: "%.2f%%", plPercent))
            .font(.system(size: 14))
            .foregroundColor(plPercent >= 0 ? .green : .red)
            .frame(width: getColumnWidth(5, geometry: geometry) * geometry.size.width, alignment: .trailing)
    }
    
    @ViewBuilder
    private func typeColumn(geometry: GeometryProxy) -> some View {
        Text(position.instrument?.assetType?.rawValue ?? "N/A")
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: HoldingsTableRow.columnWidths[6] * geometry.size.width, alignment: .leading)
    }
    
    @ViewBuilder
    private func accountColumn(geometry: GeometryProxy) -> some View {
        Text(accountNumber)
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: HoldingsTableRow.columnWidths[7] * geometry.size.width, alignment: .leading)
    }
    
    @ViewBuilder
    private func lastTradeColumn(geometry: GeometryProxy) -> some View {
        Text(tradeDate)
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: HoldingsTableRow.columnWidths[8] * geometry.size.width, alignment: .leading)
    }
    
    @ViewBuilder
    private func orderColumn(geometry: GeometryProxy) -> some View {
        Text(orderStatus?.rawValue ?? "N/A")
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(9, geometry: geometry) * geometry.size.width, alignment: .leading)
    }
    
    @ViewBuilder
    private func dteColumn(geometry: GeometryProxy) -> some View {
        Text(dte)
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .frame(width: getColumnWidth(10, geometry: geometry) * geometry.size.width, alignment: .trailing)
    }
    
    // Helper function to get column width with 50% increase for narrow layout
    private func getColumnWidth(_ index: Int, geometry: GeometryProxy) -> CGFloat {
        let baseWidth = HoldingsTableRow.columnWidths[index]
        if geometry.size.width < iPadBreakpoint {
            // Increase width by 50% for narrow layout
            return baseWidth * 1.5
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
                copyToClipboardValue: { value, format in print("Copied value: \(String(format: format, value))") }
            )
        }
    }
    .padding()
    .background(Color.gray.opacity(0.05))
}
