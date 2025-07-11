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
    let sharesAvailableForTrading: Double

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
                    copiedValue: $copiedValue,
                    atrValue: atrValue,
                    sharesAvailableForTrading: sharesAvailableForTrading
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { oldValue, newValue in
                viewSize = newValue
            }
        }
    }
    
    private func getResults( taxLots: [SalesCalcPositionsRecord]) -> [SalesCalcResultsRecord] {
        var results: [SalesCalcResultsRecord] = []
        var rollingGain: Double = 0.0
        var totalShares: Double = 0.0
        var totalCost: Double = 0.0
        
        // Sort tax lots by cost per share (highest first)
        let sortedTaxLots = taxLots.sorted(by: { $0.costBasis / $0.quantity > $1.costBasis / $1.quantity })
        
        // Process each tax lot, checking if we need to split at the break-even point
        for (index, taxLot) in sortedTaxLots.enumerated() {
            let potentialTotalShares = totalShares + taxLot.quantity
            let potentialTotalCost = totalCost + taxLot.costBasis
            let potentialCostPerShare = potentialTotalCost / potentialTotalShares
            
            // Target price for 5% profit
            let targetPrice = potentialCostPerShare * 1.05
            
            // Check if current price meets the 5% profit target
            if taxLot.price >= targetPrice {
                // Add full tax lot
                totalShares = potentialTotalShares
                totalCost = potentialTotalCost
                rollingGain += taxLot.gainLossDollar
                
                // Calculate sale parameters with the full lot
                let costPerShare = totalCost / totalShares
                let hardExitPrice = costPerShare * 1.03
                let targetSellPrice = hardExitPrice + (costPerShare * (0.02 + (atrValue/200)))
                
                if taxLot.price >= targetSellPrice {
                    let entryPrice = (taxLot.price + targetSellPrice) / 2.0
                    let trailingStopPercent = ((entryPrice - targetSellPrice) / entryPrice) * 100.0
                    let gain = ((targetSellPrice - costPerShare) / costPerShare) * 100.0
                    
                    if trailingStopPercent >= 1.0 {
                        let result = SalesCalcResultsRecord(
                            shares: totalShares,
                            rollingGainLoss: rollingGain,
                            breakEven: costPerShare,
                            gain: gain,
                            sharesToSell: totalShares,
                            trailingStop: trailingStopPercent,
                            entry: entryPrice,
                            cancel: hardExitPrice,
                            description: String(format: "Sell %.0f shares TS=%.1f, Entry Ask < %.2f, Cancel Ask < %.2f", totalShares, trailingStopPercent, entryPrice, hardExitPrice),
                            openDate: taxLot.openDate
                        )
                        results.append(result)
                    }
                }
            } else {
                // This tax lot would bring us below the 5% profit target
                // Calculate how many shares we need from this lot to achieve exactly 5% profit
                let sharesNeededForBreakeven = calculateSharesForBreakeven(
                    existingShares: totalShares,
                    existingCost: totalCost,
                    newLotCostPerShare: taxLot.costPerShare,
                    targetProfitPercent: 0.05,
                    currentPrice: taxLot.price
                )
                
                if sharesNeededForBreakeven > 0 && sharesNeededForBreakeven <= taxLot.quantity {
                    // Split the tax lot
                    let splitShares = sharesNeededForBreakeven
                    let splitCost = splitShares * taxLot.costPerShare
                    let splitGainLoss = (taxLot.price - taxLot.costPerShare) * splitShares
                    
                    let finalTotalShares = totalShares + splitShares
                    let finalTotalCost = totalCost + splitCost
                    let finalRollingGain = rollingGain + splitGainLoss
                    
                    // Calculate sale parameters for the split
                    let costPerShare = finalTotalCost / finalTotalShares
                    let hardExitPrice = costPerShare * 1.03
                    let targetSellPrice = hardExitPrice + (costPerShare * (0.02 + (atrValue/200)))
                    
                    if taxLot.price >= targetSellPrice {
                        let entryPrice = (taxLot.price + targetSellPrice) / 2.0
                        let trailingStopPercent = ((entryPrice - targetSellPrice) / entryPrice) * 100.0
                        let gain = ((targetSellPrice - costPerShare) / costPerShare) * 100.0
                        
                        if trailingStopPercent >= 1.0 {
                            let result = SalesCalcResultsRecord(
                                shares: finalTotalShares,
                                rollingGainLoss: finalRollingGain,
                                breakEven: costPerShare,
                                gain: gain,
                                sharesToSell: finalTotalShares,
                                trailingStop: trailingStopPercent,
                                entry: entryPrice,
                                cancel: hardExitPrice,
                                description: String(format: "Sell %.0f shares (%.0f split from lot) TS=%.1f, Entry Ask < %.2f, Cancel Ask < %.2f", finalTotalShares, splitShares, trailingStopPercent, entryPrice, hardExitPrice),
                                openDate: taxLot.openDate
                            )
                            results.append(result)
                        }
                    }
                    
                    // Update running totals with the split portion
                    totalShares = finalTotalShares
                    totalCost = finalTotalCost
                    rollingGain = finalRollingGain
                }
                
                // Continue to next tax lot without adding this one fully
                continue
            }
        }
        
        return results
    }
    
    // Helper method to calculate shares needed for break-even
    private func calculateSharesForBreakeven(existingShares: Double, existingCost: Double, newLotCostPerShare: Double, targetProfitPercent: Double, currentPrice: Double) -> Double {
        // We want to find n such that:
        // (existingCost + n * newLotCostPerShare) / (existingShares + n) = currentPrice / (1 + targetProfitPercent)
        
        let targetCostPerShare = currentPrice / (1 + targetProfitPercent)
        
        // Solve: (existingCost + n * newLotCostPerShare) = targetCostPerShare * (existingShares + n)
        // existingCost + n * newLotCostPerShare = targetCostPerShare * existingShares + targetCostPerShare * n
        // existingCost - targetCostPerShare * existingShares = targetCostPerShare * n - n * newLotCostPerShare
        // existingCost - targetCostPerShare * existingShares = n * (targetCostPerShare - newLotCostPerShare)
        
        let numerator = existingCost - (targetCostPerShare * existingShares)
        let denominator = targetCostPerShare - newLotCostPerShare
        
        if abs(denominator) < 0.001 {
            return 0 // Avoid division by zero
        }
        
        let sharesNeeded = numerator / denominator
        return max(0, sharesNeeded) // Return 0 if negative
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
    let atrValue: Double
    let sharesAvailableForTrading: Double

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(resultsData) { item in
                    TableRow(
                        item: item,
                        viewSize: viewSize,
                        columnWidths: columnWidths,
                        copiedValue: $copiedValue,
                        atrValue: atrValue,
                        sharesAvailableForTrading: sharesAvailableForTrading
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
    let atrValue: Double
    let sharesAvailableForTrading: Double

    private func rowStyle() -> Color {
        // if the number of available shares is too low, show as orange
        if ( item.sharesToSell > sharesAvailableForTrading )
        {
            return .red
        }
        // if the trailing stop is too low (less than 1 atr), show as yellow
        else if item.trailingStop <= atrValue
        {
            return .yellow
        }
        else if item.trailingStop < 5.0 {
            return .white
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

