import SwiftUI

struct RecommendedSellOrdersSection: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
    @State private var selectedOrderIndex: Int? = nil
    @State private var recommendedSellOrders: [SalesCalcResultsRecord] = []
    @State private var lastSymbol: String = ""
    @State private var copiedValue: String = "TBD"
    
    private var currentRecommendedSellOrders: [SalesCalcResultsRecord] {
        // This computed property will recalculate whenever symbol, atrValue, taxLotData, or sharesAvailableForTrading changes
        let orders = calculateRecommendedSellOrders()
        // Schedule state update for next run loop to avoid "Modifying state during view update" error
        if symbol != lastSymbol {
            DispatchQueue.main.async {
                self.checkAndUpdateSymbol()
            }
        }
        return orders
    }
    
    private func calculateRecommendedSellOrders() -> [SalesCalcResultsRecord] {
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
    
    private func updateRecommendedOrders() {
        recommendedSellOrders = calculateRecommendedSellOrders()
    }
    
    private func checkAndUpdateSymbol() {
        if symbol != lastSymbol {
            print("Symbol changed from \(lastSymbol) to \(symbol)")
            selectedOrderIndex = nil
            lastSymbol = symbol
        }
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
    
    private func submitSelectedOrder() {
        guard let selectedIndex = selectedOrderIndex else {
            print("No order selected for submission")
            return
        }
        
        guard selectedIndex < currentRecommendedSellOrders.count else {
            print("Selected order index out of bounds")
            return
        }
        
        let selectedOrder = currentRecommendedSellOrders[selectedIndex]
        
        // TODO: Implement order submission logic
        print("Submitting sell order: \(selectedOrder.description)")
    }
    
        var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            
            if currentRecommendedSellOrders.isEmpty {
                emptyStateView
            } else {
                ordersContentView
            }
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            print("RecommendedSellOrdersSection appeared for symbol: \(symbol)")
            checkAndUpdateSymbol()
        }
    }
    
    private var headerView: some View {
        Text("Recommended Sell Orders")
            .font(.headline)
            .padding(.horizontal)
            .onAppear {
                print("RecommendedSellOrdersSection appeared, selectedOrderIndex: \(selectedOrderIndex?.description ?? "nil")")
                updateRecommendedOrders()
            }
    }
    
    private var emptyStateView: some View {
        Text("No recommended sell orders for \(symbol)")
            .foregroundColor(.secondary)
            .padding()
    }
    
    private var ordersContentView: some View {
        HStack(alignment: .top, spacing: 16) {
            ordersListView
            submitButtonView
        }
    }
    
    private var ordersListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRowView
            ordersScrollView
        }
        .frame(maxWidth: .infinity)
    }
    
    private var headerRowView: some View {
        HStack(spacing: 8) {
            Text("Select")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 50, alignment: .center)
            
            Text("Rolling Gain/Loss")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
            
            Text("Breakeven")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 70, alignment: .trailing)
            
            Text("Shares to Sell")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
            
            Text("Gain")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
            
            Text("TS")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 50, alignment: .trailing)
            
            Text("Entry")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
            
            Text("Cancel")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
            
            Text("Description")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 200, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
    
    private var ordersScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(currentRecommendedSellOrders.enumerated()), id: \.element.id) { index, order in
                    let isSelected = selectedOrderIndex == index
                    RecommendedSellOrderRow(
                        order: order, 
                        color: getOrderColor(for: order),
                        isSelected: isSelected,
                        onSelectionChanged: { selectedIndex in
                            print("Selection changed to index: \(selectedIndex?.description ?? "nil")")
                            selectedOrderIndex = selectedIndex
                        },
                        orderIndex: index,
                        copiedValue: $copiedValue
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var submitButtonView: some View {
        if selectedOrderIndex != nil {
            VStack {
                Button(action: submitSelectedOrder) {
                    VStack {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.title2)
                        Text("Submit\nOrder")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                Spacer()
            }
            .padding(.trailing, 8)
        }
    }
}

struct RecommendedSellOrderRow: View {
    let order: SalesCalcResultsRecord
    let color: Color
    let isSelected: Bool
    let onSelectionChanged: (Int?) -> Void
    let orderIndex: Int
    @Binding var copiedValue: String
    
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
            // Radio button
            Button(action: {
                print("Radio button tapped for order index: \(orderIndex), currently selected: \(isSelected)")
                onSelectionChanged(isSelected ? nil : orderIndex)
            }) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 50, alignment: .center)
            
            Text(String(format: "%.2f", order.rollingGainLoss))
                .font(.system(.body, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: order.rollingGainLoss, format: "%.2f") }
                .foregroundColor(color)
            
            Text(String(format: "%.2f", order.breakEven))
                .font(.system(.body, design: .monospaced))
                .frame(width: 70, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: order.breakEven, format: "%.2f") }
                .foregroundColor(color)
            
            Text(String(format: "%.0f", order.sharesToSell))
                .font(.system(.body, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: order.sharesToSell, format: "%.0f") }
                .foregroundColor(color)
            
            Text(String(format: "%.2f%%", order.gain))
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: order.gain, format: "%.2f") }
                .foregroundColor(color)
            
            Text(String(format: "%.1f%%", order.trailingStop))
                .font(.system(.body, design: .monospaced))
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: order.trailingStop, format: "%.1f") }
                .foregroundColor(color)
            
            Text(String(format: "%.2f", order.entry))
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: order.entry, format: "%.2f") }
                .foregroundColor(color)
            
            Text(String(format: "%.2f", order.cancel))
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture { copyToClipboard(value: order.cancel, format: "%.2f") }
                .foregroundColor(color)
            
            Text(order.description)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 200, alignment: .leading)
                .onTapGesture { copyToClipboard(text: order.description) }
                .foregroundColor(color)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.03))
        .cornerRadius(4)
    }
} 
