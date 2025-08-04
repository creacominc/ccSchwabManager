import SwiftUI

struct RecommendedOCOOrdersSection: View {

    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
    let quoteData: QuoteData?
    let accountNumber: String
    @State private var selectedOrderIndices: Set<Int> = []
    @State private var recommendedSellOrders: [SalesCalcResultsRecord] = []
    @State private var recommendedBuyOrders: [BuyOrderRecord] = []
    @State private var lastSymbol: String = ""
    @State private var copiedValue: String = "TBD"
    
    // State variables for confirmation dialog
    @State private var showingConfirmationDialog = false
    @State private var orderToSubmit: Order?
    @State private var orderDescriptions: [String] = []
    @State private var orderJson: String = ""
    
    // State variables for success/error alerts
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
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
        
        AppLogger.shared.debug("=== allOrders computed property ===")
        AppLogger.shared.debug("currentRecommendedSellOrders count: \(currentRecommendedSellOrders.count)")
        AppLogger.shared.debug("currentRecommendedBuyOrders count: \(currentRecommendedBuyOrders.count)")
        
        // Add sell orders first
        for (index, order) in currentRecommendedSellOrders.enumerated() {
            AppLogger.shared.debug("  Adding SELL order \(index + 1): sharesToSell=\(order.sharesToSell), entry=\(order.entry), target=\(order.target), cancel=\(order.cancel)")
            orders.append(("SELL", order))
        }
        
        // Add buy orders
        for (index, order) in currentRecommendedBuyOrders.enumerated() {
            AppLogger.shared.debug("  Adding BUY order \(index + 1): sharesToBuy=\(order.sharesToBuy), targetBuyPrice=\(order.targetBuyPrice), entryPrice=\(order.entryPrice), targetGainPercent=\(order.targetGainPercent)")
            orders.append(("BUY", order))
        }
        
