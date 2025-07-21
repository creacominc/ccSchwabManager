import SwiftUI

struct RecommendedOCOOrdersSection: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
    @State private var selectedOrderIndices: Set<Int> = []
    @State private var recommendedSellOrders: [SalesCalcResultsRecord] = []
    @State private var recommendedBuyOrders: [BuyOrderRecord] = []
    @State private var lastSymbol: String = ""
    @State private var copiedValue: String = "TBD"
    
    private var currentRecommendedSellOrders: [SalesCalcResultsRecord] {
        let orders = calculateRecommendedSellOrders()
        if symbol != lastSymbol {
            DispatchQueue.main.async {
                self.checkAndUpdateSymbol()
            }
        }
        return orders
    }
    
    private var currentRecommendedBuyOrders: [BuyOrderRecord] {
        let orders = calculateRecommendedBuyOrders()
        if symbol != lastSymbol {
            DispatchQueue.main.async {
                self.checkAndUpdateSymbol()
            }
        }
        return orders
    }
    
    private var allOrders: [(String, Any)] {
        var orders: [(String, Any)] = []
        
        // Add sell orders first
        for order in currentRecommendedSellOrders {
            orders.append(("SELL", order))
        }
        
        // Add buy orders
        for order in currentRecommendedBuyOrders {
            orders.append(("BUY", order))
        }
        
        return orders
    }
    
    private func calculateRecommendedSellOrders() -> [SalesCalcResultsRecord] {
        var recommended: [SalesCalcResultsRecord] = []
        
        guard let currentPrice = getCurrentPrice() else {
            print("❌ No current price available for \(symbol)")
            return recommended
        }
        
        let sortedTaxLots = taxLotData.sorted { $0.costPerShare > $1.costPerShare }
        
        print("=== calculateRecommendedSellOrders ===")
        print("Symbol: \(symbol)")
        print("ATR: \(atrValue)%")
        print("Tax lots count: \(taxLotData.count)")
        print("Shares available for trading: \(sharesAvailableForTrading)")
        print("Current price: $\(currentPrice)")
        print("Sorted tax lots by cost per share (highest first): \(sortedTaxLots.count) lots")
        
        // Calculate Top 100 Order
        if let top100Order = calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots) {
            print("✅ Top 100 order created: \(top100Order.description)")
            recommended.append(top100Order)
        }
        
        // Calculate Min Shares Order
        if let minSharesOrder = calculateMinSharesFor5PercentProfit(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots) {
            print("✅ Min shares order created: \(minSharesOrder.description)")
            recommended.append(minSharesOrder)
        }
        
        // Calculate Min Break Even Order
        if let minBreakEvenOrder = calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots) {
            print("✅ Min break even order created: \(minBreakEvenOrder.description)")
            recommended.append(minBreakEvenOrder)
        }
        
        print("=== Final result: \(recommended.count) recommended orders ===")
        return recommended
    }
    
    private func calculateRecommendedBuyOrders() -> [BuyOrderRecord] {
        var recommended: [BuyOrderRecord] = []
        
        guard let currentPrice = getCurrentPrice() else {
            print("❌ No current price available for \(symbol)")
            return recommended
        }
        
        // Calculate total shares and average cost
        let totalShares = taxLotData.reduce(0.0) { $0 + $1.quantity }
        let totalCost = taxLotData.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        
        print("=== calculateRecommendedBuyOrders ===")
        print("Symbol: \(symbol)")
        print("ATR: \(atrValue)%")
        print("Tax lots count: \(taxLotData.count)")
        print("Shares available for trading: \(sharesAvailableForTrading)")
        print("Current price: $\(currentPrice)")
        print("Current position - Shares: \(totalShares), Avg Cost: $\(avgCostPerShare), Current P/L%: \(currentProfitPercent)%")
        
        // Only show buy orders if we have an existing position (shares > 0)
        guard totalShares > 0 else {
            print("❌ No existing position for \(symbol), skipping buy orders")
            return recommended
        }
        
        // Calculate target gain percent based on ATR
        let targetGainPercent = max(15.0, 7.0 * atrValue)
        print("Target gain percent: \(targetGainPercent)% (ATR: \(atrValue)%)")
        
        // Calculate buy order
        let buyOrder = calculateBuyOrder(
            currentPrice: currentPrice,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent,
            targetGainPercent: targetGainPercent,
            totalShares: totalShares
        )
        
        if let order = buyOrder {
            print("✅ Buy order created: \(order.description)")
            recommended.append(order)
        } else {
            print("❌ Buy order not created")
        }
        
        print("=== Final result: \(recommended.count) recommended buy orders ===")
        return recommended
    }
    
    // MARK: - Sell Order Calculations (copied from RecommendedSellOrdersSection)
    
    private func getCurrentPrice() -> Double? {
        // Get the current price from the first tax lot (they all have the same current price)
        return taxLotData.first?.price
    }
    
    private func getLimitedATR() -> Double {
        return max(1.0, min(7.0, atrValue))
    }
    
    private func formatReleaseTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Ensure the date is not in the past
        var adjustedDate = date
        if adjustedDate <= now {
            // Move to the next weekday at 09:40
            var nextWeekday = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            while calendar.component(.weekday, from: nextWeekday) == 1 || calendar.component(.weekday, from: nextWeekday) == 7 {
                // Sunday = 1, Saturday = 7
                nextWeekday = calendar.date(byAdding: .day, value: 1, to: nextWeekday) ?? nextWeekday
            }
            adjustedDate = nextWeekday
        }
        
        var components = calendar.dateComponents([.year, .month, .day], from: adjustedDate)
        components.hour = 9
        components.minute = 40
        components.second = 0
        
        let targetDate = calendar.date(from: components) ?? adjustedDate
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: targetDate)
    }
    
    // --- Top 100 Standing Sell ---
    private func calculateTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        // Remove the sharesAvailableForTrading check - show all orders regardless of available shares
        
        var sharesToConsider: Double = 0
        var totalCost: Double = 0
        
        for lot in sortedTaxLots {
            let needed = min(lot.quantity, 100.0 - sharesToConsider)
            sharesToConsider += needed
            totalCost += needed * lot.costPerShare
            if sharesToConsider >= 100.0 { break }
        }
        guard sharesToConsider >= 100.0 else { return nil }
        let costPerShare = totalCost / sharesToConsider
        
        // ATR for this order is fixed: 1.5 * 0.25 = 0.375%
        let adjustedATR = 1.5 * 0.25
        
        // Target: 3.25% above breakeven (cost per share) - accounting for wash sale adjustments
        let target = costPerShare * 1.0325
        
        // Entry: Target + (1.5 * ATR) above target
        let entry = target * (1.0 + (adjustedATR / 100.0))
        
        // Exit: 0.9% below target
        let exit = target * 0.991
        
        let gain = ((target - costPerShare) / costPerShare) * 100.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Top 100) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", sharesToConsider, symbol, entry, target, exit, costPerShare, formatReleaseTime(tomorrow))
        return SalesCalcResultsRecord(
            shares: sharesToConsider,
            rollingGainLoss: (target - costPerShare) * sharesToConsider,
            breakEven: costPerShare,
            gain: gain,
            sharesToSell: sharesToConsider,
            trailingStop: adjustedATR,
            entry: entry,
            target: target,
            cancel: exit,
            description: formattedDescription,
            openDate: "Top100"
        )
    }

    // --- Minimum ATR-based Standing Sell ---
    private func calculateMinSharesFor5PercentProfit(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        let adjustedATR = 1.5 * getLimitedATR()

        // Only show if position is at least 6% and at least (3.5 * ATR) profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        let minProfitPercent = max(6.0, 3.5 * getLimitedATR())
        guard currentProfitPercent >= minProfitPercent else { return nil }

        print("=== calculateMinSharesFor5PercentProfit ===")
        print("Current price: $\(currentPrice)")
        print("Avg cost per share: $\(avgCostPerShare)")
        print("Current P/L%: \(currentProfitPercent)%")
        print("Min profit % required: \(minProfitPercent)%")
        print("Total shares: \(totalShares)")
        print("Total cost: $\(totalCost)")
        print("Adjusted ATR: \(adjustedATR)%")

        // Target: 3.25% above breakeven (avg cost per share) - accounting for wash sale adjustments
        let target = avgCostPerShare * 1.0325
        print("Target price: $\(target) (3.25% above breakeven)")
        
        // Entry: Below current price by 1.5 * AATR
        let entry = currentPrice / (1.0 + (adjustedATR / 100.0))
        print("Entry price: $\(entry) (below current by \(adjustedATR)%)")
        
        // Exit: 0.9% below target
        let exit = target * 0.991
        print("Exit price: $\(exit) (0.9% below target)")
        
        // Calculate minimum shares needed to achieve 5% gain overall
        var sharesToSell: Double = 0
        var totalGain: Double = 0
        var remainingShares = totalShares
        var remainingCost = totalCost
        
        // Sort tax lots by cost per share (highest first) for FIFO-like selling
        let sortedLots = sortedTaxLots.sorted { $0.costPerShare > $1.costPerShare }
        print("Sorted tax lots by cost per share (highest first): \(sortedLots.count) lots")
        
        for (index, lot) in sortedLots.enumerated() {
            let lotGainPercent = ((currentPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            print("Lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare) (gain: \(lotGainPercent)%)")
            
            if lotGainPercent >= 5.0 {
                // Calculate how many shares from this lot we need to sell
                let sharesFromLot = min(lot.quantity, remainingShares)
                let costFromLot = sharesFromLot * lot.costPerShare
                let gainFromLot = sharesFromLot * (target - lot.costPerShare)
                
                print("  Considering selling \(sharesFromLot) shares from this lot")
                print("  Cost from lot: $\(costFromLot)")
                print("  Gain from lot: $\(gainFromLot)")
                
                // Check if selling these shares would achieve 5% gain overall
                let newRemainingShares = remainingShares - sharesFromLot
                let newRemainingCost = remainingCost - costFromLot
                let newAvgCost = newRemainingCost / newRemainingShares
                let newProfitPercent = ((currentPrice - newAvgCost) / newAvgCost) * 100.0
                
                print("  New remaining shares: \(newRemainingShares)")
                print("  New remaining cost: $\(newRemainingCost)")
                print("  New avg cost: $\(newAvgCost)")
                print("  New P/L%: \(newProfitPercent)%")
                
                if newProfitPercent >= 5.0 {
                    // We can sell these shares and still maintain 5% profit
                    print("  ✅ Can sell all \(sharesFromLot) shares and maintain 5% profit")
                    sharesToSell += sharesFromLot
                    totalGain += gainFromLot
                    remainingShares = newRemainingShares
                    remainingCost = newRemainingCost
                } else {
                    // Selling these shares would drop us below 5% profit
                    // Only sell enough to maintain 5% profit
                    print("  ⚠️ Selling all shares would drop P/L% below 5%")
                    let targetRemainingCost = (currentPrice * remainingShares) / 1.05 // 5% profit
                    let maxCostToSell = remainingCost - targetRemainingCost
                    let maxSharesToSell = maxCostToSell / lot.costPerShare
                    
                    print("  Target remaining cost for 5% profit: $\(targetRemainingCost)")
                    print("  Max cost to sell: $\(maxCostToSell)")
                    print("  Max shares to sell: \(maxSharesToSell)")
                    
                    if maxSharesToSell > 0 {
                        let actualSharesToSell = min(maxSharesToSell, lot.quantity)
                        print("  ✅ Selling \(actualSharesToSell) shares to maintain 5% profit")
                        sharesToSell += actualSharesToSell
                        totalGain += actualSharesToSell * (target - lot.costPerShare)
                    } else {
                        print("  ❌ Cannot sell any shares from this lot")
                    }
                    break
                }
            } else {
                print("  ❌ Lot gain \(lotGainPercent)% is below 5% threshold")
            }
        }
        
        print("Final calculation:")
        print("  Shares to sell: \(sharesToSell)")
        print("  Total gain: $\(totalGain)")
        print("  Remaining shares: \(remainingShares)")
        print("  Remaining cost: $\(remainingCost)")
        
        guard sharesToSell > 0 else { 
            print("❌ No shares to sell")
            return nil 
        }
        
        let gain = (totalGain / sharesToSell) / (target - avgCostPerShare) * 100.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Min ATR) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", sharesToSell, symbol, entry, target, exit, avgCostPerShare, formatReleaseTime(tomorrow))
        print("✅ Min ATR order created: \(formattedDescription)")
        return SalesCalcResultsRecord(
            shares: sharesToSell,
            rollingGainLoss: totalGain,
            breakEven: avgCostPerShare,
            gain: gain,
            sharesToSell: sharesToSell,
            trailingStop: adjustedATR,
            entry: entry,
            target: target,
            cancel: exit,
            description: formattedDescription,
            openDate: "MinATR"
        )
    }

    // --- Minimum Break-even Standing Sell ---
    private func calculateMinBreakEvenOrder(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        // According to sample.log: AATR is ATR/5
        let adjustedATR = atrValue / 5.0

        // Only show if position is at least 1% profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        guard currentProfitPercent >= 1.0 else { return nil }

        print("=== calculateMinBreakEvenOrder ===")
        print("=== calculateMinBreakEvenOrder Current price: $\(currentPrice)")
        print("=== calculateMinBreakEvenOrder Avg cost per share: $\(avgCostPerShare)")
        print("=== calculateMinBreakEvenOrder Current P/L%: \(currentProfitPercent)%")
        print("=== calculateMinBreakEvenOrder Total shares: \(totalShares)")
        print("=== calculateMinBreakEvenOrder Total cost: $\(totalCost)")
        print("=== calculateMinBreakEvenOrder ATR: \(atrValue)%")
        print("=== calculateMinBreakEvenOrder AATR (ATR/5): \(adjustedATR)%")

        // According to sample.log: Entry = Last - 1 AATR%
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        print("=== calculateMinBreakEvenOrder Entry price: $\(entry) (Last - 1 AATR%)")
        
        // According to sample.log: Target = Entry - 2 AATR%
        let target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
        print("=== calculateMinBreakEvenOrder Target price: $\(target) (Entry - 2 AATR%)")
        
        // According to sample.log: Cancel = Target - 2 AATR%
        let exit = target * (1.0 - 2.0 * adjustedATR / 100.0)
        print("=== calculateMinBreakEvenOrder Exit price: $\(exit) (Target - 2 AATR%)")
        
        // Calculate minimum shares needed to achieve 1% gain on the sale
        // We want to find the minimum number of shares that when sold at target price
        // would result in a 1% gain: (target - avg_cost_of_sold_shares) / avg_cost_of_sold_shares >= 0.01
        
        print("=== calculateMinBreakEvenOrder Target price: $\(target)")
        
        // Sort tax lots by cost per share (highest first) for FIFO-like selling
        let sortedLots = sortedTaxLots.sorted { $0.costPerShare > $1.costPerShare }
        print("=== calculateMinBreakEvenOrder Sorted tax lots by cost per share (highest first): \(sortedLots.count) lots")
        
        // Start with the highest cost shares first (FIFO-like)
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        var sharesToSell: Double = 0
        var totalGain: Double = 0
        
        for (index, lot) in sortedLots.enumerated() {
            let lotGainPercent = ((currentPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            print("=== calculateMinBreakEvenOrder Lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare) (gain: \(lotGainPercent)%)")
            
            if lotGainPercent >= 1.0 {
                // Calculate how many shares we need from this lot to achieve 1% gain
                // We want: (target - avg_cost_of_sold_shares) / avg_cost_of_sold_shares >= 0.01
                // This means: target >= avg_cost_of_sold_shares * 1.01
                // For a single lot: target >= cost_per_share * 1.01
                // So: cost_per_share <= target / 1.01
                
                // Check if this lot alone can achieve 1% gain
                let lotGainAtTarget = ((target - lot.costPerShare) / lot.costPerShare) * 100.0
                print("=== calculateMinBreakEvenOrder   Lot gain at target price: \(lotGainAtTarget)%")
                
                if lotGainAtTarget >= 1.0 {
                    // This lot alone can achieve 1% gain, so we only need 1 share
                    sharesToSell = 1.0
                    totalGain = sharesToSell * (target - lot.costPerShare)
                    print("=== calculateMinBreakEvenOrder   ✅ This lot alone achieves 1% gain, selling 1 share")
                    break
                } else {
                    // This lot alone can't achieve 1% gain, so we need to combine with previous lots
                    // Add all shares from this lot and check cumulative gain
                    let sharesFromLot = lot.quantity
                    let costFromLot = sharesFromLot * lot.costPerShare
                    
                    cumulativeShares += sharesFromLot
                    cumulativeCost += costFromLot
                    let avgCost = cumulativeCost / cumulativeShares
                    
                    print("=== calculateMinBreakEvenOrder   Adding \(sharesFromLot) shares, cumulative: \(cumulativeShares) shares, avg cost: $\(avgCost)")
                    
                    // Check if this combination achieves 1% gain at target price
                    let gainPercent = ((target - avgCost) / avgCost) * 100.0
                    print("=== calculateMinBreakEvenOrder   Cumulative gain at target price: \(gainPercent)%")
                    
                    if gainPercent >= 1.0 {
                        // We found the minimum shares needed
                        sharesToSell = cumulativeShares
                        totalGain = cumulativeShares * (target - avgCost)
                        print("=== calculateMinBreakEvenOrder   ✅ Found minimum shares: \(sharesToSell) shares with avg cost $\(avgCost)")
                        break
                    } else {
                        print("=== calculateMinBreakEvenOrder   ⚠️ Not enough gain yet, continuing...")
                    }
                }
            } else {
                print("=== calculateMinBreakEvenOrder   ❌ Lot gain \(lotGainPercent)% is below 1% threshold")
            }
        }
        
        print("=== calculateMinBreakEvenOrder Final calculation:")
        print("=== calculateMinBreakEvenOrder  Shares to sell: \(sharesToSell)")
        print("=== calculateMinBreakEvenOrder  Total gain: $\(totalGain)")
        print("=== calculateMinBreakEvenOrder  Cumulative shares: \(cumulativeShares)")
        print("=== calculateMinBreakEvenOrder  Cumulative cost: $\(cumulativeCost)")
        
        guard sharesToSell > 0 else { 
            print("=== calculateMinBreakEvenOrder ❌ No shares to sell")
            return nil 
        }
        
        let gain = (totalGain / sharesToSell) / (target - avgCostPerShare) * 100.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Min BE) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", sharesToSell, symbol, entry, target, exit, avgCostPerShare, formatReleaseTime(tomorrow))
        print("=== calculateMinBreakEvenOrder ✅ Min break even order created: \(formattedDescription)")
        return SalesCalcResultsRecord(
            shares: sharesToSell,
            rollingGainLoss: totalGain,
            breakEven: avgCostPerShare,
            gain: gain,
            sharesToSell: sharesToSell,
            trailingStop: adjustedATR,
            entry: entry,
            target: target,
            cancel: exit,
            description: formattedDescription,
            openDate: "MinBE"
        )
    }
    
    // MARK: - Buy Order Calculations (copied from RecommendedBuyOrdersSection)
    
    private func calculateBuyOrder(
        currentPrice: Double,
        avgCostPerShare: Double,
        currentProfitPercent: Double,
        targetGainPercent: Double,
        totalShares: Double
    ) -> BuyOrderRecord? {
        
        print("=== calculateBuyOrder (OCO) ===")
        print("Current price: $\(currentPrice)")
        print("Avg cost per share: $\(avgCostPerShare)")
        print("Current P/L%: \(currentProfitPercent)%")
        print("Target gain %: \(targetGainPercent)%")
        print("Total shares: \(totalShares)")
        print("ATR: \(atrValue)%")
        
        // Calculate total cost of current position
        let totalCost = avgCostPerShare * totalShares
        
        // Calculate the entry and target buy prices
        // Entry price should be at least 1 ATR% above the last price
        // Target price should be entry price plus the adjusted ATR%
        let entryPrice: Double
        let targetBuyPrice: Double
        
        if currentProfitPercent < targetGainPercent {
            // Current position is below target gain
            // Entry price should be 1 ATR above the current price
            entryPrice = currentPrice * (1.0 + atrValue / 100.0)
            // Target price should be entry price plus the adjusted ATR%
            targetBuyPrice = entryPrice * (1.0 + atrValue / 100.0)
        } else {
            // Current position is already above target gain
            // Entry price should be between 2x and 4x ATR above the current price
            let minEntryPrice = currentPrice * (1.0 + (2.0 * atrValue / 100.0))
            let maxEntryPrice = currentPrice * (1.0 + (4.0 * atrValue / 100.0))
            // Use the midpoint between min and max for now (could be randomized)
            entryPrice = (minEntryPrice + maxEntryPrice) / 2.0
            // Target price should be entry price plus the adjusted ATR%
            targetBuyPrice = entryPrice * (1.0 + atrValue / 100.0)
        }
        
        print("Current P/L%: \(currentProfitPercent)%")
        print("Target gain %: \(targetGainPercent)%")
        print("Current price: $\(currentPrice)")
        print("Target buy price: $\(targetBuyPrice)")
        print("Entry price: $\(entryPrice)")
        
        // Calculate how many shares we need to buy to bring the combined position to the target gain percentage
        // We want the new average cost to be such that the target buy price represents the target gain percentage
        let sharesToBuy = (totalShares * targetBuyPrice - totalCost) / (targetBuyPrice - avgCostPerShare)
        
        print("Calculated shares to buy: \(sharesToBuy)")
        
        // Apply limits
        var finalSharesToBuy = max(1.0, ceil(sharesToBuy))
        let orderCost = finalSharesToBuy * targetBuyPrice
        
        print("Initial calculation: \(finalSharesToBuy) shares at $\(targetBuyPrice) = $\(orderCost)")
        
        // Limit to $500 maximum investment
        if orderCost > 500.0 {
            finalSharesToBuy = floor(500.0 / targetBuyPrice)
            print("Order cost \(orderCost) exceeds $500 limit, reducing to \(finalSharesToBuy) shares")
        }
        
        // Ensure at least 1 share
        if finalSharesToBuy < 1.0 {
            finalSharesToBuy = 1.0
            print("Ensuring minimum of 1 share")
        }
        
        // Recalculate final order cost
        let finalOrderCost = finalSharesToBuy * targetBuyPrice
        
        print("Final shares to buy: \(finalSharesToBuy)")
        print("Final order cost: $\(finalOrderCost)")
        
        // Check if order is reasonable
        guard finalSharesToBuy > 0 else {
            print("❌ Buy order not reasonable - shares: \(finalSharesToBuy)")
            return nil
        }
        
        // Warn if order cost exceeds $500 but don't reject
        if finalOrderCost > 500.0 {
            print("⚠️ Warning: Order cost $\(finalOrderCost) exceeds $500 limit, but allowing 1 share minimum")
        }
        
        let (submitDate, isImmediate) = calculateSubmitDate()
        let formattedDescription = String(
            format: "BUY %.0f %@ Submit %@ BID >= %.2f TS = %.1f%% Target = %.2f TargetGain = %.1f%%",
            finalSharesToBuy,
            symbol,
            submitDate,
            entryPrice,
            atrValue,
            targetBuyPrice,
            targetGainPercent
        )
        return BuyOrderRecord(
            shares: finalSharesToBuy,
            targetBuyPrice: targetBuyPrice,
            entryPrice: entryPrice,
            trailingStop: atrValue,
            targetGainPercent: targetGainPercent,
            currentGainPercent: currentProfitPercent,
            sharesToBuy: finalSharesToBuy,
            orderCost: finalOrderCost,
            description: formattedDescription,
            orderType: "BUY",
            submitDate: submitDate,
            isImmediate: isImmediate
        )
    }
    
    private func calculateSubmitDate() -> (String, Bool) {
        let calendar : Calendar = Calendar.current
        let now : Date = Date()
        
        // Get the last buy transaction date (7-day rule)
        let lastBuyDate : Date = getLastBuyTransactionDate() ?? Date()
        let sevenDaysAfterLastBuy  : Date = calendar.date( byAdding: .day, value: 7, to: lastBuyDate )  ?? Date()
        
        // Calculate next trading day (only if we need to submit today)
        let nextTradingDay : Date = getNextTradingDay()
        
        // Use the later of the two dates, but only apply the 09:30 adjustment if the 7-day date is today
        let today = calendar.startOfDay(for: now)
        let sevenDaysDate = calendar.startOfDay(for: sevenDaysAfterLastBuy)
        
        // Debug logging
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("DEBUG: calculateSubmitDate (OCO) for \(symbol)")
        print("DEBUG:   now = \(formatter.string(from: now))")
        print("DEBUG:   lastBuyDate = \(formatter.string(from: lastBuyDate))")
        print("DEBUG:   sevenDaysAfterLastBuy = \(formatter.string(from: sevenDaysAfterLastBuy))")
        print("DEBUG:   nextTradingDay = \(formatter.string(from: nextTradingDay))")
        print("DEBUG:   today = \(formatter.string(from: today))")
        print("DEBUG:   sevenDaysDate = \(formatter.string(from: sevenDaysDate))")
        print("DEBUG:   isSevenDaysToday = \(calendar.isDate(sevenDaysDate, inSameDayAs: today))")
        
        let baseDate: Date
        if calendar.isDate(sevenDaysDate, inSameDayAs: today) {
            // 7-day rule says today, so use the next trading day logic (which handles 09:30 adjustment)
            baseDate = nextTradingDay
            print("DEBUG:   using nextTradingDay (7-day rule says today)")
        } else {
            // 7-day rule says a future date, so use that date directly (no 09:30 adjustment)
            baseDate = sevenDaysAfterLastBuy
            print("DEBUG:   using sevenDaysAfterLastBuy (7-day rule says future date)")
        }
        
        print("DEBUG:   baseDate = \(formatter.string(from: baseDate))")
        
        // Set the time to 09:40:00 using calendar components
        var targetDate = calendar.date(bySettingHour: 9, minute: 40, second: 0, of: baseDate) ?? baseDate
        print("DEBUG:   initial targetDate = \(formatter.string(from: targetDate))")
        
        // Check if the target date is in the past
        if targetDate <= now {
            print("DEBUG:   targetDate is in the past, moving to next weekday at 09:40")
            // Move to the next weekday at 09:40
            var nextWeekday = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            while calendar.component(.weekday, from: nextWeekday) == 1 || calendar.component(.weekday, from: nextWeekday) == 7 {
                // Sunday = 1, Saturday = 7
                nextWeekday = calendar.date(byAdding: .day, value: 1, to: nextWeekday) ?? nextWeekday
            }
            targetDate = calendar.date(bySettingHour: 9, minute: 40, second: 0, of: nextWeekday) ?? nextWeekday
            print("DEBUG:   adjusted targetDate = \(formatter.string(from: targetDate))")
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let submitDate = outputFormatter.string(from: targetDate)
        print("DEBUG:   submitDate = \(submitDate)")
        
        // Check if we can submit immediately (target date is today and it's before 09:30)
        let nineThirtyToday = today.addingTimeInterval(9 * 3600 + 30 * 60) // 9 hours and 30 minutes
        let isImmediate = calendar.isDate(targetDate, inSameDayAs: today) && now < nineThirtyToday
        
        return (submitDate, isImmediate)
    }
    
    private func getLastBuyTransactionDate() -> Date? {
        // Get transaction history for this symbol
        let transactions = SchwabClient.shared.getTransactionsFor(symbol: symbol)
        
        // Find the most recent buy transaction
        let buyTransactions = transactions.filter { transaction in
            // Check if any transfer item is a buy (positive amount) for this symbol
            transaction.transferItems.contains { item in
                item.instrument?.symbol == symbol && 
                (item.amount ?? 0) > 0
            }
        }
        
        // Sort by date (most recent first) and get the first one
        let sortedBuyTransactions = buyTransactions.sorted { first, second in
            let firstTime = first.time ?? ""
            let secondTime = second.time ?? ""
            return firstTime > secondTime
        }
        
        guard let mostRecentBuy = sortedBuyTransactions.first,
              let timeString = mostRecentBuy.time else {
            return nil
        }
        
        // Parse the time string to Date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let date = formatter.date(from: timeString) else {
            return nil
        }
        
        return date
    }
    
    private func getNextTradingDay() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if current time is before 09:30
        let today = calendar.startOfDay(for: now)
        let nineThirtyToday = today.addingTimeInterval(9 * 3600 + 30 * 60) // 9 hours and 30 minutes
        
        var baseDate: Date
        if now < nineThirtyToday {
            // Before 09:30, use today
            baseDate = today
        } else {
            // After 09:30, use tomorrow
            baseDate = today.addingTimeInterval(24 * 3600) // Add 24 hours
        }
        
        // Find the next weekday (skip weekends)
        var nextWeekday = baseDate
        while calendar.component(.weekday, from: nextWeekday) == 1 || calendar.component(.weekday, from: nextWeekday) == 7 {
            // Sunday = 1, Saturday = 7
            nextWeekday = calendar.date(byAdding: .day, value: 1, to: nextWeekday) ?? nextWeekday
        }
        
        return nextWeekday
    }
    
    private func updateRecommendedOrders() {
        recommendedSellOrders = calculateRecommendedSellOrders()
        recommendedBuyOrders = calculateRecommendedBuyOrders()
    }
    
    private func checkAndUpdateSymbol() {
        if symbol != lastSymbol {
            print("Symbol changed from \(lastSymbol) to \(symbol)")
            lastSymbol = symbol
            copiedValue = "TBD"
            selectedOrderIndices.removeAll()
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
    
    private func rowStyle(for orderType: String, item: Any) -> Color {
        switch orderType {
        case "SELL":
            if let sellOrder = item as? SalesCalcResultsRecord {
                if sellOrder.sharesToSell > sharesAvailableForTrading {
                    return .red
                } else if sellOrder.trailingStop < (2.0 * getLimitedATR()) {
                    return .orange
                } else {
                    return .green
                }
            }
        case "BUY":
            if let buyOrder = item as? BuyOrderRecord {
                if buyOrder.orderCost > 500.0 {
                    return .red
                } else if buyOrder.trailingStop < 1.0 {
                    return .orange
                } else {
                    return .blue
                }
            }
        default:
            return .primary
        }
        return .primary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            Text("Recommended OCO Orders")
                .font(.headline)
            
            Spacer()
            
            Button(selectedOrderIndices.count == allOrders.count ? "Deselect All" : "Select All") {
                if selectedOrderIndices.count == allOrders.count {
                    // Deselect all
                    selectedOrderIndices.removeAll()
                } else {
                    // Select all
                    selectedOrderIndices = Set(0..<allOrders.count)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(allOrders.isEmpty)
        }
        .padding(.horizontal)
    }
    
    private var contentView: some View {
        Group {
            if allOrders.isEmpty {
                Text("No recommended OCO orders available")
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
                if !selectedOrderIndices.isEmpty {
                    Button(action: submitOCOOrders) {
                        VStack {
                            Image(systemName: "paperplane.circle.fill")
                                .font(.title2)
                            Text("Submit\nOCO")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                Spacer()
            }
            .padding(.trailing, 8)
        }
    }
    
    private func submitOCOOrders() {
        guard !selectedOrderIndices.isEmpty else { return }
        
        let selectedOrders = selectedOrderIndices.compactMap { index in
            index < allOrders.count ? allOrders[index] : nil
        }
        
        // Create OCO order description
        let ocoDescription = createOCOOrderDescription(orders: selectedOrders)
        copyToClipboard(text: ocoDescription)
        print("Submitted OCO orders: \(ocoDescription)")
    }
    
    private func createOCOOrderDescription(orders: [(String, Any)]) -> String {
        guard !orders.isEmpty else { return "" }
        
        var description = "OCO Orders for \(symbol):\n"
        
        for (index, (_, order)) in orders.enumerated() {
            if let sellOrder = order as? SalesCalcResultsRecord {
                description += "Order \(index + 1) (SELL): \(sellOrder.description)\n"
            } else if let buyOrder = order as? BuyOrderRecord {
                description += "Order \(index + 1) (BUY): \(buyOrder.description)\n"
            }
        }
        
        return description
    }
    
    private var headerRow: some View {
        HStack {
            Text("")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .center)
            
            Text("Type")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .leading)
            
            Text("Description")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Shares")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Stop")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 100, alignment: .trailing)
            
            Text("Entry")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Target")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Cancel")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
    }
    
    private var orderRows: some View {
        ForEach(Array(allOrders.enumerated()), id: \.offset) { index, order in
            orderRow(index: index, orderType: order.0, order: order.1)
        }
    }
    
    private func orderRow(index: Int, orderType: String, order: Any) -> some View {
        HStack {
            Button(action: {
                if selectedOrderIndices.contains(index) {
                    selectedOrderIndices.remove(index)
                } else {
                    selectedOrderIndices.insert(index)
                }
            }) {
                Image(systemName: selectedOrderIndices.contains(index) ? "checkmark.square.fill" : "square")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 30, alignment: .center)
            
            Text(orderType)
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .leading)
                .foregroundColor(orderType == "SELL" ? .red : .blue)
            
            Group {
                if let sellOrder = order as? SalesCalcResultsRecord {
                    Text(sellOrder.description)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            copyToClipboard(text: sellOrder.description)
                        }
                    
                    Text("\(Int(sellOrder.sharesToSell))")
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: Double(sellOrder.sharesToSell), format: "%.0f")
                        }
                    
                    Text(String(format: "%.2f%%", sellOrder.trailingStop))
                        .font(.caption)
                        .frame(width: 100, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: sellOrder.trailingStop, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", sellOrder.entry))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: sellOrder.entry, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", sellOrder.target))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: sellOrder.target, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", sellOrder.cancel))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: sellOrder.cancel, format: "%.2f")
                        }
                } else if let buyOrder = order as? BuyOrderRecord {
                    Text(buyOrder.description)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            copyToClipboard(text: buyOrder.description)
                        }
                    
                    Text("\(Int(buyOrder.sharesToBuy))")
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: Double(buyOrder.sharesToBuy), format: "%.0f")
                        }
                    
                    Text(String(format: "%.2f%%", buyOrder.trailingStop))
                        .font(.caption)
                        .frame(width: 100, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: buyOrder.trailingStop, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", buyOrder.entryPrice))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: buyOrder.entryPrice, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", buyOrder.targetBuyPrice))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: buyOrder.targetBuyPrice, format: "%.2f")
                        }
                    
                    Text("")
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .background(selectedOrderIndices.contains(index) ? Color.blue.opacity(0.2) : rowStyle(for: orderType, item: order).opacity(0.1))
        .cornerRadius(4)
    }
} 
