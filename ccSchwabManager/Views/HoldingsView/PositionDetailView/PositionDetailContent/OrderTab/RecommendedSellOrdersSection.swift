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
    
    private func calculateTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        print("=== calculateTop100Order ===")
        print("Current price: $\(currentPrice)")
        print("ATR value: \(atrValue)%")
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
        let atrDollarAmount = currentPrice * (atrValue / 100.0)  // Convert ATR percentage to dollar amount
        let minEntryPrice = currentPrice - atrDollarAmount  // Entry price must be at least 1 ATR below current price
        let entryPrice = max((currentPrice + targetSellPrice) / 2.0, minEntryPrice)
        let trailingStopPercent = ((entryPrice - targetSellPrice) / entryPrice) * 100.0
        
        print("Order parameters:")
        print("  Entry price: $\(entryPrice)")
        print("  Cancel price: $\(hardExitPrice)")
        print("  Trailing stop: \(trailingStopPercent)%")
        print("  ATR requirement: \(2.0 * atrValue)%")
        
        // Skip if trailing stop is less than 2 * ATR
        guard trailingStopPercent >= (2.0 * atrValue) else {
            print("❌ Trailing stop too low: \(trailingStopPercent)% < \(2.0 * atrValue)% (2 * ATR)")
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
                            
                            // Format the description to match the standard sell order format
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                            let formattedDescription = String(format: "(Min) SELL -%.0f %@ @LAST-%.2f%% TRSTPLMT ASK below %.2f cancel below %.2f GTC SUBMIT AT %@",
                                                            roundedShares,
                                                            symbol,
                                                            trailingStopPercent,
                                                            entryPrice,
                                                            hardExitPrice,
                                                            formatReleaseTime(tomorrow))
                            
                            return SalesCalcResultsRecord(
                                shares: roundedShares,
                                rollingGainLoss: totalGain,
                                breakEven: costPerShare,
                                gain: gainPercent,
                                sharesToSell: roundedShares,
                                trailingStop: trailingStopPercent,
                                entry: entryPrice,
                                cancel: hardExitPrice,
                                description: formattedDescription,
                                openDate: "2025-01-01"
                            )
                        } else if isLastLot {
                            // This is the last lot and it's profitable but doesn't meet ATR requirement
                            let roundedShares = ceil(sharesUsed)  // Round up to whole shares
                            print("⚠️ Last lot reached - profitable but trailing stop too low: \(trailingStopPercent)% < \(2.0 * atrValue)% (2 * ATR)")
                            print("   Showing order in orange color")
                            
                            // Format the description to match the standard sell order format
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                            let formattedDescription = String(format: "(Min) SELL -%.0f %@ @LAST-%.2f%% TRSTPLMT ASK below %.2f cancel below %.2f GTC SUBMIT AT %@",
                                                            roundedShares,
                                                            symbol,
                                                            trailingStopPercent,
                                                            entryPrice,
                                                            hardExitPrice,
                                                            formatReleaseTime(tomorrow))
                            
                            return SalesCalcResultsRecord(
                                shares: roundedShares,
                                rollingGainLoss: totalGain,
                                breakEven: costPerShare,
                                gain: gainPercent,
                                sharesToSell: roundedShares,
                                trailingStop: trailingStopPercent,
                                entry: entryPrice,
                                cancel: hardExitPrice,
                                description: formattedDescription,
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
                            
                            // Format the description to match the standard sell order format
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                            let formattedDescription = String(format: "(Min) SELL -%.0f %@ @LAST-%.2f%% TRSTPLMT ASK below %.2f cancel below %.2f GTC SUBMIT AT %@",
                                                            roundedShares,
                                                            symbol,
                                                            trailingStopPercent,
                                                            entryPrice,
                                                            hardExitPrice,
                                                            formatReleaseTime(tomorrow))
                            
                            return SalesCalcResultsRecord(
                                shares: roundedShares,
                                rollingGainLoss: totalGain,
                                breakEven: costPerShare,
                                gain: gainPercent,
                                sharesToSell: roundedShares,
                                trailingStop: trailingStopPercent,
                                entry: entryPrice,
                                cancel: hardExitPrice,
                                description: formattedDescription,
                                openDate: "2025-01-01"
                            )
                        } else if isLastLot {
                            // This is the last lot and it's profitable but doesn't meet ATR requirement
                            print("⚠️ Last lot reached - profitable but trailing stop too low: \(trailingStopPercent)% < \(2.0 * atrValue)% (2 * ATR)")
                            print("   Showing order in orange color")
                            
                            // Format the description to match the standard sell order format
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                            let formattedDescription = String(format: "(Min) SELL -%.0f %@ @LAST-%.2f%% TRSTPLMT ASK below %.2f cancel below %.2f GTC SUBMIT AT %@",
                                                            sharesUsed,
                                                            symbol,
                                                            trailingStopPercent,
                                                            entryPrice,
                                                            hardExitPrice,
                                                            formatReleaseTime(tomorrow))
                            
                            return SalesCalcResultsRecord(
                                shares: sharesUsed,
                                rollingGainLoss: totalGain,
                                breakEven: costPerShare,
                                gain: gainPercent,
                                sharesToSell: sharesUsed,
                                trailingStop: trailingStopPercent,
                                entry: entryPrice,
                                cancel: hardExitPrice,
                                description: formattedDescription,
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
            lastSymbol = symbol
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
        } else if item.trailingStop <= atrValue {
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
                        copiedValue = selectedOrder.description
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
                    copiedValue = order.description
                    selectedOrderIndex = index
                }
            
            Text("\(Int(order.sharesToSell))")
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copiedValue = "\(Int(order.sharesToSell))"
                    selectedOrderIndex = index
                }
            
            Text(String(format: "%.2f%%", order.trailingStop))
                .font(.caption)
                .frame(width: 100, alignment: .trailing)
                .onTapGesture {
                    copiedValue = String(format: "%.2f", order.trailingStop)
                    selectedOrderIndex = index
                }
            
            Text(String(format: "%.2f", order.entry))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copiedValue = String(format: "%.2f", order.entry)
                    selectedOrderIndex = index
                }
            
            Text(String(format: "%.2f", order.cancel))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copiedValue = String(format: "%.2f", order.cancel)
                    selectedOrderIndex = index
                }
            
            Text(String(format: "%.1f%%", order.gain))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copiedValue = String(format: "%.1f", order.gain)
                    selectedOrderIndex = index
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(selectedOrderIndex == index ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
} 