        AppLogger.shared.debug("Total orders created: \(orders.count)")
        return orders
    }
    
    private func calculateRecommendedSellOrders() -> [SalesCalcResultsRecord] {
        var recommended: [SalesCalcResultsRecord] = []
        
        guard let currentPrice = getCurrentPrice() else {
            AppLogger.shared.debug("❌ No current price available for \(symbol)")
            return recommended
        }
        
        let sortedTaxLots = taxLotData.sorted { $0.costPerShare > $1.costPerShare }
        
        AppLogger.shared.debug("=== calculateRecommendedSellOrders ===")
        AppLogger.shared.debug("Symbol: \(symbol)")
        AppLogger.shared.debug("ATR: \(atrValue)%")
        AppLogger.shared.debug("Tax lots count: \(taxLotData.count)")
        AppLogger.shared.debug("Shares available for trading: \(sharesAvailableForTrading)")
        AppLogger.shared.debug("Current price: $\(currentPrice)")
        AppLogger.shared.debug("Sorted tax lots by cost per share (highest first): \(sortedTaxLots.count) lots")
        
        // Calculate Top 100 Order
        if let top100Order = calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots) {
            AppLogger.shared.debug("✅ Top 100 order created: \(top100Order.description)")
            recommended.append(top100Order)
        }
        
        // Calculate Min Shares Order
        if let minSharesOrder = calculateMinSharesFor5PercentProfit(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots) {
            AppLogger.shared.debug("✅ Min shares order created: \(minSharesOrder.description)")
            recommended.append(minSharesOrder)
        }
        
        // Calculate Min Break Even Order
        if let minBreakEvenOrder = calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots) {
            AppLogger.shared.debug("✅ Min break even order created: \(minBreakEvenOrder.description)")
            recommended.append(minBreakEvenOrder)
        }
        
        AppLogger.shared.debug("=== Final result: \(recommended.count) recommended orders ===")
        return recommended
    }
    
    private func calculateRecommendedBuyOrders() -> [BuyOrderRecord] {
        var recommended: [BuyOrderRecord] = []
        
        guard let currentPrice = getCurrentPrice() else {
            AppLogger.shared.debug("❌ No current price available for \(symbol)")
            return recommended
        }
        
        // Calculate total shares and average cost
        let totalShares = taxLotData.reduce(0.0) { $0 + $1.quantity }
        let totalCost = taxLotData.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        
        AppLogger.shared.debug("=== calculateRecommendedBuyOrders ===")
        AppLogger.shared.debug("Symbol: \(symbol)")
        AppLogger.shared.debug("ATR: \(atrValue)%")
        AppLogger.shared.debug("Tax lots count: \(taxLotData.count)")
        AppLogger.shared.debug("Shares available for trading: \(sharesAvailableForTrading)")
        AppLogger.shared.debug("Current price: $\(currentPrice)")
        AppLogger.shared.debug("Current position - Shares: \(totalShares), Avg Cost: $\(avgCostPerShare), Current P/L%: \(currentProfitPercent)%")
        
        // Only show buy orders if we have an existing position (shares > 0)
        guard totalShares > 0 else {
            AppLogger.shared.debug("❌ No existing position for \(symbol), skipping buy orders")
            return recommended
        }
        
        // Calculate target gain percent based on ATR
        let targetGainPercent = max(15.0, TradingConfig.atrMultiplier * atrValue)
        AppLogger.shared.debug("Target gain percent: \(targetGainPercent)% (ATR: \(atrValue)%)")
        
        // Calculate primary buy order
        let primaryBuyOrder = calculateBuyOrder(
            currentPrice: currentPrice,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent,
            targetGainPercent: targetGainPercent,
            totalShares: totalShares
        )
        
        if let order = primaryBuyOrder {
            AppLogger.shared.debug("✅ Primary buy order created: \(order.description)")
            recommended.append(order)
            
            // Check if we need a second buy order (trailing stop > 20%)
            if order.trailingStop > 20.0 {
                AppLogger.shared.debug("🔄 Trailing stop \(order.trailingStop)% is above 20%, creating second buy order")
                
                // Calculate second buy order with half the shares and half the trailing stop
                let secondBuyOrder = calculateSecondBuyOrder(
                    primaryOrder: order,
                    currentPrice: currentPrice,
                    avgCostPerShare: avgCostPerShare,
                    currentProfitPercent: currentProfitPercent,
                    targetGainPercent: targetGainPercent,
                    totalShares: totalShares
                )
                
                if let secondOrder = secondBuyOrder {
                    AppLogger.shared.debug("✅ Second buy order created: \(secondOrder.description)")
                    recommended.append(secondOrder)
                } else {
                    AppLogger.shared.debug("❌ Second buy order not created")
                }
            } else {
                AppLogger.shared.debug("ℹ️ Trailing stop \(order.trailingStop)% is not above 20%, skipping second buy order")
            }
        } else {
            AppLogger.shared.debug("❌ Primary buy order not created")
        }
        
        AppLogger.shared.debug("=== Final result: \(recommended.count) recommended buy orders ===")
        return recommended
    }
    
    // MARK: - Sell Order Calculations (copied from RecommendedSellOrdersSection)
    
    private func getCurrentPrice() -> Double? {
        // First try to get the real-time quote price
        if let quote = quoteData?.quote?.lastPrice {
            AppLogger.shared.debug("✅ Using real-time quote price: $\(quote)")
            return quote
        }
        
        // Fallback to extended market price if available
        if let extendedPrice = quoteData?.extended?.lastPrice {
            AppLogger.shared.debug("✅ Using extended market price: $\(extendedPrice)")
            return extendedPrice
        }
        
        // Fallback to regular market price if available
        if let regularPrice = quoteData?.regular?.regularMarketLastPrice {
            AppLogger.shared.debug("✅ Using regular market price: $\(regularPrice)")
            return regularPrice
        }
        
        // Last resort: use the price from tax lot data (may be yesterday's close)
        let fallbackPrice = taxLotData.first?.price
        AppLogger.shared.debug("⚠️ Using fallback price from tax lot data: $\(fallbackPrice ?? 0)")
        return fallbackPrice
    }
    
    private func getLimitedATR() -> Double {
        return max(1.0, min(TradingConfig.atrMultiplier, atrValue))
    }
    
    // OLD CODE - COMMENTED OUT FOR REFERENCE
    // This timing-related function is no longer needed for simplified orders.
    /*
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
    */
    
    // --- Top 100 Standing Sell ---
    private func calculateTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        // Check if position has more than 100 shares total (not just available for trading)
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        
        guard totalShares >= 100.0 else {
            AppLogger.shared.debug("❌ Top 100 order: Position has only \(totalShares) shares, need at least 100")
            return nil
        }
        
        // Calculate the minimum shares needed to achieve 3.25% gain at target price
        // Target: 3.25% above breakeven (cost per share) - accounting for wash sale adjustments
        // let targetGainPercent = 3.25
        
        // We need to calculate the target price first, but we need the cost per share
        // Let's start with a reasonable estimate and then refine
        //let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        // let avgCostPerShare = totalCost / totalShares
        // let estimatedTarget = avgCostPerShare * 1.0325
        
        // For Top-100 order, always use exactly 100 shares of the most expensive shares
        let finalSharesToConsider = 100.0
        
        // Calculate the cost per share for the 100 most expensive shares
        var sharesRemaining = finalSharesToConsider
        var totalCostOfTop100 = 0.0
        var actualCostPerShare = 0.0
        
        for lot in sortedTaxLots {
            if sharesRemaining <= 0 { break }
            
            let sharesFromThisLot = min(lot.quantity, sharesRemaining)
            totalCostOfTop100 += sharesFromThisLot * lot.costPerShare
            sharesRemaining -= sharesFromThisLot
        }
        
        actualCostPerShare = totalCostOfTop100 / finalSharesToConsider
        
        AppLogger.shared.debug("Top 100 order calculation:")
        AppLogger.shared.debug("  Total shares in position: \(totalShares)")
        AppLogger.shared.debug("  Cost per share for 100 most expensive shares: $\(actualCostPerShare)")
        
        // Calculate target price - ensure it's above cost per share
        let target = actualCostPerShare * 1.0325
        
        // Check if target is above cost per share
        let isTargetProfitable = target > actualCostPerShare
        // let totalGain = finalSharesToConsider * (target - actualCostPerShare)
        
        if isTargetProfitable {
            AppLogger.shared.debug("✅ Top 100 order: Target price $\(target) is above cost per share $\(actualCostPerShare)")
        } else {
            AppLogger.shared.debug("⚠️ Top 100 order: Target price $\(target) is below cost per share $\(actualCostPerShare)")
        }
        
        // ATR for this order is fixed: 1.5 * 0.25 = 0.375%
        let adjustedATR = 1.5 * 0.25
        
        // If target is below cost per share, raise it to be profitable
        let adjustedTarget = max(target, actualCostPerShare * 1.01) // At least 1% above cost
        
        // Entry: Adjusted target + (1.5 * ATR) above target
        let entry = adjustedTarget * (1.0 + (adjustedATR / 100.0))
        
        // Exit: 0.9% below adjusted target, but never below cost per share
        let exit = max(adjustedTarget * 0.991, actualCostPerShare)
        
        // Check if entry price is above current price
        let isEntryAboveCurrent = entry > currentPrice
        let isProfitable = isTargetProfitable && !isEntryAboveCurrent
        
        if isEntryAboveCurrent {
            AppLogger.shared.debug("⚠️ Top 100 order: Entry price $\(entry) is above current price $\(currentPrice)")
        } else {
            AppLogger.shared.debug("✅ Top 100 order: Entry price $\(entry) is below current price $\(currentPrice)")
        }
        
        // Calculate gain based on adjusted target
        let gain = ((adjustedTarget - actualCostPerShare) / actualCostPerShare) * 100.0
        // let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        // Create simplified description without timing constraints
        let profitIndicator = isProfitable ? "(Top 100)" : "(Top 100 - UNPROFITABLE)"
        let formattedDescription = String(format: "%@ SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f", profitIndicator, finalSharesToConsider, symbol, adjustedTarget, adjustedATR, actualCostPerShare)
        
        return SalesCalcResultsRecord(
            shares: finalSharesToConsider,
            rollingGainLoss: (adjustedTarget - actualCostPerShare) * finalSharesToConsider,
            breakEven: actualCostPerShare,
            gain: gain,
            sharesToSell: finalSharesToConsider,
            trailingStop: adjustedATR,
            entry: entry,
            target: adjustedTarget,
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

        AppLogger.shared.debug("=== calculateMinSharesFor5PercentProfit ===")
        AppLogger.shared.debug("Current price: $\(currentPrice)")
        AppLogger.shared.debug("Avg cost per share: $\(avgCostPerShare)")
        AppLogger.shared.debug("Current P/L%: \(currentProfitPercent)%")
        AppLogger.shared.debug("Min profit % required: \(minProfitPercent)%")
        AppLogger.shared.debug("Total shares: \(totalShares)")
        AppLogger.shared.debug("Total cost: $\(totalCost)")
        AppLogger.shared.debug("Adjusted ATR: \(adjustedATR)%")

        // Target: 3.25% above breakeven (avg cost per share) - accounting for wash sale adjustments
        let target = avgCostPerShare * 1.0325
        AppLogger.shared.debug("Target price: $\(target) (3.25% above breakeven)")
        
        // Entry: Below current price by 1.5 * AATR
        let entry = currentPrice / (1.0 + (adjustedATR / 100.0))
        AppLogger.shared.debug("Entry price: $\(entry) (below current by \(adjustedATR)%)")
        
        // Use the helper function to calculate minimum shares needed to maintain 5% profit on remaining position
        guard let result = calculateMinimumSharesForRemainingProfit(
            targetProfitPercent: 5.0,
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots
        ) else {
            AppLogger.shared.debug("❌ Min ATR order: Could not achieve 5% profit on remaining position")
            return nil
        }
        
        let sharesToSell = result.sharesToSell
        let totalGain = result.totalGain
        let actualCostPerShare = result.actualCostPerShare
        
        AppLogger.shared.debug("Final calculation:")
        AppLogger.shared.debug("  Shares to sell: \(sharesToSell)")
        AppLogger.shared.debug("  Total gain: $\(totalGain)")
        AppLogger.shared.debug("  Actual cost per share: $\(actualCostPerShare)")
        
        // Validate that target is above the actual cost per share of the shares being sold
        guard target > actualCostPerShare else {
            AppLogger.shared.debug("❌ Min ATR order rejected: target ($\(target)) is not above actual cost per share ($\(actualCostPerShare))")
            return nil
        }
        
        // Exit: 0.9% below target, but never below the actual cost per share of the shares being sold
        let exit = max(target * 0.991, actualCostPerShare)
        AppLogger.shared.debug("Exit price: $\(exit) (0.9% below target, but never below actual cost per share $\(actualCostPerShare))")
        
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        let formattedDescription = String(format: "(Min ATR) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f", sharesToSell, symbol, target, adjustedATR, actualCostPerShare)
        AppLogger.shared.debug("✅ Min ATR order created: \(formattedDescription)")
        return SalesCalcResultsRecord(
            shares: sharesToSell,
            rollingGainLoss: totalGain,
            breakEven: actualCostPerShare,
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

        AppLogger.shared.debug("=== calculateMinBreakEvenOrder ===")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Current price: $\(currentPrice)")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Avg cost per share: $\(avgCostPerShare)")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Current P/L%: \(currentProfitPercent)%")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Total shares: \(totalShares)")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Total cost: $\(totalCost)")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder ATR: \(atrValue)%")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder AATR (ATR/5): \(adjustedATR)%")

        // Check if the highest cost-per-share tax lot is profitable
        guard let highestCostLot = sortedTaxLots.first else { return nil }
        let highestCostProfitPercent = ((currentPrice - highestCostLot.costPerShare) / highestCostLot.costPerShare) * 100.0
        let isHighestCostLotProfitable = highestCostProfitPercent > 0
        
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Highest cost lot: $\(highestCostLot.costPerShare), profit: \(highestCostProfitPercent)%")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Is highest cost lot profitable: \(isHighestCostLotProfitable)")
        
        let entry: Double
        let target: Double
        let sharesToSell: Double
        let actualCostPerShare: Double
        
        if isHighestCostLotProfitable {
            // New logic: If highest cost lot is profitable
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Using new profitable logic")
            
            // Set shares to 50% of the highest tax lot
            sharesToSell = ceil(highestCostLot.quantity * 0.5)
            actualCostPerShare = highestCostLot.costPerShare
            
            // Use descriptive variable names for clarity
            let costPerShare = actualCostPerShare
            let lastPrice = currentPrice
            
            // Target price = (lastPrice + costPerShare)/2 or (lastPrice - costPerShare)/2 + costPerShare
            target = (lastPrice + costPerShare) / 2.0
            
            // Entry point = (lastPrice - costPerShare)/4 + target (halfway between last and target)
            entry = (lastPrice - costPerShare) / 4.0 + target
            
            // Trailing stop = 1/4 of the amount from entry to target
            let trailingStopValue = ((entry - target) / target) * 100.0
            
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Cost per share: $\(costPerShare)")
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Last price: $\(lastPrice)")
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Target price: $\(target) = (lastPrice + costPerShare)/2")
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Entry price: $\(entry) = (lastPrice - costPerShare)/4 + target")
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Shares to sell: \(sharesToSell) (50% of highest lot)")
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Trailing stop: \(trailingStopValue)% (1/4 from entry to target)")
            
        } else {
            // Original logic: Entry = Last - 1 AATR%, Target = Entry - 2 AATR%
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Using original break-even logic")
            
            entry = currentPrice * (1.0 - adjustedATR / 100.0)
            target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
            
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Entry price: $\(entry) (Last - 1 AATR%)")
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Target price: $\(target) (Entry - 2 AATR%)")
            
            // Use the helper function to calculate minimum shares needed to achieve 1% gain at target price
            guard let result = calculateMinimumSharesForGain(
                targetGainPercent: 1.0,
                targetPrice: target,
                sortedTaxLots: sortedTaxLots
            ) else {
                AppLogger.shared.debug("❌ Min Break Even order: Could not achieve 1% gain at target price")
                return nil
            }
            
            sharesToSell = result.sharesToSell
            actualCostPerShare = result.actualCostPerShare
            
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder Final calculation:")
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder  Shares to sell: \(sharesToSell)")
            AppLogger.shared.debug("=== calculateMinBreakEvenOrder  Actual cost per share: $\(actualCostPerShare)")
        }
        
        // Validate that target is above the actual cost per share of the shares being sold
        guard target > actualCostPerShare else {
            AppLogger.shared.debug("❌ Min Break Even order rejected: target ($\(target)) is not above actual cost per share ($\(actualCostPerShare))")
            return nil
        }
        
        // Calculate exit price
        let exit: Double
        if isHighestCostLotProfitable {
            // Exit (cancel) = target - (lastPrice - costPerShare)/4 (1/4 below target)
            let costPerShare = actualCostPerShare
            let lastPrice = currentPrice
            exit = target - (lastPrice - costPerShare) / 4.0
        } else {
            // Original logic: Cancel = Target - 2 AATR%, but never below actual cost per share
            exit = max(target * (1.0 - 2.0 * adjustedATR / 100.0), actualCostPerShare)
        }
        
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Exit price: $\(exit) = target - (lastPrice - costPerShare)/4")
        
        // Verify the ordering: Entry > Target > Exit > Cost-per-share for sell orders
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Ordering verification:")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Entry ($\(entry)) > Target ($\(target)) > Exit ($\(exit)) > CostPerShare ($\(actualCostPerShare))")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Entry > Target: \(entry > target)")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Target > Exit: \(target > exit)")
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Exit > CostPerShare: \(exit > actualCostPerShare)")
        
        let totalGain = sharesToSell * (target - actualCostPerShare)
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Calculate trailing stop value
        let trailingStopValue = isHighestCostLotProfitable ? 
            ((entry - target) / target) * 100.0 : adjustedATR
        
        // Simplified description without timing constraints
        let formattedDescription = String(format: "(Min BE) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                                          sharesToSell, symbol, target, trailingStopValue, actualCostPerShare)
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder ✅ Min break even order created: \(formattedDescription)")
        
        return SalesCalcResultsRecord(
            shares: sharesToSell,
            rollingGainLoss: totalGain,
            breakEven: actualCostPerShare,
            gain: gain,
            sharesToSell: sharesToSell,
            trailingStop: trailingStopValue,
            entry: entry,
            target: target,
            cancel: exit,
            description: formattedDescription,
            openDate: "MinBE"
        )
    }
    
    
    private func calculateBuyOrder(
        currentPrice: Double,
        avgCostPerShare: Double,
        currentProfitPercent: Double,
        targetGainPercent: Double,
        totalShares: Double
    ) -> BuyOrderRecord? {
        
        AppLogger.shared.debug("=== calculateBuyOrder (OCO) ===")
        AppLogger.shared.debug("Current price: $\(currentPrice)")
        AppLogger.shared.debug("Avg cost per share: $\(avgCostPerShare)")
        AppLogger.shared.debug("Current P/L%: \(currentProfitPercent)%")
        AppLogger.shared.debug("Target gain %: \(targetGainPercent)%")
        AppLogger.shared.debug("Total shares: \(totalShares)")
        AppLogger.shared.debug("ATR: \(atrValue)%")
        
        // Calculate total cost of current position
        let totalCost = avgCostPerShare * totalShares
        
        // Calculate the entry and target buy prices
        let entryPrice: Double
        let targetBuyPrice: Double
        let trailingStopPercent: Double
        
        if currentProfitPercent < targetGainPercent {
            // Current position is below target gain
            // Target price should be 33% above current price (1.333 * currentPrice)
            targetBuyPrice = currentPrice * 1.333
            
            // Entry price should be 1 ATR% below the target price
            entryPrice = targetBuyPrice * (1.0 - atrValue / 100.0)
            
            // Trailing stop should be set so that from current price, the stop would be at target price
            // This means: currentPrice * (1 + trailingStopPercent/100) = targetBuyPrice
            // So: trailingStopPercent = ((targetBuyPrice / currentPrice) - 1) * 100
            trailingStopPercent = ((targetBuyPrice / currentPrice) - 1.0) * 100.0
            AppLogger.shared.debug("=== calculateBuyOrder (OCO) trailingStopPercent: \(trailingStopPercent) = (( targetBuyPrice: \(targetBuyPrice) / currentPrice: \(currentPrice) ) -1 ) * 100.0")

            AppLogger.shared.debug("Position below target gain - using new strategy:")
            AppLogger.shared.debug("  Target price (33% above current): $\(targetBuyPrice)")
            AppLogger.shared.debug("  Entry price (1 ATR% below target): $\(entryPrice)")
            AppLogger.shared.debug("  Trailing stop %: \(trailingStopPercent)%")
        } else {
            // Current position is already above target gain
            // Use the original logic for positions already profitable
            let minEntryPrice = currentPrice * (1.0 + (2.0 * atrValue / 100.0))
            let maxEntryPrice = currentPrice * (1.0 + (4.0 * atrValue / 100.0))
            entryPrice = (minEntryPrice + maxEntryPrice) / 2.0
            targetBuyPrice = entryPrice * (1.0 + atrValue / 100.0)
            trailingStopPercent = atrValue
            AppLogger.shared.debug("=== calculateBuyOrder (OCO) trailingStopPercent: \(trailingStopPercent) = (( atrValue: \(atrValue) ) )")

            AppLogger.shared.debug("Position above target gain - using original logic:")
            AppLogger.shared.debug("  Entry price: $\(entryPrice)")
            AppLogger.shared.debug("  Target price: $\(targetBuyPrice)")
            AppLogger.shared.debug("  Trailing stop %: \(trailingStopPercent)%")
        }
        
        AppLogger.shared.debug("Current P/L%: \(currentProfitPercent)%")
        AppLogger.shared.debug("Target gain %: \(targetGainPercent)%")
        AppLogger.shared.debug("Current price: $\(currentPrice)")
        AppLogger.shared.debug("Target buy price: $\(targetBuyPrice)")
        AppLogger.shared.debug("Entry price: $\(entryPrice)")
        AppLogger.shared.debug("Trailing stop %: \(trailingStopPercent)%")
        
        // Calculate how many shares we need to buy to bring the combined position to the target gain percentage
        // We want the new average cost to be such that the target buy price represents the target gain percentage
        let sharesToBuy = (totalShares * targetBuyPrice - totalCost) / (targetBuyPrice - avgCostPerShare)
        
        AppLogger.shared.debug("Calculated shares to buy: \(sharesToBuy)")
        
        // Apply limits
        var finalSharesToBuy = max(1.0, ceil(sharesToBuy))
        let orderCost = finalSharesToBuy * targetBuyPrice
        
        AppLogger.shared.debug("Initial calculation: \(finalSharesToBuy) shares at $\(targetBuyPrice) = $\(orderCost)")
        
        // Limit to $500 maximum investment
        if orderCost > 500.0 {
            finalSharesToBuy = floor(500.0 / targetBuyPrice)
            AppLogger.shared.debug("Order cost \(orderCost) exceeds $500 limit, reducing to \(finalSharesToBuy) shares")
        }
        
        // Ensure at least 1 share
        if finalSharesToBuy < 1.0 {
            finalSharesToBuy = 1.0
            AppLogger.shared.debug("Ensuring minimum of 1 share")
        }
        
        // Recalculate final order cost
        let finalOrderCost = finalSharesToBuy * targetBuyPrice
        
        AppLogger.shared.debug("Final shares to buy: \(finalSharesToBuy)")
        AppLogger.shared.debug("Final order cost: $\(finalOrderCost)")
        
        // Check if order is reasonable
        guard finalSharesToBuy > 0 else {
            AppLogger.shared.debug("❌ Buy order not reasonable - shares: \(finalSharesToBuy)")
            return nil
        }
        
        // Warn if order cost exceeds $500 but don't reject
        if finalOrderCost > 500.0 {
            AppLogger.shared.debug("⚠️ Warning: Order cost $\(finalOrderCost) exceeds $500 limit, but allowing 1 share minimum")
        }
        
        // Simplified order description without timing constraints
        let formattedDescription = String(
            format: "BUY %.0f %@ Target = %.2f TS = %.1f%% TargetGain = %.1f%%",
            finalSharesToBuy,
            symbol,
            targetBuyPrice,
            trailingStopPercent,
            targetGainPercent
        )
        return BuyOrderRecord(
            shares: finalSharesToBuy,
            targetBuyPrice: targetBuyPrice,
            entryPrice: entryPrice,
            trailingStop: trailingStopPercent,
            targetGainPercent: targetGainPercent,
            currentGainPercent: currentProfitPercent,
            sharesToBuy: finalSharesToBuy,
            orderCost: finalOrderCost,
            description: formattedDescription,
            orderType: "BUY",
            submitDate: "", // No submit date for simplified orders
            isImmediate: false // No immediate submission for simplified orders
        )
    }
    
    private func calculateSecondBuyOrder(
        primaryOrder: BuyOrderRecord,
        currentPrice: Double,
        avgCostPerShare: Double,
        currentProfitPercent: Double,
        targetGainPercent: Double,
        totalShares: Double
    ) -> BuyOrderRecord? {
        
        AppLogger.shared.debug("=== calculateSecondBuyOrder ===")
        AppLogger.shared.debug("Primary order trailing stop: \(primaryOrder.trailingStop)%")
        AppLogger.shared.debug("Primary order shares: \(primaryOrder.sharesToBuy)")
        
        // Calculate half the shares and half the trailing stop
        let secondOrderShares = max(1.0, ceil(primaryOrder.sharesToBuy / 2.0))
        let secondOrderTrailingStop = primaryOrder.trailingStop / 2.0
        
        AppLogger.shared.debug("Second order shares: \(secondOrderShares) (half of \(primaryOrder.sharesToBuy))")
        AppLogger.shared.debug("Second order trailing stop: \(secondOrderTrailingStop)% (half of \(primaryOrder.trailingStop)%)")
        
        // Use the same target price as the primary order
        let targetBuyPrice = primaryOrder.targetBuyPrice
        let entryPrice = primaryOrder.entryPrice
        
        // Calculate order cost
        let orderCost = secondOrderShares * targetBuyPrice
        
        AppLogger.shared.debug("Second order cost: $\(orderCost)")
        
        // Check if order is reasonable
        guard secondOrderShares > 0 else {
            AppLogger.shared.debug("❌ Second buy order not reasonable - shares: \(secondOrderShares)")
            return nil
        }
        
        // Simplified order description for second order
        let formattedDescription = String(
            format: "BUY %.0f %@ Target = %.2f TS = %.1f%% TargetGain = %.1f%%",
            secondOrderShares,
            symbol,
            targetBuyPrice,
            secondOrderTrailingStop,
            targetGainPercent
        )
        
        AppLogger.shared.debug("✅ Second buy order created: \(formattedDescription)")
        
        return BuyOrderRecord(
            shares: secondOrderShares,
            targetBuyPrice: targetBuyPrice,
            entryPrice: entryPrice,
            trailingStop: secondOrderTrailingStop,
            targetGainPercent: targetGainPercent,
            currentGainPercent: currentProfitPercent,
            sharesToBuy: secondOrderShares,
            orderCost: orderCost,
            description: formattedDescription,
            orderType: "BUY",
            submitDate: "", // No submit date for simplified orders
            isImmediate: false // No immediate submission for simplified orders
        )
    }
    
    // OLD CODE - COMMENTED OUT FOR REFERENCE
    // The following timing-related functions are no longer needed for simplified orders
    // that don't use submit/cancel times or dates.
    /*
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
        AppLogger.shared.debug("DEBUG: calculateSubmitDate (OCO) for \(symbol)")
        AppLogger.shared.debug("DEBUG:   now = \(formatter.string(from: now))")
        AppLogger.shared.debug("DEBUG:   lastBuyDate = \(formatter.string(from: lastBuyDate))")
        AppLogger.shared.debug("DEBUG:   sevenDaysAfterLastBuy = \(formatter.string(from: sevenDaysAfterLastBuy))")
        AppLogger.shared.debug("DEBUG:   nextTradingDay = \(formatter.string(from: nextTradingDay))")
        AppLogger.shared.debug("DEBUG:   today = \(formatter.string(from: today))")
        AppLogger.shared.debug("DEBUG:   sevenDaysDate = \(formatter.string(from: sevenDaysDate))")
        AppLogger.shared.debug("DEBUG:   isSevenDaysToday = \(calendar.isDate(sevenDaysDate, inSameDayAs: today))")
        
        let baseDate: Date
        if calendar.isDate(sevenDaysDate, inSameDayAs: today) {
            // 7-day rule says today, so use the next trading day logic (which handles 09:30 adjustment)
            baseDate = nextTradingDay
            AppLogger.shared.debug("DEBUG:   using nextTradingDay (7-day rule says today)")
        } else {
            // 7-day rule says a future date, so use that date directly (no 09:30 adjustment)
            baseDate = sevenDaysAfterLastBuy
            AppLogger.shared.debug("DEBUG:   using sevenDaysAfterLastBuy (7-day rule says future date)")
        }
        
        AppLogger.shared.debug("DEBUG:   baseDate = \(formatter.string(from: baseDate))")
        
        // Set the time to 09:40:00 using calendar components
        var targetDate = calendar.date(bySettingHour: 9, minute: 40, second: 0, of: baseDate) ?? baseDate
        AppLogger.shared.debug("DEBUG:   initial targetDate = \(formatter.string(from: targetDate))")
        
        // Check if the target date is in the past
        if targetDate <= now {
            AppLogger.shared.debug("DEBUG:   targetDate is in the past, moving to next weekday at 09:40")
            // Move to the next weekday at 09:40
            var nextWeekday = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            while calendar.component(.weekday, from: nextWeekday) == 1 || calendar.component(.weekday, from: nextWeekday) == 7 {
                // Sunday = 1, Saturday = 7
                nextWeekday = calendar.date(byAdding: .day, value: 1, to: nextWeekday) ?? nextWeekday
            }
            targetDate = calendar.date(bySettingHour: 9, minute: 40, second: 0, of: nextWeekday) ?? nextWeekday
            AppLogger.shared.debug("DEBUG:   adjusted targetDate = \(formatter.string(from: targetDate))")
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let submitDate = outputFormatter.string(from: targetDate)
        AppLogger.shared.debug("DEBUG:   submitDate = \(submitDate)")
        
        // Check if we can submit immediately (target date is today and it's before 09:30)
        let nineThirtyToday = today.addingTimeInterval(9 * 3600 + 30 * 60) // 9 hours and 30 minutes
        let isImmediate = calendar.isDate(targetDate, inSameDayAs: today) && now < nineThirtyToday
        
        return (submitDate, isImmediate)
    }
    */
    
    // OLD CODE - COMMENTED OUT FOR REFERENCE
    // These timing-related functions are no longer needed for simplified orders.
    /*
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
    */
    
    private func updateRecommendedOrders() {
        recommendedSellOrders = calculateRecommendedSellOrders()
        recommendedBuyOrders = calculateRecommendedBuyOrders()
    }
    
    private func checkAndUpdateSymbol() {
        if symbol != lastSymbol {
            AppLogger.shared.debug("Symbol changed from \(lastSymbol) to \(symbol)")
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
                // Check if this is an unprofitable Top-100 order
                if sellOrder.description.contains("UNPROFITABLE") {
                    return .purple  // Purple for unprofitable Top-100 orders
                } else if sellOrder.sharesToSell > sharesAvailableForTrading {
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
        .sheet(isPresented: $showingConfirmationDialog) {
            confirmationDialogView
        }
        .onChange(of: showingConfirmationDialog) { _, isPresented in
            if isPresented {
                AppLogger.shared.debug("=== Sheet is being presented ===")
                AppLogger.shared.debug("orderDescriptions count: \(orderDescriptions.count)")
                AppLogger.shared.debug("orderJson length: \(orderJson.count)")
                AppLogger.shared.debug("orderToSubmit is nil: \(orderToSubmit == nil)")
            }
        }
        .alert("Order Submission Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Order Submitted Successfully", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your OCO order has been submitted successfully.")
        }
    }
    
    private var confirmationDialogView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Confirm OCO Order Submission")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Cancel") {
                    showingConfirmationDialog = false
                    orderToSubmit = nil
                    orderDescriptions = []
                    orderJson = ""
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Order Descriptions Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Please review the following orders before submission:")
                    .font(.headline)
                
                if orderDescriptions.isEmpty {
                    Text("No order descriptions available")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(orderDescriptions.enumerated()), id: \.offset) { index, description in
                            Text(description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // JSON Section
            VStack(alignment: .leading, spacing: 8) {
                Text("JSON to be submitted:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ScrollView {
                    Text(orderJson.isEmpty ? "No JSON available" : orderJson)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action Buttons
            HStack {
                Spacer()
                
                Button("Submit Order") {
                    confirmAndSubmitOrder()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 600, minHeight: 400)
        .padding()
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
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] === submitOCOOrders START ===")
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] Selected order indices: \(selectedOrderIndices)")
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] All orders count: \(allOrders.count)")
        
        guard !selectedOrderIndices.isEmpty else { 
            AppLogger.shared.debug("🔄 [OCO-SUBMIT] ❌ No orders selected")
            return 
        }
        
        let selectedOrders = selectedOrderIndices.compactMap { index in
            index < allOrders.count ? allOrders[index] : nil
        }
        
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] Selected orders count: \(selectedOrders.count)")
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] Selected orders details:")
        for (index, (orderType, order)) in selectedOrders.enumerated() {
            AppLogger.shared.debug("🔄 [OCO-SUBMIT]   Order \(index + 1): type=\(orderType), order=\(type(of: order))")
            if let sellOrder = order as? SalesCalcResultsRecord {
                AppLogger.shared.debug("🔄 [OCO-SUBMIT]     SELL order: sharesToSell=\(sellOrder.sharesToSell), entry=\(sellOrder.entry), target=\(sellOrder.target), cancel=\(sellOrder.cancel)")
            } else if let buyOrder = order as? BuyOrderRecord {
                AppLogger.shared.debug("🔄 [OCO-SUBMIT]     BUY order: sharesToBuy=\(buyOrder.sharesToBuy), targetBuyPrice=\(buyOrder.targetBuyPrice), entryPrice=\(buyOrder.entryPrice), targetGainPercent=\(buyOrder.targetGainPercent)")
            } else {
                AppLogger.shared.debug("🔄 [OCO-SUBMIT]     Unknown order type: \(type(of: order))")
            }
        }
        
        // Get account number from the position
        guard let accountNumberInt = getAccountNumber() else {
            AppLogger.shared.debug("🔄 [OCO-SUBMIT] ❌ Could not get account number for position")
            return
        }
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] Account number: \(accountNumberInt)")
        
        // Simplified OCO order creation - no timing constraints
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] Creating simplified OCO order without timing constraints")
        
        // Create order using SchwabClient (single order or OCO)
        guard let orderToSubmit = SchwabClient.shared.createOrder(
            symbol: symbol,
            accountNumber: accountNumberInt,
            selectedOrders: selectedOrders,
            releaseTime: "" // No release time for simplified orders
        ) else {
            AppLogger.shared.debug("🔄 [OCO-SUBMIT] ❌ Failed to create order")
            return
        }
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] ✅ Order created successfully")
        
        // Create order descriptions for confirmation dialog
        orderDescriptions = createOrderDescriptions(orders: selectedOrders)
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] Created \(orderDescriptions.count) order descriptions:")
        for (index, description) in orderDescriptions.enumerated() {
            AppLogger.shared.debug("🔄 [OCO-SUBMIT]   \(index + 1): \(description)")
        }
        
        // Create JSON preview
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(orderToSubmit)
            orderJson = String(data: jsonData, encoding: .utf8) ?? "{}"
            AppLogger.shared.debug("🔄 [OCO-SUBMIT] JSON created successfully, length: \(orderJson.count)")
            AppLogger.shared.debug("🔄 [OCO-SUBMIT] JSON preview : \(String(orderJson))")
        } catch {
            orderJson = "Error encoding order: \(error)"
            AppLogger.shared.debug("🔄 [OCO-SUBMIT] ❌ JSON encoding error: \(error)")
        }
        
        // Store the order and show confirmation dialog
        self.orderToSubmit = orderToSubmit
        showingConfirmationDialog = true
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] ✅ Showing confirmation dialog")
        AppLogger.shared.debug("🔄 [OCO-SUBMIT] === submitOCOOrders END ===")
    }
    
    private func getAccountNumber() -> Int64? {
        // Get the full account number from SchwabClient instead of using the truncated version
        let accounts = SchwabClient.shared.getAccounts()
        AppLogger.shared.debug("=== getAccountNumber ===")
        AppLogger.shared.debug("Total accounts found: \(accounts.count)")
        
        for (index, accountContent) in accounts.enumerated() {
            AppLogger.shared.debug("Account \(index + 1):")
            AppLogger.shared.debug("  Securities account: \(accountContent.securitiesAccount?.accountNumber ?? "nil")")
            AppLogger.shared.debug("  Positions count: \(accountContent.securitiesAccount?.positions.count ?? 0)")
            
            // Check if this account contains the current symbol
            if let positions = accountContent.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        AppLogger.shared.debug("  ✅ Found position for symbol \(symbol) in this account")
                        if let fullAccountNumber = accountContent.securitiesAccount?.accountNumber,
                           let accountNumberInt = Int64(fullAccountNumber) {
                            AppLogger.shared.debug("  ✅ Using full account number: \(fullAccountNumber)")
                            return accountNumberInt
                        } else {
                            AppLogger.shared.debug("  ❌ Could not convert account number to Int64")
                        }
                    }
                }
            }
        }
        
        // Fallback to the truncated version if full account number not found
        AppLogger.shared.debug("❌ No matching account found for symbol \(symbol), using truncated account number: \(accountNumber)")
        return Int64(accountNumber)
    }
    
    // OLD CODE - COMMENTED OUT FOR REFERENCE
    // These timing-related functions are no longer needed for simplified orders.
    /*
    private func calculateReleaseTime() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Get tomorrow's date
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
            return formatDateForSchwab(now)
        }
        
        // Set to 9:30 AM (market open)
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 30
        components.second = 0
        
        guard let marketOpen = calendar.date(from: components) else {
            return formatDateForSchwab(tomorrow)
        }
        
        return formatDateForSchwab(marketOpen)
    }
    
    private func formatDateForSchwab(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: date)
    }
    */
    
    private func createOrderDescriptions(orders: [(String, Any)]) -> [String] {
        AppLogger.shared.debug("=== createOrderDescriptions ===")
        AppLogger.shared.debug("Input orders count: \(orders.count)")
        
        var descriptions: [String] = []
        for (index, (orderType, order)) in orders.enumerated() {
            AppLogger.shared.debug("Processing order \(index + 1): type=\(orderType), order=\(type(of: order))")
            
            if let sellOrder = order as? SalesCalcResultsRecord {
                AppLogger.shared.debug("  Found SELL order: sharesToSell=\(sellOrder.sharesToSell), entry=\(sellOrder.entry), target=\(sellOrder.target), cancel=\(sellOrder.cancel)")
                let description = sellOrder.description.isEmpty ? 
                    "SELL \(sellOrder.sharesToSell) shares at \(sellOrder.entry) (Target: \(sellOrder.target), Cancel: \(sellOrder.cancel))" :
                    sellOrder.description
                descriptions.append("Order \(index + 1) (SELL): \(description)")
            } else if let buyOrder = order as? BuyOrderRecord {
                AppLogger.shared.debug("  Found BUY order: sharesToBuy=\(buyOrder.sharesToBuy), targetBuyPrice=\(buyOrder.targetBuyPrice), entryPrice=\(buyOrder.entryPrice), targetGainPercent=\(buyOrder.targetGainPercent)")
                let description = buyOrder.description.isEmpty ?
                    "BUY \(buyOrder.sharesToBuy) shares at \(buyOrder.targetBuyPrice) (Entry: \(buyOrder.entryPrice), Target: \(buyOrder.targetGainPercent)%)" :
                    buyOrder.description
                descriptions.append("Order \(index + 1) (BUY): \(description)")
            } else {
                AppLogger.shared.debug("  ❌ Unknown order type: \(type(of: order))")
            }
        }
        
        AppLogger.shared.debug("Created \(descriptions.count) descriptions")
        return descriptions
    }
    
    private func confirmAndSubmitOrder() {
        guard let order = orderToSubmit else { return }
        
        // Submit the order asynchronously
        Task {
            let result = await SchwabClient.shared.placeOrder(order: order)
            
            await MainActor.run {
                // Clear the dialog state
                showingConfirmationDialog = false
                orderToSubmit = nil
                orderDescriptions = []
                orderJson = ""
                selectedOrderIndices.removeAll()
                
                // Show success or error dialog
                if result.success {
                    showingSuccessAlert = true
                } else {
                    errorMessage = result.errorMessage ?? "Unknown error occurred"
                    showingErrorAlert = true
                }
            }
        }
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
            
            Text("Target")
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
                    
                    Text(String(format: "%.2f", sellOrder.target))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: sellOrder.target, format: "%.2f")
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
                    
                    Text(String(format: "%.2f", buyOrder.targetBuyPrice))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: buyOrder.targetBuyPrice, format: "%.2f")
                        }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .background(selectedOrderIndices.contains(index) ? Color.blue.opacity(0.2) : rowStyle(for: orderType, item: order).opacity(0.1))
        .cornerRadius(4)
    }
    
    // MARK: - Helper Functions for Minimum Share Calculations
    
    /// Calculates the minimum shares needed from tax lots to meet a specific gain requirement
    /// - Parameters:
    ///   - targetGainPercent: The minimum gain percentage required
    ///   - targetPrice: The price at which the shares will be sold
    ///   - sortedTaxLots: Tax lots sorted by cost per share (highest first for FIFO-like selling)
    /// - Returns: A tuple containing (sharesToSell, totalGain, actualCostPerShare) or nil if not possible
    private func calculateMinimumSharesForGain(
        targetGainPercent: Double,
        targetPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord]
    ) -> (sharesToSell: Double, totalGain: Double, actualCostPerShare: Double)? {
        
        AppLogger.shared.debug("=== calculateMinimumSharesForGain ===")
        AppLogger.shared.debug("Target gain %: \(targetGainPercent)%")
        AppLogger.shared.debug("Target price: $\(targetPrice)")
        AppLogger.shared.debug("Tax lots count: \(sortedTaxLots.count)")
        
        // First, separate profitable and unprofitable lots
        var profitableLots: [SalesCalcPositionsRecord] = []
        var unprofitableLots: [SalesCalcPositionsRecord] = []
        
        for (index, lot) in sortedTaxLots.enumerated() {
            let gainAtTarget = ((targetPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            AppLogger.shared.debug("Lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare) (gain at target: \(gainAtTarget)%)")
            
            if gainAtTarget > 0 {
                profitableLots.append(lot)
                AppLogger.shared.debug("  ✅ Profitable lot: \(lot.quantity) shares")
            } else {
                unprofitableLots.append(lot)
                AppLogger.shared.debug("  ❌ Unprofitable lot: \(lot.quantity) shares")
            }
        }
        
        AppLogger.shared.debug("Profitable lots: \(profitableLots.count)")
        AppLogger.shared.debug("Unprofitable lots: \(unprofitableLots.count)")
        
        // Always start with unprofitable shares first (FIFO-like selling)
        // Then add minimum profitable shares needed to achieve target gain
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        
        // First, add all unprofitable shares
        for (index, lot) in unprofitableLots.enumerated() {
            AppLogger.shared.debug("Unprofitable lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare)")
            
            let sharesFromLot = lot.quantity
            let costFromLot = sharesFromLot * lot.costPerShare
            
            cumulativeShares += sharesFromLot
            cumulativeCost += costFromLot
            let avgCost = cumulativeCost / cumulativeShares
            
            AppLogger.shared.debug("  Adding \(sharesFromLot) shares, cumulative: \(cumulativeShares) shares, avg cost: $\(avgCost)")
            
            // Check if this combination achieves the target gain at target price
            let gainPercent = ((targetPrice - avgCost) / avgCost) * 100.0
            AppLogger.shared.debug("  Cumulative gain at target price: \(gainPercent)%")
            
            if gainPercent >= targetGainPercent {
                // We found the minimum shares needed to achieve target gain
                let sharesToSell = cumulativeShares
                let totalGain = cumulativeShares * (targetPrice - avgCost)
                let actualCostPerShare = avgCost
                
                AppLogger.shared.debug("  ✅ Found minimum shares: \(sharesToSell) shares with avg cost $\(actualCostPerShare)")
                AppLogger.shared.debug("  Total gain: $\(totalGain)")
                
                return (sharesToSell, totalGain, actualCostPerShare)
            } else {
                AppLogger.shared.debug("  ⚠️ Not enough gain yet, continuing with unprofitable shares...")
            }
        }
        
        // If we still need more shares, add profitable shares one by one
        for (index, lot) in profitableLots.enumerated() {
            AppLogger.shared.debug("Profitable lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare)")
            
            // Try adding shares from this lot one by one
            for sharesToAdd in stride(from: 1.0, through: lot.quantity, by: 1.0) {
                let testShares = cumulativeShares + sharesToAdd
                let testCost = cumulativeCost + (sharesToAdd * lot.costPerShare)
                let testAvgCost = testCost / testShares
                let testGainPercent = ((targetPrice - testAvgCost) / testAvgCost) * 100.0
                
                AppLogger.shared.debug("  Testing with \(sharesToAdd) shares from this lot, cumulative: \(testShares) shares, avg cost: $\(testAvgCost)")
                AppLogger.shared.debug("  Test gain at target price: \(testGainPercent)%")
                
                if testGainPercent >= targetGainPercent {
                    // We found the minimum shares needed to achieve target gain
                    let sharesToSell = testShares
                    let totalGain = testShares * (targetPrice - testAvgCost)
                    let actualCostPerShare = testAvgCost
                    
                    AppLogger.shared.debug("  ✅ Found minimum shares: \(sharesToSell) shares with avg cost $\(actualCostPerShare)")
                    AppLogger.shared.debug("  Total gain: $\(totalGain)")
                    
                    return (sharesToSell, totalGain, actualCostPerShare)
                }
            }
            
            // If we get here, we need all shares from this lot
            let sharesFromLot = lot.quantity
            let costFromLot = sharesFromLot * lot.costPerShare
            
            cumulativeShares += sharesFromLot
            cumulativeCost += costFromLot
            let avgCost = cumulativeCost / cumulativeShares
            
            AppLogger.shared.debug("  Adding all \(sharesFromLot) shares, cumulative: \(cumulativeShares) shares, avg cost: $\(avgCost)")
            
            // Check if this combination achieves the target gain at target price
            let gainPercent = ((targetPrice - avgCost) / avgCost) * 100.0
            AppLogger.shared.debug("  Cumulative gain at target price: \(gainPercent)%")
            
            if gainPercent >= targetGainPercent {
                // We found the minimum shares needed to achieve target gain
                let sharesToSell = cumulativeShares
                let totalGain = cumulativeShares * (targetPrice - avgCost)
                let actualCostPerShare = avgCost
                
                AppLogger.shared.debug("  ✅ Found minimum shares: \(sharesToSell) shares with avg cost $\(actualCostPerShare)")
                AppLogger.shared.debug("  Total gain: $\(totalGain)")
                
                return (sharesToSell, totalGain, actualCostPerShare)
            } else {
                AppLogger.shared.debug("  ⚠️ Not enough gain yet, continuing with profitable shares...")
            }
        }
        
        AppLogger.shared.debug("❌ Could not achieve target gain of \(targetGainPercent)%")
        return nil
    }
    
    /// Calculate the minimum number of shares needed from a specific lot to achieve the target gain
    private func calculateMinimumSharesFromLot(
        lot: SalesCalcPositionsRecord,
        targetGainPercent: Double,
        targetPrice: Double,
        cumulativeShares: Double,
        cumulativeCost: Double
    ) -> Double {
        // If this lot alone can achieve the target gain, calculate the minimum shares needed
        let lotGainPercent = ((targetPrice - lot.costPerShare) / lot.costPerShare) * 100.0
        
        if lotGainPercent >= targetGainPercent {
            // This lot alone can achieve the target gain
            // Calculate the minimum shares needed from this lot
            // let minShares: Double = 1.0 // Start with 1 share
            
            // Binary search to find the minimum shares needed
            var low = 1.0
            var high = lot.quantity
            
            while low <= high {
                let mid = (low + high) / 2.0
                let testShares = cumulativeShares + mid
                let testCost = cumulativeCost + (mid * lot.costPerShare)
                let testAvgCost = testCost / testShares
                let testGainPercent = ((targetPrice - testAvgCost) / testAvgCost) * 100.0
                
                if testGainPercent >= targetGainPercent {
                    // We can achieve the target with this many shares, try fewer
                    high = mid - 1.0
                } else {
                    // We need more shares
                    low = mid + 1.0
                }
            }
            
            return low
        } else {
            // This lot alone cannot achieve the target gain
            // We need all shares from this lot plus some from previous lots
            return lot.quantity
        }
    }
    
    /// Calculates the minimum shares needed to achieve a specific profit percentage on the remaining position
    /// - Parameters:
    ///   - targetProfitPercent: The minimum profit percentage required on the remaining position
    ///   - currentPrice: The current market price
    ///   - sortedTaxLots: Tax lots sorted by cost per share (highest first for FIFO-like selling)
    /// - Returns: A tuple containing (sharesToSell, totalGain, actualCostPerShare) or nil if not possible
    private func calculateMinimumSharesForRemainingProfit(
        targetProfitPercent: Double,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord]
    ) -> (sharesToSell: Double, totalGain: Double, actualCostPerShare: Double)? {
        
        AppLogger.shared.debug("=== calculateMinimumSharesForRemainingProfit ===")
        AppLogger.shared.debug("Target profit %: \(targetProfitPercent)%")
        AppLogger.shared.debug("Current price: $\(currentPrice)")
        AppLogger.shared.debug("Tax lots count: \(sortedTaxLots.count)")
        
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        
        AppLogger.shared.debug("Total shares: \(totalShares)")
        AppLogger.shared.debug("Total cost: $\(totalCost)")
        
        var sharesToSell: Double = 0
        var totalGain: Double = 0
        var remainingShares = totalShares
        var remainingCost = totalCost
        
        for (index, lot) in sortedTaxLots.enumerated() {
            let lotGainPercent = ((currentPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            AppLogger.shared.debug("Lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare) (gain: \(lotGainPercent)%)")
            
            if lotGainPercent >= targetProfitPercent {
                // Calculate how many shares from this lot we need to sell
                let sharesFromLot = min(lot.quantity, remainingShares)
                let costFromLot = sharesFromLot * lot.costPerShare
                
                AppLogger.shared.debug("  Considering selling \(sharesFromLot) shares from this lot")
                AppLogger.shared.debug("  Cost from lot: $\(costFromLot)")
                
                // Check if selling these shares would achieve target profit overall
                let newRemainingShares = remainingShares - sharesFromLot
                let newRemainingCost = remainingCost - costFromLot
                let newAvgCost = newRemainingCost / newRemainingShares
                let newProfitPercent = ((currentPrice - newAvgCost) / newAvgCost) * 100.0
                
                AppLogger.shared.debug("  New remaining shares: \(newRemainingShares)")
                AppLogger.shared.debug("  New remaining cost: $\(newRemainingCost)")
                AppLogger.shared.debug("  New avg cost: $\(newAvgCost)")
                AppLogger.shared.debug("  New P/L%: \(newProfitPercent)%")
                
                if newProfitPercent >= targetProfitPercent {
                    // We can sell these shares and still maintain target profit
                    AppLogger.shared.debug("  ✅ Can sell all \(sharesFromLot) shares and maintain \(targetProfitPercent)% profit")
                    sharesToSell += sharesFromLot
                    totalGain += sharesFromLot * (currentPrice - lot.costPerShare)
                    remainingShares = newRemainingShares
                    remainingCost = newRemainingCost
                } else {
                    // Selling these shares would drop us below target profit
                    // Only sell enough to maintain target profit
                    AppLogger.shared.debug("  ⚠️ Selling all shares would drop P/L% below \(targetProfitPercent)%")
                    let targetRemainingCost = (currentPrice * remainingShares) / (1.0 + targetProfitPercent / 100.0)
                    let maxCostToSell = remainingCost - targetRemainingCost
                    let maxSharesToSell = maxCostToSell / lot.costPerShare
                    
                    AppLogger.shared.debug("  Target remaining cost for \(targetProfitPercent)% profit: $\(targetRemainingCost)")
                    AppLogger.shared.debug("  Max cost to sell: $\(maxCostToSell)")
                    AppLogger.shared.debug("  Max shares to sell: \(maxSharesToSell)")
                    
                    if maxSharesToSell > 0 {
                        let actualSharesToSell = min(maxSharesToSell, lot.quantity)
                        AppLogger.shared.debug("  ✅ Selling \(actualSharesToSell) shares to maintain \(targetProfitPercent)% profit")
                        sharesToSell += actualSharesToSell
                        totalGain += actualSharesToSell * (currentPrice - lot.costPerShare)
                    } else {
                        AppLogger.shared.debug("  ❌ Cannot sell any shares from this lot")
                    }
                    break
                }
            } else {
                AppLogger.shared.debug("  ❌ Lot gain \(lotGainPercent)% is below \(targetProfitPercent)% threshold")
            }
        }
        
        AppLogger.shared.debug("Final calculation:")
        AppLogger.shared.debug("  Shares to sell: \(sharesToSell)")
        AppLogger.shared.debug("  Total gain: $\(totalGain)")
        AppLogger.shared.debug("  Remaining shares: \(remainingShares)")
        AppLogger.shared.debug("  Remaining cost: $\(remainingCost)")
        
        guard sharesToSell > 0 else { 
            AppLogger.shared.debug("❌ No shares to sell")
            return nil 
        }
        
        // Calculate the actual cost per share for the shares being sold
        var totalCostOfSharesSold: Double = 0
        var sharesSoldSoFar: Double = 0
        
        for lot in sortedTaxLots {
            if sharesSoldSoFar >= sharesToSell { break }
            let sharesFromThisLot = min(lot.quantity, sharesToSell - sharesSoldSoFar)
            totalCostOfSharesSold += sharesFromThisLot * lot.costPerShare
            sharesSoldSoFar += sharesFromThisLot
        }
        
        let actualCostPerShare = totalCostOfSharesSold / sharesToSell
        
        return (sharesToSell, totalGain, actualCostPerShare)
    }
} 
