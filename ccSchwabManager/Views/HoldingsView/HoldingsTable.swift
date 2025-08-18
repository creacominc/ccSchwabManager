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
    @State private var copiedValue: String = "TBD"

// private let columnWidths: [CGFloat] = [0.17, 0.07, 0.07, 0.09, 0.07, 0.07, 0.09, 0.05, 0.08, 0.05, 0.05]
    private let columnWidths: [CGFloat] = [ 0.09, 0.06, 0.06, 0.08, 0.06, 0.06, 0.08, 0.04, 0.06, 0.04, 0.04 ]

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
            TableHeader(currentSort: $currentSort, viewSize: viewSize, columnWidths: columnWidths, sortedHoldings: sortedHoldings, accountPositions: accountPositions, tradeDateCache: tradeDateCache, orderStatusCache: orderStatusCache)
            Divider()
            TableContent(
                sortedHoldings: sortedHoldings,
                selectedPositionId: $selectedPositionId,
                accountPositions: accountPositions,
                viewSize: viewSize,
                columnWidths: columnWidths,
                tradeDateCache: tradeDateCache,
                orderStatusCache: orderStatusCache,
                copyToClipboard: copyToClipboard,
                copyToClipboardValue: copyToClipboard
//                dteCache: dteCache
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

private struct TableHeader: View {
    @Binding var currentSort: SortConfig?
    let viewSize: CGSize
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
        HStack(spacing: 8) {
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
            .frame(width: columnWidths[0] * viewSize.width)
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
    let copyToClipboard: (String) -> Void
    let copyToClipboardValue: (Double, String) -> Void
//    let dteCache: [String: Int?]

    private func accountNumberFor(_ position: Position) -> String {
        accountPositions.first { $0.0.id == position.id }?.1 ?? ""
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(sortedHoldings.enumerated()), id: \.element.id) { index, position in
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
                        dte: (nil == dte) ? "" : String( format: "%d / %.0f", dte ?? 0, count ),
                        isEvenRow: index % 2 == 0,
                        isSelected: selectedPositionId == position.id,
                        copyToClipboard: copyToClipboard,
                        copyToClipboardValue: copyToClipboardValue
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
    let isEvenRow: Bool
    let isSelected: Bool
    let copyToClipboard: (String) -> Void
    let copyToClipboardValue: (Double, String) -> Void
    
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
    
    var body: some View {
        HStack(spacing: 8) {
            Text(position.instrument?.symbol ?? "")
                .frame(width: columnWidths[0] * viewSize.width, alignment: .leading)
                .onTapGesture {
                    copyToClipboard(position.instrument?.symbol ?? "")
                }
            
            Text(String(format: "%.2f", ((position.longQuantity ?? 0.0) + (position.shortQuantity ?? 0.0))))
                .frame(width: columnWidths[1] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    copyToClipboardValue((position.longQuantity ?? 0.0) + (position.shortQuantity ?? 0.0), "%.2f")
                }
            
            Text(String(format: "%.2f", position.averagePrice ?? 0.0))
                .frame(width: columnWidths[2] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    copyToClipboardValue(position.averagePrice ?? 0.0, "%.2f")
                }
            
            Text(String(format: "%.2f", position.marketValue ?? 0.0))
                .frame(width: columnWidths[3] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    copyToClipboardValue(position.marketValue ?? 0.0, "%.2f")
                }
            
            Text(String(format: "%.2f", position.longOpenProfitLoss ?? 0.0))
                .frame(width: columnWidths[4] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundColor(plColor)
                .onTapGesture {
                    copyToClipboardValue(position.longOpenProfitLoss ?? 0.0, "%.2f")
                }
            
            Text(String(format: "%.1f%%", plPercent))
                .frame(width: columnWidths[5] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundColor(plColor)
                .onTapGesture {
                    copyToClipboardValue(plPercent, "%.1f")
                }
            
            Text(position.instrument?.assetType?.rawValue ?? "")
                .frame(width: columnWidths[6] * viewSize.width, alignment: .leading)
                .onTapGesture {
                    copyToClipboard(position.instrument?.assetType?.rawValue ?? "")
                }
            
            Text(accountNumber)
                .frame(width: columnWidths[7] * viewSize.width, alignment: .leading)
                .onTapGesture {
                    copyToClipboard(accountNumber)
                }
            
            Text(tradeDate)
                .frame(width: columnWidths[8] * viewSize.width, alignment: .leading)
                .onTapGesture {
                    copyToClipboard(tradeDate)
                }
            
            Text(orderStatusText)
                .frame(width: columnWidths[9] * viewSize.width, alignment: .trailing)
                .foregroundColor(orderStatusColor)
                .font(.system(.body, design: .monospaced))
                .onTapGesture {
                    copyToClipboard(orderStatusText)
                }
            
            Text(dte)
                .frame(width: columnWidths[10] * viewSize.width, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(dte)
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(rowBackgroundColor)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
    }
    
    private var rowBackgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color.gray.opacity(0.1)
        } else if isEvenRow {
            return Color.clear
        } else {
            return Color.gray.opacity(0.08) // Slightly more visible for iOS
        }
    }
    

}


// Preview

#Preview("HoldingsTable", traits: .landscapeLeft) {
    let samplePosition1 = Position(
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
        viewSize: CGSize(width: 1200, height: 800),
        tradeDateCache: ["123456": "2024/01/15", "789012": "2024/01/16"],
        orderStatusCache: ["456": .working, "012": .accepted]
    )
}

