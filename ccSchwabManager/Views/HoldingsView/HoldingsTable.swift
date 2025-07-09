import SwiftUI

struct HoldingsTable: View {
    let sortedHoldings: [Position]
    @Binding var selectedPositionId: Position.ID?
    let accountPositions: [(Position, String, String)]
    @Binding var currentSort: SortConfig?
    let viewSize: CGSize
    let tradeDateCache: [String: String]
    let orderStatusCache: [String: ActiveOrderStatus?]
//    let dteCache: [String: Int?]

    private let columnWidths: [CGFloat] = [0.17, 0.07, 0.07, 0.09, 0.07, 0.07, 0.09, 0.05, 0.08, 0.05, 0.05]

    var body: some View {
        VStack(spacing: 0) {
            TableHeader(currentSort: $currentSort, viewSize: viewSize, columnWidths: columnWidths)
            Divider()
            TableContent(
                sortedHoldings: sortedHoldings,
                selectedPositionId: $selectedPositionId,
                accountPositions: accountPositions,
                viewSize: viewSize,
                columnWidths: columnWidths,
                tradeDateCache: tradeDateCache,
                orderStatusCache: orderStatusCache,
//                dteCache: dteCache
            )
        }
    }
}

private struct TableHeader: View {
    @Binding var currentSort: SortConfig?
    let viewSize: CGSize
    let columnWidths: [CGFloat]

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
        HStack(spacing: 8) {
            columnHeader(title: "Symbol", column: .symbol).frame(width: columnWidths[0] * viewSize.width)
            columnHeader(title: "Qty", column: .quantity, alignment: .trailing).frame(width: columnWidths[1] * viewSize.width)
            columnHeader(title: "Avg", column: .avgPrice, alignment: .trailing).frame(width: columnWidths[2] * viewSize.width)
            columnHeader(title: "Market", column: .marketValue, alignment: .trailing).frame(width: columnWidths[3] * viewSize.width)
            columnHeader(title: "P/L", column: .pl, alignment: .trailing).frame(width: columnWidths[4] * viewSize.width)
            columnHeader(title: "P/L%", column: .plPercent, alignment: .trailing).frame(width: columnWidths[5] * viewSize.width)
            columnHeader(title: "Type", column: .assetType).frame(width: columnWidths[6] * viewSize.width)
            columnHeader(title: "Acnt", column: .account).frame(width: columnWidths[7] * viewSize.width)
            columnHeader(title: "Last Trade", column: .lastTradeDate).frame(width: columnWidths[8] * viewSize.width)
            columnHeader(title: "Order", column: .orderStatus ).frame(width: columnWidths[9] * viewSize.width)
            columnHeader(title: "DTE/#", column: .dte, alignment: .trailing).frame(width: columnWidths[10] * viewSize.width)
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
    }
}

private struct TableContent: View {
    let sortedHoldings: [Position]
    @Binding var selectedPositionId: Position.ID?
    let accountPositions: [(Position, String, String)]
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    let tradeDateCache: [String: String]
    let orderStatusCache: [String: ActiveOrderStatus?]
//    let dteCache: [String: Int?]

    private func accountNumberFor(_ position: Position) -> String {
        accountPositions.first { $0.0.id == position.id }?.1 ?? ""
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedHoldings) { position in
                    let dte : Int? =  ( position.instrument?.assetType == .OPTION) ?  extractExpirationDate( from: position.instrument?.symbol ?? "", description: position.instrument?.description ?? "" )   : SchwabClient.shared.getMinimumDTEForSymbol(position.instrument?.symbol ?? "")
                    let count : Double = SchwabClient.shared.getContractCountForSymbol(position.instrument?.symbol ?? "")
                    TableRow(
                        position: position,
                        accountNumber: accountNumberFor(position),
                        viewSize: viewSize,
                        columnWidths: columnWidths,
                        onTap: { selectedPositionId = position.id },
                        tradeDate: tradeDateCache[position.instrument?.symbol ?? ""] ?? "0000",
                        orderStatus: orderStatusCache[position.instrument?.symbol ?? ""] ?? nil,
                        dte: (nil == dte) ? "" : String( format: "%d / %.0f", dte ?? 0, count )
                    )
                    Divider()
                }
            }
        }
    }
}

private struct TableRow: View {
    let position: Position
    let accountNumber: String
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    let onTap: () -> Void
    let tradeDate: String
    let orderStatus: ActiveOrderStatus?
    let dte: String
    
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
    
    var body: some View {
        HStack(spacing: 8) {
            Text(position.instrument?.symbol ?? "").frame(width: columnWidths[0] * viewSize.width, alignment: .leading)
            Text(String(format: "%.2f", ((position.longQuantity ?? 0.0) + (position.shortQuantity ?? 0.0)))).frame(width: columnWidths[1] * viewSize.width, alignment: .trailing)
            Text(String(format: "%.2f", position.averagePrice ?? 0.0)).frame(width: columnWidths[2] * viewSize.width, alignment: .trailing).monospacedDigit()
            Text(String(format: "%.2f", position.marketValue ?? 0.0)).frame(width: columnWidths[3] * viewSize.width, alignment: .trailing).monospacedDigit()
            Text(String(format: "%.2f", position.longOpenProfitLoss ?? 0.0))
                .frame(width: columnWidths[4] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundColor(plColor)
            Text(String(format: "%.1f%%", plPercent))
                .frame(width: columnWidths[5] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundColor(plColor)
            Text(position.instrument?.assetType?.rawValue ?? "").frame(width: columnWidths[6] * viewSize.width, alignment: .leading)
            Text(accountNumber).frame(width: columnWidths[7] * viewSize.width, alignment: .leading)
            Text(tradeDate).frame(width: columnWidths[8] * viewSize.width, alignment: .leading)
            Text(orderStatusText)
                .frame(width: columnWidths[9] * viewSize.width, alignment: .trailing)
                .foregroundColor(orderStatusColor)
                .font(.system(.body, design: .monospaced))
            Text(dte).frame(width: columnWidths[10] * viewSize.width, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    

}
