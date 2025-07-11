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
        
        // Add new special orders
        let specialOrders = calculateSpecialOrders()
        recommended.append(contentsOf: specialOrders)
        
        return recommended
    }
    
    private func calculateSpecialOrders() -> [SalesCalcResultsRecord] {
        var specialOrders: [SalesCalcResultsRecord] = []
        
        // Get current price from the first tax lot (they all have the same current price)
        guard let currentPrice = taxLotData.first?.price, currentPrice > 0 else {
            return specialOrders
        }
        
        // Sort tax lots by cost per share (highest first)
        let sortedTaxLots = taxLotData.sorted { $0.costPerShare > $1.costPerShare }
        
        // Order 0: Sell top 100 most expensive shares if profitable
        let top100Order = calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
        if let order = top100Order {
            specialOrders.append(order)
        }
        
        // Order 1: Minimum shares needed for 5% profit
        let minSharesOrder = calculateMinSharesFor5PercentProfit(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
        if let order = minSharesOrder {
            specialOrders.append(order)
        }
        
        return specialOrders
    }
    
    private func calculateTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        print("=== calculateTop100Order ===")
        print("Current price: $\(currentPrice)")
        
        // Check if we have at least 100 shares not under contract
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let sharesNotUnderContract = totalShares - (SchwabClient.shared.getContractCountForSymbol(symbol) * 100.0)
        
        print("Total shares: \(totalShares)")
        print("Shares under contract: \(SchwabClient.shared.getContractCountForSymbol(symbol) * 100.0)")
        print("Shares not under contract: \(sharesNotUnderContract)")
        
        guard sharesNotUnderContract >= 100.0 else {
            print("❌ Insufficient shares not under contract: \(sharesNotUnderContract) < 100")
            return nil
        }
        
        // Check if we have at least 100 shares held for more than 30 days
        let sharesOver30Days = sortedTaxLots
            .filter { (daysSinceDateString(dateString: $0.openDate) ?? 0) > 30 }
            .reduce(0.0) { $0 + $1.quantity }
        
        print("Shares held for more than 30 days: \(sharesOver30Days)")
        
        guard sharesOver30Days >= 100.0 else {
            print("❌ Insufficient shares held for more than 30 days: \(sharesOver30Days) < 100")
            return nil
        }
        
        // Calculate the cost per share of the 100 most expensive shares
        var sharesToConsider: Double = 0.0
        var totalCost: Double = 0.0
        var sharesUsed: Double = 0.0
        
        print("Calculating cost of 100 most expensive shares:")
        for taxLot in sortedTaxLots {
            let remainingSharesNeeded = 100.0 - sharesUsed
            let sharesFromThisLot = min(taxLot.quantity, remainingSharesNeeded)
            
            sharesToConsider += sharesFromThisLot
            totalCost += sharesFromThisLot * taxLot.costPerShare
            sharesUsed += sharesFromThisLot
            
            print("  Lot: \(sharesFromThisLot) shares @ $\(taxLot.costPerShare) = $\(sharesFromThisLot * taxLot.costPerShare)")
            
            if sharesUsed >= 100.0 {
                break
            }
        }
        
        guard sharesUsed >= 100.0 else {
            print("❌ Could not get 100 shares from available lots")
            return nil
        }
        
        let costPerShare = totalCost / sharesToConsider
        let targetSellPrice = costPerShare * 1.05 // 5% profit
        let gain = ((targetSellPrice - costPerShare) / costPerShare) * 100.0
        
        print("100 most expensive shares:")
        print("  Total cost: $\(totalCost)")
        print("  Cost per share: $\(costPerShare)")
        print("  Target sell price for 5% profit: $\(targetSellPrice)")
        print("  Expected gain: \(gain)%")
        
        // Only add if the current price is high enough to achieve 5% profit
        guard currentPrice >= targetSellPrice else {
            print("❌ Current price $\(currentPrice) too low for 5% profit target $\(targetSellPrice)")
            return nil
        }
        
        // Calculate entry and cancel prices using the same logic as other orders
        let hardExitPrice = costPerShare * 1.03
        let atrDollarAmount = currentPrice * (atrValue / 100.0)  // Convert ATR percentage to dollar amount
        let minEntryPrice = currentPrice - atrDollarAmount  // Entry price must be at least 1 ATR below current price
        let entryPrice = max((currentPrice + targetSellPrice) / 2.0, minEntryPrice)
        let trailingStopPercent = ((entryPrice - targetSellPrice) / entryPrice) * 100.0
        
        print("Order parameters:")
        print("  Entry price: $\(entryPrice)")
        print("  Cancel price: $\(hardExitPrice)")
        print("  Trailing stop: \(trailingStopPercent)%")
        
        // Skip if trailing stop is less than 1%
        guard trailingStopPercent >= 1.0 else {
            print("❌ Trailing stop too low: \(trailingStopPercent)%")
            return nil
        }
        
        print("✅ Top 100 shares order created successfully")
        
        return SalesCalcResultsRecord(
            shares: sharesToConsider,
            rollingGainLoss: (currentPrice - costPerShare) * sharesToConsider,
            breakEven: costPerShare,
            gain: gain,
            sharesToSell: sharesToConsider,
            trailingStop: trailingStopPercent,
            entry: entryPrice,
            cancel: hardExitPrice,
            description: String(format: "🔵 Sell %.0f shares (Top 100) - Target: %.2f, Cost: %.2f, Profit: %.1f%%", 
                              sharesToConsider, targetSellPrice, costPerShare, gain),
            openDate: "Special"
        )
    }
    
    private func calculateMinSharesFor5PercentProfit(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        print("=== calculateMinSharesFor5PercentProfit ===")
        print("Current price: $\(currentPrice)")
        print("Tax lots (sorted by cost per share, highest first):")
        for (index, lot) in sortedTaxLots.enumerated() {
            print("  Lot \(index): \(lot.quantity) shares @ $\(lot.costPerShare) = $\(lot.costBasis) total")
        }
        
        var totalLoss: Double = 0.0
        var totalGain: Double = 0.0
        var sharesUsed: Double = 0.0
        var totalCost: Double = 0.0
        
        // First pass: Calculate total loss from high-cost lots (lots with cost > current price)
        for lot in sortedTaxLots {
            if lot.costPerShare > currentPrice {
                let loss = (lot.costPerShare - currentPrice) * lot.quantity
                totalLoss += loss
                sharesUsed += lot.quantity
                totalCost += lot.costBasis
                print("  High-cost lot: \(lot.quantity) shares @ $\(lot.costPerShare) = $\(loss) loss")
            }
        }
        
        print("Total loss from high-cost lots: $\(totalLoss)")
        print("Shares used from high-cost lots: \(sharesUsed)")
        
        if totalLoss > 0 {
            print("Need to offset $\(totalLoss) in losses")
        } else {
            print("No losses to offset, starting with profitable lots")
        }
        
        // Second pass: Find minimum shares needed to achieve 5% profit
        // Continue through all tax lots to find the best combination
        for (lotIndex, lot) in sortedTaxLots.enumerated() {
            if lot.costPerShare <= currentPrice {
                // This is a profitable lot
                let gainPerShare = currentPrice - lot.costPerShare
                let totalGainFromThisLot = gainPerShare * lot.quantity
                
                print("  Profitable lot \(lotIndex): \(lot.quantity) shares @ $\(lot.costPerShare) = $\(totalGainFromThisLot) gain")
                
                // Calculate how much additional gain we need
                let targetGain = (totalCost + lot.costBasis) * 0.05  // 5% of total cost
                let additionalGainNeeded = targetGain - totalGain
                
                if additionalGainNeeded > 0 {
                    // Calculate how many shares we need from this lot
                    let sharesNeeded = additionalGainNeeded / gainPerShare
                    let sharesToUse = min(ceil(sharesNeeded), lot.quantity)  // Round up to whole shares
                    
                    print("    Need \(sharesNeeded) shares for 5% profit (additional gain needed: $\(additionalGainNeeded))")
                    print("    Using \(sharesToUse) shares from this lot (rounded up from \(sharesNeeded))")
                    
                    sharesUsed += sharesToUse
                    totalCost += sharesToUse * lot.costPerShare
                    totalGain += sharesToUse * gainPerShare
                    
                    let costPerShare = totalCost / sharesUsed
                    let gainPercent = (totalGain / totalCost) * 100.0
                    
                    print("    Running totals: \(sharesUsed) shares, $\(totalCost) cost, $\(totalGain) gain")
                    print("    Current cost per share: $\(costPerShare)")
                    print("    Current gain percent: \(gainPercent)%")
                    
                    if gainPercent >= 5.0 {
                        print("    ✅ Achieved 5% profit with \(sharesUsed) shares!")
                        
                        let targetSellPrice = costPerShare * 1.05
                        let hardExitPrice = costPerShare * 1.03
                        let atrDollarAmount = currentPrice * (atrValue / 100.0)  // Convert ATR percentage to dollar amount
                        let minEntryPrice = currentPrice - atrDollarAmount  // Entry price must be at least 1 ATR below current price
                        let entryPrice = min(currentPrice, minEntryPrice)  // Use current price as entry, but ensure it's at least 1 ATR below
                        let trailingStopPercent = ((entryPrice - targetSellPrice) / entryPrice) * 100.0
                        
                        // Check if trailing stop meets the 2 * ATR requirement
                        let isLastLot = lotIndex == sortedTaxLots.count - 1
                        let meetsATRRequirement = trailingStopPercent >= (2.0 * atrValue)
                        
                        if meetsATRRequirement {
                            let roundedShares = ceil(sharesUsed)  // Round up to whole shares
                            print("✅ Final result: \(roundedShares) shares needed for \(gainPercent)% profit")
                            print("   Target price: $\(targetSellPrice), Cost per share: $\(costPerShare)")
                            print("   Entry price: $\(entryPrice), Cancel price: $\(hardExitPrice)")
                            print("   Trailing stop: \(trailingStopPercent)% (meets 2 * ATR requirement)")
                            
                            return SalesCalcResultsRecord(
                                shares: roundedShares,
                                rollingGainLoss: totalGain,
                                breakEven: costPerShare,
                                gain: gainPercent,
                                sharesToSell: roundedShares,
                                trailingStop: trailingStopPercent,
                                entry: entryPrice,
                                cancel: hardExitPrice,
                                description: "🔵 Min shares for 5% profit: \(Int(roundedShares)) shares @ $\(String(format: "%.2f", costPerShare)) = \(String(format: "%.1f", gainPercent))% gain",
                                openDate: "2025-01-01"
                            )
                        } else if isLastLot {
                            // This is the last lot and it's profitable but doesn't meet ATR requirement
                            let roundedShares = ceil(sharesUsed)  // Round up to whole shares
                            print("⚠️ Last lot reached - profitable but trailing stop too low: \(trailingStopPercent)% < \(2.0 * atrValue)% (2 * ATR)")
                            print("   Showing order in orange color")
                            
                            return SalesCalcResultsRecord(
                                shares: roundedShares,
                                rollingGainLoss: totalGain,
                                breakEven: costPerShare,
                                gain: gainPercent,
                                sharesToSell: roundedShares,
                                trailingStop: trailingStopPercent,
                                entry: entryPrice,
                                cancel: hardExitPrice,
                                description: "🟠 Min shares for 5% profit (low TS): \(Int(roundedShares)) shares @ $\(String(format: "%.2f", costPerShare)) = \(String(format: "%.1f", gainPercent))% gain",
                                openDate: "2025-01-01"
                            )
                        } else {
                            // Not the last lot, continue to next lot
                            print("    Trailing stop too low: \(trailingStopPercent)% < \(2.0 * atrValue)% (2 * ATR), continuing to next lot")
                        }
                    }
                } else {
                    // We already have enough gain, but let's add this lot to improve the average
                    print("    Already have sufficient gain, adding this lot to improve average")
                    sharesUsed += lot.quantity
                    totalCost += lot.costBasis
                    totalGain += totalGainFromThisLot
                    
                    let costPerShare = totalCost / sharesUsed
                    let gainPercent = (totalGain / totalCost) * 100.0
                    
                    print("    Running totals: \(sharesUsed) shares, $\(totalCost) cost, $\(totalGain) gain")
                    print("    Current cost per share: $\(costPerShare)")
                    print("    Current gain percent: \(gainPercent)%")
                    
                    if gainPercent >= 5.0 {
                        print("    ✅ Achieved 5% profit with \(sharesUsed) shares!")
                        
                        let targetSellPrice = costPerShare * 1.05
                        let hardExitPrice = costPerShare * 1.03
                        let atrDollarAmount = currentPrice * (atrValue / 100.0)  // Convert ATR percentage to dollar amount
                        let minEntryPrice = currentPrice - atrDollarAmount  // Entry price must be at least 1 ATR below current price
                        let entryPrice = min(currentPrice, minEntryPrice)  // Use current price as entry, but ensure it's at least 1 ATR below
                        let trailingStopPercent = ((entryPrice - targetSellPrice) / entryPrice) * 100.0
                        
                        // Check if trailing stop meets the 2 * ATR requirement
                        let isLastLot = lotIndex == sortedTaxLots.count - 1
                        let meetsATRRequirement = trailingStopPercent >= (2.0 * atrValue)
                        
                        if meetsATRRequirement {
                            let roundedShares = ceil(sharesUsed)  // Round up to whole shares
                            print("✅ Final result: \(roundedShares) shares needed for \(gainPercent)% profit")
                            print("   Target price: $\(targetSellPrice), Cost per share: $\(costPerShare)")
                            print("   Entry price: $\(entryPrice), Cancel price: $\(hardExitPrice)")
                            print("   Trailing stop: \(trailingStopPercent)% (meets 2 * ATR requirement)")
                            
                            return SalesCalcResultsRecord(
                                shares: roundedShares,
                                rollingGainLoss: totalGain,
                                breakEven: costPerShare,
                                gain: gainPercent,
                                sharesToSell: roundedShares,
                                trailingStop: trailingStopPercent,
                                entry: entryPrice,
                                cancel: hardExitPrice,
                                description: "🔵 Min shares for 5% profit: \(Int(roundedShares)) shares @ $\(String(format: "%.2f", costPerShare)) = \(String(format: "%.1f", gainPercent))% gain",
                                openDate: "2025-01-01"
                            )
                        } else if isLastLot {
                            // This is the last lot and it's profitable but doesn't meet ATR requirement
                            print("⚠️ Last lot reached - profitable but trailing stop too low: \(trailingStopPercent)% < \(2.0 * atrValue)% (2 * ATR)")
                            print("   Showing order in orange color")
                            
                            return SalesCalcResultsRecord(
                                shares: sharesUsed,
                                rollingGainLoss: totalGain,
                                breakEven: costPerShare,
                                gain: gainPercent,
                                sharesToSell: sharesUsed,
                                trailingStop: trailingStopPercent,
                                entry: entryPrice,
                                cancel: hardExitPrice,
                                description: "🟠 Min shares for 5% profit (low TS): \(sharesUsed) shares @ $\(String(format: "%.2f", costPerShare)) = \(String(format: "%.1f", gainPercent))% gain",
                                openDate: "2025-01-01"
                            )
                        } else {
                            // Not the last lot, continue to next lot
                            print("    Trailing stop too low: \(trailingStopPercent)% < \(2.0 * atrValue)% (2 * ATR), continuing to next lot")
                        }
                    }
                }
            }
        }
        
        print("❌ Could not achieve 5% profit with available shares")
        return nil
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
        // Special handling for blue orders (top 100 shares)
        if result.description.contains("🔵") {
            return .blue
        }
        
        // Special handling for orange orders (profitable but low trailing stop)
        if result.description.contains("🟠") {
            return .orange
        }
        
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
