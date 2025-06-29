import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum SellListSortableColumn: String, CaseIterable, Identifiable {
    case rollingGainLoss = "Rolling Gain/Loss"
    case breakEven = "Breakeven"
    case sharesToSell = "Shares to Sell"
    case gain = "Gain"
    case trailingStop = "TS"
    case entry = "Entry"
    case cancel = "Cancel"
    case description = "Description"
    
    var id: String { self.rawValue }
}

struct SellListView: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let isLoadingTaxLots: Bool
    @State private var copiedValue: String = "TBD"
    @State private var viewSize: CGSize = .zero

    // Define proportional widths for columns
    private let columnWidths: [CGFloat] = [0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.28]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TableHeader(  // currentSort: $currentSort,
                              viewSize: geometry.size, columnWidths: columnWidths)
                Divider()
                TableContent(
                    // resultsData: sortedData,
                    resultsData: getResults(taxLots: taxLotData),
                    viewSize: geometry.size,
                    columnWidths: columnWidths,
                    copiedValue: $copiedValue
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newValue in
                viewSize = newValue
            }
        }
    }
    
    private func getResults( taxLots: [SalesCalcPositionsRecord]) -> [SalesCalcResultsRecord] {
        var results: [SalesCalcResultsRecord] = []
        var rollingGain: Double = 0.0
        var totalShares: Double = 0.0
        var totalCost: Double = 0.0

        /**
         *  The lots to sell :
         *
         */

        for taxLot in taxLots.sorted(by: { $0.costBasis / $0.quantity > $1.costBasis / $1.quantity }) {
//            print( " === processing tax lot: \(taxLot.openDate), \(taxLot.quantity), \(taxLot.costBasis), \(taxLot.price), \(taxLot.gainLossDollar)" )
            totalShares += taxLot.quantity
            totalCost += taxLot.costBasis
            rollingGain += taxLot.gainLossDollar
            // pricer per share at which we would break even
            let costPerShare: Double = totalCost / totalShares
            // the sale exit (lowest we want to sell at) at 1 ATR + 3.5% above the costPerShare
            let exitPrice: Double = costPerShare * ( 1.035 + (atrValue / 100.00) )
            // skip this for tax lots that are not at least 1 ATR profitable
            if( taxLot.price < exitPrice ) {
                continue
            }
            // the target sell price would be 1.5% above the exitPrice
            let targetSellPrice: Double = exitPrice * 1.015
            // sell entry is half way between the target price and the exit price
            let entryPrice = (taxLot.price + targetSellPrice) / 2.0
            // trailing stop % is the amount between the entry and target over the entry price
            let trailingStopPercent: Double = ((entryPrice - targetSellPrice) / entryPrice) * 100.0
            // percent gain at target sell price compared to cost
            let gain: Double = ((targetSellPrice - costPerShare) / costPerShare)
            //
//            print( "                  totalShares = \(totalShares), rollingGain = \(rollingGain), costPerShare = \(costPerShare), gain = \(gain), trailingStopPercent = \(trailingStopPercent), entryPrice = \(entryPrice), exitPrice = \(exitPrice),  ATR = \(atrValue)")

            let result: SalesCalcResultsRecord = SalesCalcResultsRecord(
                shares: totalShares,
                rollingGainLoss: rollingGain,
                breakEven: costPerShare,
                gain: gain,
                sharesToSell: totalShares,
                trailingStop: trailingStopPercent,
                entry: entryPrice,
                cancel: exitPrice,
                description: String(format: "Sell %.0f shares TS=%.1f, Entry Ask < %.2f, Cancel Ask < %.2f"
                                    , totalShares, trailingStopPercent, entryPrice, exitPrice),
                openDate: taxLot.openDate
            )
            results.append(result)
        }
        return results
    }
}

private struct TableHeader: View {
    //@Binding var currentSort: SellListSortConfig?
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    
    @ViewBuilder
    private func columnHeader(title: String
                              //, column: SellListSortableColumn
                              , alignment: Alignment = .leading
    ) -> some View {
        Text(title)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            columnHeader(title: "Rolling Gain/Loss"
                         //, column: .rollingGainLoss
                         , alignment: .trailing)
                .frame(width: columnWidths[0] * viewSize.width)
            columnHeader(title: "Breakeven"
                         //, column: .breakEven
                         , alignment: .trailing)
                .frame(width: columnWidths[1] * viewSize.width)
            columnHeader(title: "Shares to Sell"
                         //, column: .sharesToSell
                         , alignment: .trailing)
                .frame(width: columnWidths[2] * viewSize.width)
            columnHeader(title: "Gain"
                         //, column: .gain
                         , alignment: .trailing)
                .frame(width: columnWidths[3] * viewSize.width)
            columnHeader(title: "TS"
                         //, column: .trailingStop
                         , alignment: .trailing)
                .frame(width: columnWidths[4] * viewSize.width)
            columnHeader(title: "Entry"
                         //, column: .entry
                         , alignment: .trailing)
                .frame(width: columnWidths[5] * viewSize.width)
            columnHeader(title: "Cancel"
                         //, column: .cancel
                         , alignment: .trailing)
                .frame(width: columnWidths[6] * viewSize.width)
            columnHeader(title: "Description"
                         //, column: .description
            )
                .frame(width: columnWidths[7] * viewSize.width)
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
    }
}

private struct TableContent: View {
    let resultsData: [SalesCalcResultsRecord]
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    @Binding var copiedValue: String
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(resultsData) { item in
                    TableRow(
                        item: item,
                        viewSize: viewSize,
                        columnWidths: columnWidths,
                        copiedValue: $copiedValue
                    )
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TableRow: View {
    let item: SalesCalcResultsRecord
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    @Binding var copiedValue: String
    
    private func rowStyle() -> Color {
        if item.trailingStop <= 2.0 || (daysBetweenDates(dateString: item.openDate) ?? 0 < 31) {
            return .red
        } else if item.trailingStop < 5.0 {
            return .yellow
        }
        return .green
    }
    
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
        HStack(spacing: 8) {
            Text(String(format: "%.2f", item.rollingGainLoss))
                .frame(width: columnWidths[0] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: item.rollingGainLoss, format: "%.2f") }
            
            Text(String(format: "%.2f", item.breakEven))
                .frame(width: columnWidths[1] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: item.breakEven, format: "%.2f") }
            
            Text(String(format: "%.0f", item.sharesToSell))
                .frame(width: columnWidths[2] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: item.sharesToSell, format: "%.0f") }
                .foregroundStyle(rowStyle())
            
            Text(String(format: "%.2f%%", item.gain))
                .frame(width: columnWidths[3] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: item.gain, format: "%.2f") }
            
            Text(String(format: "%.1f%%", item.trailingStop))
                .frame(width: columnWidths[4] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: item.trailingStop, format: "%.1f") }
                .foregroundStyle(rowStyle())
            
            Text(String(format: "%.2f", item.entry))
                .frame(width: columnWidths[5] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: item.entry, format: "%.2f") }
                .foregroundStyle(rowStyle())
            
            Text(String(format: "%.2f", item.cancel))
                .frame(width: columnWidths[6] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: item.cancel, format: "%.2f") }
                .foregroundStyle(rowStyle())
            
            Text(item.description)
                .frame(width: columnWidths[7] * viewSize.width, alignment: .leading)
                .onTapGesture { copyToClipboard(text: item.description) }
                .foregroundStyle(rowStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.05))
    }
}

