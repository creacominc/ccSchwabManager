import SwiftUI

struct HoldingsTable: View {
    let sortedHoldings: [Position]
    @Binding var selectedPositionId: Position.ID?
    let accountPositions: [(Position, String, String)]
    @Binding var currentSort: SortConfig?
    let viewSize: CGSize
    let tradeDateCache: [String: String]
    let orderStatusCache: [String: ActiveOrderStatus?]
    @State private var copiedValue: String = "TBD"

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

    var body: some View {
        VStack(spacing: 0) {
            HoldingsTableHeader(currentSort: $currentSort, columnWidths: HoldingsTableRow.columnWidths, sortedHoldings: sortedHoldings, accountPositions: accountPositions, tradeDateCache: tradeDateCache, orderStatusCache: orderStatusCache)
            Divider()
            HoldingsTableContent(
                sortedHoldings: sortedHoldings,
                selectedPositionId: $selectedPositionId,
                accountPositions: accountPositions,
                viewSize: viewSize,
                tradeDateCache: tradeDateCache,
                orderStatusCache: orderStatusCache,
                copyToClipboard: copyToClipboard,
                copyToClipboardValue: copyToClipboard
            )
            if copiedValue != "TBD" {
                Text("Copied: \(copiedValue)")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
        }
    }
}

// Preview

#Preview("HoldingsTable", traits: .landscapeLeft) {
    let samplePosition1 = Position(
        shortQuantity: 0.0,
        averagePrice: 50.0,
        longQuantity: 100.0,
        instrument: Instrument(
            assetType: .EQUITY,
            symbol: "AAPL",
            description: "Apple Inc."
        ),
        marketValue: 5500.0,
        longOpenProfitLoss: 500.0
    )
    
    let samplePosition2 = Position(
        shortQuantity: 0.0,
        averagePrice: 25.0,
        longQuantity: 50.0,
        instrument: Instrument(
            assetType: .OPTION,
            symbol: "AAPL240119C00150000",
            description: "AAPL Jan 19 2024 150 Call"
        ),
        marketValue: 1250.0,
        longOpenProfitLoss: -250.0
    )
    
    let samplePositions = [samplePosition1, samplePosition2]
    let accountPositions = [
        (samplePosition1, "456", "2024/01/15"),
        (samplePosition2, "012", "2024/01/16")
    ]
    
    HoldingsTable(
        sortedHoldings: samplePositions,
        selectedPositionId: .constant(nil),
        accountPositions: accountPositions,
        currentSort: .constant(SortConfig(column: .symbol, ascending: true)),
        viewSize: CGSize(width: 1030, height: 800),
        tradeDateCache: ["123456": "2024/01/15", "789012": "2024/01/16"],
        orderStatusCache: ["456": .working, "012": .accepted]
    )
}

