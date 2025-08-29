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

    private func accountNumberFor(_ position: Position) -> String {
        accountPositions.first { $0.0.id == position.id }?.1 ?? ""
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
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
                        copyToClipboardValue: copyToClipboardValue
                    ) // table row
                } // for
            }  // vstack
            .padding(.trailing, 15)
            .padding(.bottom, 15)
        } // scroll
    } // view
}

#Preview("Holdings", traits: .landscapeLeft) {
    let samplePositions : [Position] = [
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
        HoldingsTableContent(
            sortedHoldings: samplePositions,
            selectedPositionId: .constant(nil),
            accountPositions: [],
            viewSize: CGSize(width: 800, height: 600),
            tradeDateCache: ["AAPL": "20241201"],
            orderStatusCache: ["AAPL": .working],
            copyToClipboard: { _ in },
            copyToClipboardValue: { _, _ in },
        )
    }
    .padding(.horizontal, 5)
    .padding(.trailing, 5)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}
