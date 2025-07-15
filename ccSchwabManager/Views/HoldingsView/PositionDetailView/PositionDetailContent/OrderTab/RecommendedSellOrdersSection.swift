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
    @State private var isRadioButtonSelected: Bool = false
    
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
        print("=== calculateRecommendedSellOrders ===")
        print("Symbol: \(symbol)")
        print("ATR: \(atrValue)%")
        print("Tax lots count: \(taxLotData.count)")
        print("Shares available for trading: \(sharesAvailableForTrading)")
        
        var recommended: [SalesCalcResultsRecord] = []
        
        // Get current price from the first tax lot (they all have the same current price)
        guard let currentPrice = taxLotData.first?.price, currentPrice > 0 else {
            print("❌ No valid current price found")
            return recommended
        }
        
        print("Current price: $\(currentPrice)")
        
        // Sort tax lots by cost per share (highest first)
        let sortedTaxLots = taxLotData.sorted { $0.costPerShare > $1.costPerShare }
        print("Sorted tax lots by cost per share (highest first): \(sortedTaxLots.count) lots")
        
        // Order 0: Sell top 100 most expensive shares if profitable
        print("--- Calculating Top 100 Order ---")
        let top100Order = calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
        if let order = top100Order {
            print("✅ Top 100 order created: \(order.description)")
            recommended.append(order)
        } else {
            print("❌ Top 100 order not created")
        }
        
        // Order 1: Minimum shares needed for 5% profit
        print("--- Calculating Min Shares Order ---")
        let minSharesOrder = calculateMinSharesFor5PercentProfit(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
        if let order = minSharesOrder {
            print("✅ Min shares order created: \(order.description)")
            recommended.append(order)
        } else {
            print("❌ Min shares order not created")
        }

        // Order 2: Minimum break even order (>1% gain)
        print("--- Calculating Min Break Even Order ---")
        let minBreakEvenOrder = calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
        if let order = minBreakEvenOrder {
            print("✅ Min break even order created: \(order.description)")
            recommended.append(order)
        } else {
            print("❌ Min break even order not created")
        }
        
        print("=== Final result: \(recommended.count) recommended orders ===")
        return recommended
    }
    
    private func formatReleaseTime(_ date: Date) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 40
        components.second = 0
        
        let targetDate = calendar.date(from: components) ?? date
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy HH:mm:ss"
        return formatter.string(from: targetDate)
    }
    
    private func getLimitedATR() -> Double {
        // Clamp ATR to the range [1, 7] percent
        return max(1.0, min(atrValue, 7.0))
    }
    
    private func calculateTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        print("=== calculateTop100Order ===")
        print("Current price: $\(currentPrice)")
        print("ATR value: \(atrValue)%")
        print("Limited ATR value: \(getLimitedATR())%")
        print("Total tax lots: \(sortedTaxLots.count)")
        
        // Log all tax lots for debugging
        print("All tax lots:")
        for (index, lot) in sortedTaxLots.enumerated() {
            let daysHeld = daysSinceDateString(dateString: lot.openDate) ?? 0
            print("  Lot \(index): \(lot.quantity) shares @ $\(lot.costPerShare) = $\(lot.costBasis) total, held for \(daysHeld) days")
        }
        
        // Check if we have at least 100 shares not under contract
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let sharesUnderContract = SchwabClient.shared.getContractCountForSymbol(symbol) * 100.0
        let sharesNotUnderContract = totalShares - sharesUnderContract
        
        print("Total shares: \(totalShares)")
        print("Shares under contract: \(sharesUnderContract)")
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
        for (index, taxLot) in sortedTaxLots.enumerated() {
            let remainingSharesNeeded = 100.0 - sharesUsed
            let sharesFromThisLot = min(taxLot.quantity, remainingSharesNeeded)
            
            sharesToConsider += sharesFromThisLot
            totalCost += sharesFromThisLot * taxLot.costPerShare
            sharesUsed += sharesFromThisLot
            
            print("  Lot \(index): \(sharesFromThisLot) shares @ $\(taxLot.costPerShare) = $\(sharesFromThisLot * taxLot.costPerShare)")
            
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
        let atrDollarAmount = currentPrice * (getLimitedATR() / 100.0)  // Convert ATR percentage to dollar amount
        let minEntryPrice = currentPrice - atrDollarAmount  // Entry price must be at least 1 ATR below current price
        let entryPrice = max((currentPrice + targetSellPrice) / 2.0, minEntryPrice)
        let trailingStopPercent = ((entryPrice - targetSellPrice) / entryPrice) * 100.0
        
        print("Order parameters:")
        print("  Entry price: $\(entryPrice)")
        print("  Cancel price: $\(hardExitPrice)")
        print("  Trailing stop: \(trailingStopPercent)%")
        print("  ATR requirement: \(2.0 * getLimitedATR())%")
        
        // Skip if trailing stop is less than 2 * ATR
        guard trailingStopPercent >= (2.0 * getLimitedATR()) else {
            print("❌ Trailing stop too low: \(trailingStopPercent)% < \(2.0 * getLimitedATR())% (2 * ATR)")
            return nil
        }
        
        print("✅ Top 100 shares order created successfully")
        
        // Format the description to match the standard sell order format
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(100) SELL -%.0f %@ @LAST-%.2f%% TRSTPLMT ASK below %.2f cancel below %.2f GTC SUBMIT AT %@",
                                        sharesToConsider,
                                        symbol,
                                        trailingStopPercent,
                                        entryPrice,
                                        hardExitPrice,
                                        formatReleaseTime(tomorrow))
        
        return SalesCalcResultsRecord(
            shares: sharesToConsider,
            rollingGainLoss: (currentPrice - costPerShare) * sharesToConsider,
            breakEven: costPerShare,
            gain: gain,
            sharesToSell: sharesToConsider,
            trailingStop: trailingStopPercent,
            entry: entryPrice,
            cancel: hardExitPrice,
            description: formattedDescription,
            openDate: "Special"
        )
    }
    
    private func calculateMinSharesFor5PercentProfit(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        print("=== calculateMinSharesForATRLogic ===")
        print("Current price: $\(currentPrice)")
        print("ATR: \(atrValue)%")
        print("Tax lots (sorted by cost per share, highest first):")
        for (index, lot) in sortedTaxLots.enumerated() {
            print("  Lot \(index): \(lot.quantity) shares @ $\(lot.costPerShare) = $\(lot.costBasis) total")
        }

        // 1. Calculate entry, target, and exit prices using ATR, rounded down to the penny
        let limitedATR = getLimitedATR()
        let entryRaw = currentPrice / (1.0 + (2.0 * limitedATR / 100.0))
        let entry = floor(entryRaw * 100) / 100
        let targetRaw = entry / (1.0 + (limitedATR / 100.0))
        let target = floor(targetRaw * 100) / 100
        let exitRaw = target / (1.0 + (limitedATR / 100.0))
        let exit = floor(exitRaw * 100) / 100
        let costPerShareThresholdRaw = target / 1.05
        let costPerShareThreshold = floor(costPerShareThresholdRaw * 100) / 100
        print("Entry: $\(entry), Target: $\(target), Exit: $\(exit), Cost/share threshold: $\(costPerShareThreshold)")

        // 2. Find minimum shares such that cost-per-share <= costPerShareThreshold, allowing partial lots
        var sharesUsed: Double = 0.0
        var totalCost: Double = 0.0
        var lotsUsed: [(Double, Double)] = [] // (shares, costPerShare)
        var found = false

        for lot in sortedTaxLots {
            let sharesToUse = lot.quantity
            let newSharesUsed = sharesUsed + sharesToUse
            let newTotalCost = totalCost + sharesToUse * lot.costPerShare
            let avgCostPerShare = newTotalCost / newSharesUsed
            if avgCostPerShare <= costPerShareThreshold {
                // Only take the minimum number of shares from this lot to reach the threshold
                let numerator = costPerShareThreshold * sharesUsed - totalCost
                let denominator = lot.costPerShare - costPerShareThreshold
                var partialShares: Double = 0.0
                if denominator != 0 {
                    partialShares = numerator / denominator
                }
                // Clamp to [0, lot.quantity]
                partialShares = max(0.0, min(partialShares, lot.quantity))
                sharesUsed += partialShares
                totalCost += partialShares * lot.costPerShare
                lotsUsed.append((partialShares, lot.costPerShare))
                found = true
                break
            } else {
                sharesUsed = newSharesUsed
                totalCost = newTotalCost
                lotsUsed.append((sharesToUse, lot.costPerShare))
            }
        }

        if sharesUsed == 0 || !found {
            print("❌ Could not find enough shares to meet cost-per-share threshold with partial lots")
            return nil
        }

        // Round up shares to next whole number
        let roundedShares = ceil(sharesUsed)
        // Recalculate total cost for the rounded number of shares
        var runningShares: Double = 0.0
        var runningCost: Double = 0.0
        for (qty, cps) in lotsUsed {
            let sharesToAdd = min(qty, max(0, roundedShares - runningShares))
            runningCost += sharesToAdd * cps
            runningShares += sharesToAdd
            if runningShares >= roundedShares { break }
        }
        let avgCostPerShare = runningCost / roundedShares
        let gain = ((target - avgCostPerShare) / avgCostPerShare) * 100.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Min ATR) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", roundedShares, symbol, entry, target, exit, avgCostPerShare, formatReleaseTime(tomorrow))

        // Set trailing stop to ATR value (1 ATR)
        let trailingStopATR = limitedATR

        return SalesCalcResultsRecord(
            shares: roundedShares,
            rollingGainLoss: (target - avgCostPerShare) * roundedShares,
            breakEven: avgCostPerShare,
            gain: gain,
            sharesToSell: roundedShares,
            trailingStop: trailingStopATR, // Set to ATR value
            entry: entry,
            cancel: exit,
            description: formattedDescription,
            openDate: "ATR"
        )
    }
    
    private func calculateMinBreakEvenOrder(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        print("=== calculateMinBreakEvenOrder ===")
        print("Current price: $\(currentPrice)")
        print("Tax lots (sorted by cost per share, highest first):")
        for (index, lot) in sortedTaxLots.enumerated() {
            print("  Lot \(index): \(lot.quantity) shares @ $\(lot.costPerShare) = $\(lot.costBasis) total")
        }

        // 1. Find minimum shares such that cost-per-share is at least 1% below current price (>1% gain)
        let costPerShareThreshold = currentPrice / 1.01 // must be at least 1% gain
        var sharesUsed: Double = 0.0
        var totalCost: Double = 0.0
        var lotsUsed: [(Double, Double)] = [] // (shares, costPerShare)
        var found = false

        for lot in sortedTaxLots {
            let sharesToUse = lot.quantity
            let newSharesUsed = sharesUsed + sharesToUse
            let newTotalCost = totalCost + sharesToUse * lot.costPerShare
            let avgCostPerShare = newTotalCost / newSharesUsed
            if avgCostPerShare <= costPerShareThreshold {
                // Only take the minimum number of shares from this lot to reach the threshold
                let numerator = costPerShareThreshold * sharesUsed - totalCost
                let denominator = lot.costPerShare - costPerShareThreshold
                var partialShares: Double = 0.0
                if denominator != 0 {
                    partialShares = numerator / denominator
                }
                // Clamp to [0, lot.quantity]
                partialShares = max(0.0, min(partialShares, lot.quantity))
                sharesUsed += partialShares
                totalCost += partialShares * lot.costPerShare
                lotsUsed.append((partialShares, lot.costPerShare))
                found = true
                break
            } else {
                sharesUsed = newSharesUsed
                totalCost = newTotalCost
                lotsUsed.append((sharesToUse, lot.costPerShare))
            }
        }

        if sharesUsed == 0 || !found {
            print("❌ Could not find enough shares to meet break even threshold with partial lots")
            return nil
        }

        // Round up shares to next whole number
        let roundedShares = ceil(sharesUsed)
        // Recalculate total cost for the rounded number of shares
        var runningShares: Double = 0.0
        var runningCost: Double = 0.0
        for (qty, cps) in lotsUsed {
            let sharesToAdd = min(qty, max(0, roundedShares - runningShares))
            runningCost += sharesToAdd * cps
            runningShares += sharesToAdd
            if runningShares >= roundedShares { break }
        }
        let avgCostPerShare = runningCost / roundedShares
        let gain = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        if gain < 1.0 {
            print("❌ Gain is less than 1%: \(gain)%")
            return nil
        }
        // Exit: 0.25% above cost-per-share
        let exit = floor((avgCostPerShare * 1.0025) * 100) / 100
        // Entry: 0.5% below current price
        var entry = floor((currentPrice * 0.995) * 100) / 100
        // Target sell: midway between entry and exit
        var target = floor(((entry + exit) / 2.0) * 100) / 100
        // Trailing stop: percent from entry to target sell
        var trailingStop = ((target - entry) / entry) * 100.0
        
        // Ensure trailing stop is at least 0.25%
        if trailingStop < 0.25 {
            print("⚠️ Trailing stop \(trailingStop)% is less than 0.25%, adjusting prices...")
            // Calculate required target price to achieve 0.25% trailing stop
            let requiredTarget = entry * 1.0025
            target = floor(requiredTarget * 100) / 100
            trailingStop = 0.25
            print("  Adjusted target: $\(target), trailing stop: \(trailingStop)%")
        }
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Min BE) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", roundedShares, symbol, entry, target, exit, avgCostPerShare, formatReleaseTime(tomorrow))
        return SalesCalcResultsRecord(
            shares: roundedShares,
            rollingGainLoss: (target - avgCostPerShare) * roundedShares,
            breakEven: avgCostPerShare,
            gain: gain,
            sharesToSell: roundedShares,
            trailingStop: trailingStop,
            entry: entry,
            cancel: exit,
            description: formattedDescription,
            openDate: "MinBE"
        )
    }
    
    private func updateRecommendedOrders() {
        recommendedSellOrders = calculateRecommendedSellOrders()
    }
    
    private func checkAndUpdateSymbol() {
        if symbol != lastSymbol {
            print("Symbol changed from \(lastSymbol) to \(symbol)")
            lastSymbol = symbol
            copiedValue = "TBD"
            selectedOrderIndex = nil
            updateRecommendedOrders()
        }
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
    
    private func rowStyle(for item: SalesCalcResultsRecord) -> Color {
        if item.sharesToSell > sharesAvailableForTrading {
            return .red
        } else if item.trailingStop < (2.0 * getLimitedATR()) {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            contentView
            if copiedValue != "TBD" {
                Text("Copied: \(copiedValue)")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Recommended Sell Orders")
                .font(.headline)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var contentView: some View {
        Group {
            if currentRecommendedSellOrders.isEmpty {
                Text("No recommended sell orders available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                orderTableView
            }
        }
    }
    
    private var orderTableView: some View {
        HStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerRow
                    orderRows
                }
            }
            
            VStack {
                Spacer()
                Button("Submit") {
                    if let selectedIndex = selectedOrderIndex,
                       selectedIndex < currentRecommendedSellOrders.count {
                        let selectedOrder = currentRecommendedSellOrders[selectedIndex]
                        copyToClipboard(text: selectedOrder.description)
                        print("Submitted order: \(selectedOrder.description)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(selectedOrderIndex == nil)
                .padding(.trailing)
                Spacer()
            }
        }
    }
    
    private var headerRow: some View {
        HStack {
            Text("")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .center)
            
            Text("Description")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Shares")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Trailing Stop")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 100, alignment: .trailing)
            
            Text("Entry")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Cancel")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Gain %")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    private var orderRows: some View {
        ForEach(Array(currentRecommendedSellOrders.enumerated()), id: \.offset) { index, order in
            orderRow(index: index, order: order)
        }
    }
    
    private func orderRow(index: Int, order: SalesCalcResultsRecord) -> some View {
        HStack {
            Button(action: {
                selectedOrderIndex = index
            }) {
                Image(systemName: selectedOrderIndex == index ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 30, alignment: .center)
            
            Text(order.description)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    copyToClipboard(text: order.description)
                    selectedOrderIndex = index
                }
            
            Text("\(Int(order.sharesToSell))")
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: Double(order.sharesToSell), format: "%.0f")
                    selectedOrderIndex = index
                }
            
            Text(String(format: "%.2f%%", order.trailingStop))
                .font(.caption)
                .frame(width: 100, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.trailingStop, format: "%.2f")
                    selectedOrderIndex = index
                }
            
            Text(String(format: "%.2f", order.entry))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.entry, format: "%.2f")
                    selectedOrderIndex = index
                }
            
            Text(String(format: "%.2f", order.cancel))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.cancel, format: "%.2f")
                    selectedOrderIndex = index
                }
            
            Text(String(format: "%.1f%%", order.gain))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.gain, format: "%.1f")
                    selectedOrderIndex = index
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(selectedOrderIndex == index ? Color.blue.opacity(0.1) : rowStyle(for: order).opacity(0.1))
        .cornerRadius(4)
    }
} 
