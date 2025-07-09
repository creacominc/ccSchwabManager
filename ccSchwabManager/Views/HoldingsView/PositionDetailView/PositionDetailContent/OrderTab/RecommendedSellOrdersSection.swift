import SwiftUI

struct RecommendedSellOrdersSection: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
    
    private var recommendedSellOrders: [SalesCalcResultsRecord] {
        let results = getResults(taxLots: taxLotData)
        
        // Find the first green (trailing stop >= 5.0), first white (trailing stop < 5.0 but > atrValue), and last yellow (trailing stop <= atrValue)
        var greenOrders: [SalesCalcResultsRecord] = []
        var whiteOrders: [SalesCalcResultsRecord] = []
        var yellowOrders: [SalesCalcResultsRecord] = []
        
        for result in results {
            if result.sharesToSell > sharesAvailableForTrading {
                // Red orders (insufficient shares) - skip
                continue
            } else if result.trailingStop >= 5.0 {
                greenOrders.append(result)
            } else if result.trailingStop > atrValue {
                whiteOrders.append(result)
            } else {
                yellowOrders.append(result)
            }
        }
        
        var recommended: [SalesCalcResultsRecord] = []
        
        // Add first green order
        if let firstGreen = greenOrders.first {
            recommended.append(firstGreen)
        }
        
        // Add first white order
        if let firstWhite = whiteOrders.first {
            recommended.append(firstWhite)
        }
        
        // Add last yellow order
        if let lastYellow = yellowOrders.last {
            recommended.append(lastYellow)
        }
        
        return recommended
    }
    
    private func getResults(taxLots: [SalesCalcPositionsRecord]) -> [SalesCalcResultsRecord] {
        var results: [SalesCalcResultsRecord] = []
        var rollingGain: Double = 0.0
        var totalShares: Double = 0.0
        var totalCost: Double = 0.0

        for taxLot in taxLots.sorted(by: { $0.costBasis / $0.quantity > $1.costBasis / $1.quantity }) {
            totalShares += taxLot.quantity
            totalCost += taxLot.costBasis
            rollingGain += taxLot.gainLossDollar
            // price per share at which we would break even
            let costPerShare: Double = totalCost / totalShares
            // the sale exit (cancel sale) at 3% above the costPerShare
            let hardExitPrice: Double = costPerShare * ( 1.03 )
            // set the target sell price to be 2% of the cost above the exit.
            let targetSellPrice: Double = hardExitPrice + (costPerShare * (0.02 + (atrValue/200)) )

            // if the current price (taxLot.price) is less than 1 ATR above the exit, skip this
            if( taxLot.price < targetSellPrice ) {
                continue
            }

            // sell entry is half way between the target price and the current price
            let entryPrice = (taxLot.price + targetSellPrice) / 2.0
            // trailing stop % is the amount between the entry and target over the entry price
            let trailingStopPercent: Double = ((entryPrice - targetSellPrice) / entryPrice) * 100.0
            // percent gain at target sell price compared to cost
            let gain: Double = ((targetSellPrice - costPerShare) / costPerShare)*100.0

            // skip if the trailing stop is less than 1%
            if( trailingStopPercent < 1.0 ) {
                continue
            }

            let result: SalesCalcResultsRecord = SalesCalcResultsRecord(
                shares: totalShares,
                rollingGainLoss: rollingGain,
                breakEven: costPerShare,
                gain: gain,
                sharesToSell: totalShares,
                trailingStop: trailingStopPercent,
                entry: entryPrice,
                cancel: hardExitPrice,
                description: String(format: "Sell %.0f shares TS=%.1f, Entry Ask < %.2f, Cancel Ask < %.2f"
                                    , totalShares, trailingStopPercent, entryPrice, hardExitPrice),
                openDate: taxLot.openDate
            )
            results.append(result)
        }
        return results
    }
    
    private func getOrderColor(for result: SalesCalcResultsRecord) -> Color {
        if result.sharesToSell > sharesAvailableForTrading {
            return .red
        } else if result.trailingStop <= atrValue {
            return .yellow
        } else if result.trailingStop < 5.0 {
            return .white
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended Sell Orders")
                .font(.headline)
                .padding(.horizontal)
            
            if recommendedSellOrders.isEmpty {
                Text("No recommended sell orders for \(symbol)")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Header row
                HStack {
                    Text("Type")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 60, alignment: .leading)
                    
                    Text("Shares")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 60, alignment: .trailing)
                    
                    Text("Entry")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 70, alignment: .trailing)
                    
                    Text("TS%")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 70, alignment: .trailing)
                    
                    Text("Value")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 80, alignment: .trailing)
                    
                    Text("Date")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 120, alignment: .leading)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(recommendedSellOrders) { order in
                            RecommendedSellOrderRow(order: order, color: getOrderColor(for: order))
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct RecommendedSellOrderRow: View {
    let order: SalesCalcResultsRecord
    let color: Color
    
    var body: some View {
        HStack {
            Text("SELL")
                .foregroundColor(.red)
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .leading)
            
            Text(String(format: "%.0f", order.sharesToSell))
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
                .foregroundColor(color)
            
            Text(String(format: "%.2f", order.entry))
                .font(.system(.body, design: .monospaced))
                .frame(width: 70, alignment: .trailing)
                .foregroundColor(color)
            
            Text(String(format: "%.1f%%", order.trailingStop))
                .font(.system(.body, design: .monospaced))
                .frame(width: 70, alignment: .trailing)
                .foregroundColor(color)
            
            Text(String(format: "%.2f", order.entry * order.sharesToSell))
                .font(.system(.body, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(color)
            
            Text(order.openDate)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 120, alignment: .leading)
                .foregroundColor(color)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.03))
        .cornerRadius(4)
    }
} 