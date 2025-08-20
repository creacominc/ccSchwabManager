import SwiftUI

struct HoldingsTableContent: View {
    let sortedHoldings: [Position]
    @Binding var selectedPositionId: Position.ID?
    let accountPositions: [(Position, String, String)]
    let viewSize: CGSize
    let tradeDateCache: [String: String]
    let orderStatusCache: [String: ActiveOrderStatus?]
    let copyToClipboard: (String) -> Void
    let copyToClipboardValue: (Double, String) -> Void
    let availableWidth: CGFloat

    private func accountNumberFor(_ position: Position) -> String {
        accountPositions.first { $0.0.id == position.id }?.1 ?? ""
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(sortedHoldings.enumerated()), id: \.element.id) { index, position in
                    let isOption = position.instrument?.assetType == .OPTION
                    let dte: Int? = isOption ? 
                        extractExpirationDate(from: position.instrument?.symbol ?? "", description: position.instrument?.description ?? "") : 
                        SchwabClient.shared.getMinimumDTEForSymbol(position.instrument?.symbol ?? "")
                    let count: Double = SchwabClient.shared.getContractCountForSymbol(position.instrument?.symbol ?? "")
                    let dteString = (dte == nil) ? "" : String(format: "%d / %.0f", dte ?? 0, count)
                    let tradeDate = tradeDateCache[position.instrument?.symbol ?? ""] ?? "0000"
                    let orderStatus = orderStatusCache[position.instrument?.symbol ?? ""] ?? nil
                    let isEvenRow = index % 2 == 0
                    let isSelected = selectedPositionId == position.id
                    
                    HoldingsTableRow(
                        position: position,
                        accountNumber: accountNumberFor(position),
                        onTap: { selectedPositionId = position.id },
                        tradeDate: tradeDate,
                        orderStatus: orderStatus,
                        dte: dteString,
                        isEvenRow: isEvenRow,
                        isSelected: isSelected,
                        copyToClipboard: copyToClipboard,
                        copyToClipboardValue: copyToClipboardValue,
                        availableWidth: availableWidth
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
