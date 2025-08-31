import Foundation

/// Service responsible for calculating recommended trading orders based on market data and tax lot information
@MainActor
class OrderRecommendationService: ObservableObject {
    
    // MARK: - Configuration
    private let maxAdditionalSellOrders = 7
    
    // MARK: - Public Interface
    
    /// Calculates recommended sell orders for a given position
    /// - Parameters:
    ///   - symbol: The trading symbol
    ///   - atrValue: Average True Range value
    ///   - taxLotData: Tax lot information for the position
    ///   - sharesAvailableForTrading: Number of shares available for trading
    ///   - currentPrice: Current market price
    /// - Returns: Array of recommended sell orders
    func calculateRecommendedSellOrders(
        symbol: String,
        atrValue: Double,
        taxLotData: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        currentPrice: Double
    ) async -> [SalesCalcResultsRecord] {
        
        // Early validation
        guard !taxLotData.isEmpty, sharesAvailableForTrading > 0 else {
            return []
        }
        
        let sortedTaxLots = sortTaxLotsByCost(taxLotData)
        
        // Calculate different order types in parallel
        let orders = await withTaskGroup(of: SalesCalcResultsRecord?.self) { group in
            var results: [SalesCalcResultsRecord?] = []
            
            // Top 100 Order
            group.addTask {
                return await self.calculateTop100Order(
                    currentPrice: currentPrice,
                    sortedTaxLots: sortedTaxLots,
                    sharesAvailableForTrading: sharesAvailableForTrading
                )
            }
            
            // Min Shares Order
            group.addTask {
                return await self.calculateMinSharesFor5PercentProfit(
                    currentPrice: currentPrice,
                    sortedTaxLots: sortedTaxLots,
                    atrValue: atrValue,
                    sharesAvailableForTrading: sharesAvailableForTrading
                )
            }
            
            // Min Break Even Order
            group.addTask {
                return await self.calculateMinBreakEvenOrder(
                    currentPrice: currentPrice,
                    sortedTaxLots: sortedTaxLots,
                    atrValue: atrValue,
                    sharesAvailableForTrading: sharesAvailableForTrading
                )
            }
            
            // Collect results
            for await result in group {
                results.append(result)
            }
            
            return results
        }
        
        var recommended: [SalesCalcResultsRecord] = []
        
        // Process results and add to recommended list
        for order in orders {
            if let order = order {
                recommended.append(order)
            }
        }
        
        // Calculate additional orders if we have a min break even order
        if let minBreakEvenOrder = orders[2] {
            let additionalOrders = calculateAdditionalSellOrdersFromTaxLots(
                currentPrice: currentPrice,
                sortedTaxLots: sortedTaxLots,
                minBreakEvenOrder: minBreakEvenOrder,
                sharesAvailableForTrading: sharesAvailableForTrading,
                atrValue: atrValue
            )
            recommended.append(contentsOf: additionalOrders)
        }
        
        // Sort sell orders by number of shares in descending order
        recommended.sort { $0.shares > $1.shares }
        
        return recommended
    }
    
    /// Calculates recommended buy orders for a given position
    /// - Parameters:
    ///   - symbol: The trading symbol
    ///   - atrValue: Average True Range value
    ///   - taxLotData: Tax lot information for the position
    ///   - sharesAvailableForTrading: Number of shares available for trading
    ///   - currentPrice: Current market price
    /// - Returns: Array of recommended buy orders
    func calculateRecommendedBuyOrders(
        symbol: String,
        atrValue: Double,
        taxLotData: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        currentPrice: Double
    ) -> [BuyOrderRecord] {
        
        // Early validation
        guard !taxLotData.isEmpty else { return [] }
        
        // Calculate total shares and average cost
        let totalShares = taxLotData.reduce(0.0) { $0 + $1.quantity }
        let totalCost = taxLotData.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        
        // Only show buy orders if we have an existing position
        guard totalShares > 0 else { return [] }
        
        // Calculate target gain percent based on ATR (limited to 5% to 35%)
        let targetGainPercent = max(5.0, min(35.0, TradingConfig.atrMultiplier * atrValue))
        
        // Define the share percentages to consider
        let sharePercentages: [Double] = [1.0, 5.0, 10.0, 15.0, 25.0, 50.0]
        
        // Track unique share counts to avoid duplicates
        var uniqueShareCounts: Set<Int> = []
        var recommended: [BuyOrderRecord] = []
        
        for percentage in sharePercentages {
            let sharesToBuy: Double
            
            if percentage == 1.0 {
                sharesToBuy = 1.0
            } else {
                sharesToBuy = ceil(totalShares * percentage / 100.0)
            }
            
            let shareCount = Int(sharesToBuy)
            
            // Skip if we already have this share count
            if uniqueShareCounts.contains(shareCount) {
                continue
            }
            
            uniqueShareCounts.insert(shareCount)
            
            // Calculate target price that maintains current gain level
            guard let targetBuyPrice = calculateTargetPriceForGain(
                currentPrice: currentPrice,
                avgCostPerShare: avgCostPerShare,
                currentProfitPercent: currentProfitPercent,
                targetGainPercent: targetGainPercent,
                totalShares: totalShares,
                sharesToBuy: sharesToBuy
            ) else {
                continue
            }
            
            // Calculate entry price (1 ATR below target)
            let entryPrice = targetBuyPrice * (1.0 - atrValue / 100.0)
            
            // For buy orders, trailing stop should be above current price to trigger the order
            // Calculate trailing stop as percentage from current price to a stop level between current and target
            let stopPrice = currentPrice + (atrValue / 100.0) * currentPrice
            let trailingStopPercent = ((stopPrice - currentPrice) / currentPrice) * 100.0
            
            // Calculate order cost
            let orderCost = sharesToBuy * targetBuyPrice
            
            // Skip orders that cost more than $2000
            guard orderCost < 2000.0 else { continue }
            
            // Create the buy order
            let formattedDescription = String(
                format: "BUY %.0f %@ (%.0f%%) Target=%.2f TS=%.1f%% Gain=%.1f%% Cost=%.2f",
                sharesToBuy,
                symbol,
                percentage,
                targetBuyPrice,
                trailingStopPercent,
                targetGainPercent,
                orderCost
            )
            
            let buyOrder = BuyOrderRecord(
                shares: sharesToBuy,
                targetBuyPrice: targetBuyPrice,
                entryPrice: entryPrice,
                trailingStop: trailingStopPercent,
                targetGainPercent: targetGainPercent,
                currentGainPercent: currentProfitPercent,
                sharesToBuy: sharesToBuy,
                orderCost: orderCost,
                description: formattedDescription,
                orderType: "BUY",
                submitDate: "",
                isImmediate: false
            )
            
            recommended.append(buyOrder)
        }
        
        return recommended
    }
    
    // MARK: - Private Helper Methods
    
    private func sortTaxLotsByCost(_ taxLots: [SalesCalcPositionsRecord]) -> [SalesCalcPositionsRecord] {
        return taxLots.sorted { $0.costPerShare > $1.costPerShare }
    }
    
    private func calculateTop100Order(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double
    ) async -> SalesCalcResultsRecord? {
        
        // Early exit conditions
        guard !sortedTaxLots.isEmpty else { return nil }
        
        // Check if position has more than 100 shares total
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        guard totalShares >= 100.0 else { return nil }
        
        let finalSharesToConsider = 100.0
        
        // Calculate the cost per share for the 100 most expensive shares
        var sharesRemaining = finalSharesToConsider
        var totalCostOfTop100 = 0.0
        
        for lot in sortedTaxLots {
            if sharesRemaining <= 0 { break }
            
            let sharesFromThisLot = min(lot.quantity, sharesRemaining)
            totalCostOfTop100 += sharesFromThisLot * lot.costPerShare
            sharesRemaining -= sharesFromThisLot
        }
        
        let actualCostPerShare = totalCostOfTop100 / finalSharesToConsider
        
        // Check if the top 100 shares are profitable at current price
        let currentProfitPercent = ((currentPrice - actualCostPerShare) / actualCostPerShare) * 100.0
        let isTop100Profitable = currentProfitPercent > 0
        
        let entry: Double
        let target: Double
        let trailingStop: Double
        
        if isTop100Profitable {
            // If top 100 shares are profitable, use profit-based logic
            target = (currentPrice + actualCostPerShare) / 2.0
            entry = (currentPrice - actualCostPerShare) / 4.0 + target
            trailingStop = ((entry - target) / target) * 100.0
        } else {
            // If top 100 shares are not profitable, use ATR-based logic
            let adjustedATR = 1.0 // Simplified ATR calculation
            entry = currentPrice * (1.0 - adjustedATR / 100.0)
            target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
            trailingStop = adjustedATR
        }
        
        // Calculate exit price
        let exit = max(target * (1.0 - 2.0 * 0.2 / 100.0), actualCostPerShare)
        
        let totalGain = finalSharesToConsider * (target - actualCostPerShare)
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Create description
        let profitIndicator = isTop100Profitable ? "(Top 100)" : "(Top 100 - UNPROFITABLE)"
        let formattedDescription = String(format: "%@ SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f", 
                                          profitIndicator, finalSharesToConsider, "SYMBOL", target, trailingStop, actualCostPerShare)
        
        return SalesCalcResultsRecord(
            shares: finalSharesToConsider,
            rollingGainLoss: totalGain,
            breakEven: actualCostPerShare,
            gain: gain,
            sharesToSell: finalSharesToConsider,
            trailingStop: trailingStop,
            entry: entry,
            target: target,
            cancel: exit,
            description: formattedDescription,
            openDate: "Top100"
        )
    }
    
    private func calculateMinSharesFor5PercentProfit(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        atrValue: Double,
        sharesAvailableForTrading: Double
    ) async -> SalesCalcResultsRecord? {
        
        // Only show if position is at least 6% and at least (3.5 * ATR) profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        let minProfitPercent = max(6.0, 3.5 * min(atrValue, TradingConfig.atrMultiplier))
        
        guard currentProfitPercent >= minProfitPercent else { return nil }
        
        // Use ATR as the trailing stop amount for Min ATR orders
        let targetTrailingStop = atrValue
        
        // Calculate entry price (1 ATR below current price)
        let entry = currentPrice * (1.0 - atrValue / 100.0)
        
        // Calculate target price based on trailing stop
        let target = entry / (1.0 + targetTrailingStop / 100.0)
        
        // Use the helper function to calculate minimum shares needed to achieve 5% gain at target price
        guard let result = calculateMinimumSharesForGain(
            targetGainPercent: 5.0,
            targetPrice: target,
            sortedTaxLots: sortedTaxLots
        ) else {
            return nil
        }
        
        let sharesToSell = result.sharesToSell
        let totalGain = result.totalGain
        let actualCostPerShare = result.actualCostPerShare
        
        // Validate shares to sell
        guard sharesToSell >= 1.0 && sharesToSell <= sharesAvailableForTrading else {
            return nil
        }
        
        // Validate target is above cost per share
        guard target > actualCostPerShare else { return nil }
        
        // Calculate exit price (2 ATR below target)
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        let formattedDescription = String(format: "(Min ATR) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f", sharesToSell, "SYMBOL", target, targetTrailingStop, actualCostPerShare)
        
        return SalesCalcResultsRecord(
            shares: sharesToSell,
            rollingGainLoss: totalGain,
            breakEven: actualCostPerShare,
            gain: gain,
            sharesToSell: sharesToSell,
            trailingStop: targetTrailingStop,
            entry: entry,
            target: target,
            cancel: exit,
            description: formattedDescription,
            openDate: "MinATR"
        )
    }
    
    private func calculateMinBreakEvenOrder(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        atrValue: Double,
        sharesAvailableForTrading: Double
    ) async -> SalesCalcResultsRecord? {
        
        let adjustedATR = atrValue / 5.0
        
        // Only show if position is at least 1% profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        guard currentProfitPercent >= 1.0 else { return nil }
        
        // Check if the highest cost-per-share tax lot is profitable
        guard let highestCostLot = sortedTaxLots.first else { return nil }
        let highestCostProfitPercent = ((currentPrice - highestCostLot.costPerShare) / highestCostLot.costPerShare) * 100.0
        let isHighestCostLotProfitable = highestCostProfitPercent > 0
        
        let entry: Double
        let target: Double
        let sharesToSell: Double
        let actualCostPerShare: Double
        
        if isHighestCostLotProfitable {
            // If highest cost lot is profitable
            sharesToSell = ceil(highestCostLot.quantity * 0.5)
            actualCostPerShare = highestCostLot.costPerShare
            
            let costPerShare = actualCostPerShare
            let lastPrice = currentPrice
            
            target = (lastPrice + costPerShare) / 2.0
            entry = (lastPrice - costPerShare) / 4.0 + target
        } else {
            // Original logic: Entry = Last - 1 AATR%, Target = Entry - 2 AATR%
            entry = currentPrice * (1.0 - adjustedATR / 100.0)
            target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
            
            // Use the helper function to calculate minimum shares needed to achieve 1% gain at target price
            guard let result = calculateMinimumSharesForGain(
                targetGainPercent: 1.0,
                targetPrice: target,
                sortedTaxLots: sortedTaxLots
            ) else {
                return nil
            }
            
            sharesToSell = result.sharesToSell
            actualCostPerShare = result.actualCostPerShare
        }
        
        // Validate shares to sell
        guard sharesToSell >= 1.0 && sharesToSell <= sharesAvailableForTrading else {
            return nil
        }
        
        // Validate target is above cost per share
        guard target > actualCostPerShare else { return nil }
        
        // Calculate exit price
        let exit: Double
        if isHighestCostLotProfitable {
            let costPerShare = actualCostPerShare
            let lastPrice = currentPrice
            exit = target - (lastPrice - costPerShare) / 4.0
        } else {
            exit = max(target * (1.0 - 2.0 * adjustedATR / 100.0), actualCostPerShare)
        }
        
        let totalGain = sharesToSell * (target - actualCostPerShare)
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Calculate trailing stop value
        let trailingStopValue = isHighestCostLotProfitable ? 
            ((entry - target) / target) * 100.0 : adjustedATR
        
        let formattedDescription = String(format: "(Min BE) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                                          sharesToSell, "SYMBOL", target, trailingStopValue, actualCostPerShare)
        
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
    
    private func calculateAdditionalSellOrdersFromTaxLots(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) -> [SalesCalcResultsRecord] {
        
        var additionalOrders: [SalesCalcResultsRecord] = []
        var currentTaxLotIndex = 0
        
        // Create 1% higher trailing stop order
        if let higherTSOrder = createOnePercentHigherTrailingStopOrder(
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots,
            minBreakEvenOrder: minBreakEvenOrder,
            currentTaxLotIndex: &currentTaxLotIndex,
            sharesAvailableForTrading: sharesAvailableForTrading
        ) {
            additionalOrders.append(higherTSOrder)
        }
        
        // Create max shares sell order
        if let maxSharesOrder = createMaxSharesSellOrder(
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots,
            minBreakEvenOrder: minBreakEvenOrder,
            currentTaxLotIndex: &currentTaxLotIndex,
            sharesAvailableForTrading: sharesAvailableForTrading
        ) {
            additionalOrders.append(maxSharesOrder)
        }
        
        return additionalOrders
    }
    
    private func createOnePercentHigherTrailingStopOrder(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        currentTaxLotIndex: inout Int,
        sharesAvailableForTrading: Double
    ) -> SalesCalcResultsRecord? {
        
        // Calculate trailing stop as ATR + 1% (similar to Min ATR but with higher trailing stop)
        // Extract ATR from Min BE order (Min BE uses atrValue / 5.0, so multiply by 5 to get ATR)
        let atrValue = minBreakEvenOrder.trailingStop * 5.0
        let targetTrailingStop: Double = atrValue + 1.0
        
        // Calculate entry price (1 ATR below current price)
        let entry = currentPrice * (1.0 - atrValue / 100.0)
        
        // Calculate target price based on trailing stop
        let target = entry / (1.0 + targetTrailingStop / 100.0)
        
        // Use the helper function to calculate minimum shares needed to achieve 5% gain at target price
        guard let result = calculateMinimumSharesForGain(
            targetGainPercent: 5.0,
            targetPrice: target,
            sortedTaxLots: sortedTaxLots
        ) else {
            return nil
        }
        
        let sharesToSell = result.sharesToSell
        let actualCostPerShare = result.actualCostPerShare
        
        // Validate shares to sell
        guard sharesToSell >= 1.0 && sharesToSell <= sharesAvailableForTrading else {
            return nil
        }
        
        // Validate target is above cost per share
        guard target > actualCostPerShare else { return nil }
        
        // Calculate exit price (2 ATR below target)
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        let sellOrder = SalesCalcResultsRecord(
            shares: sharesToSell,
            rollingGainLoss: sharesToSell * (target - actualCostPerShare),
            breakEven: actualCostPerShare,
            gain: gain,
            sharesToSell: sharesToSell,
            trailingStop: targetTrailingStop,
            entry: entry,
            target: target,
            cancel: exit,
            description: String(format: "(1%% TS) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                               sharesToSell, "SYMBOL", target, targetTrailingStop, actualCostPerShare),
            openDate: "1%TS"
        )
        
        return sellOrder
    }
    
    private func createMaxSharesSellOrder(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        currentTaxLotIndex: inout Int,
        sharesAvailableForTrading: Double
    ) -> SalesCalcResultsRecord? {
        
        // Calculate remaining shares available
        let remainingShares = sharesAvailableForTrading
        guard remainingShares >= 1.0 else { return nil }
        
        // Calculate cost basis for all remaining shares
        let costBasisResult = calculateCostBasisForShares(
            sharesNeeded: remainingShares,
            startingTaxLotIndex: 0,
            sortedTaxLots: sortedTaxLots,
            cumulativeSharesUsed: 0.0
        )
        
        guard let (actualCostPerShare, sharesUsed) = costBasisResult else {
            return nil
        }
        
        // Calculate a profitable target (1% above cost per share)
        let profitableTarget = actualCostPerShare * 1.01
        
        // Calculate the trailing stop from current price to this target
        let trailingStop = ((currentPrice - profitableTarget) / currentPrice) * 100.0
        
        // Validate the trailing stop is reasonable
        guard trailingStop >= 0.5 else { return nil }
        
        // Calculate the proper target price: midway between stop price and cost per share
        let stopPrice = currentPrice * (1.0 - trailingStop / 100.0)
        let targetPrice = stopPrice + (actualCostPerShare - stopPrice) / 2.0
        
        // Calculate gain at this target
        let gainAtTarget = ((targetPrice - actualCostPerShare) / actualCostPerShare) * 100.0
        
        // Create the sell order
        let description = String(
            format: "(Max Shares) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f",
            sharesUsed,
            "SYMBOL",
            targetPrice,
            trailingStop,
            actualCostPerShare
        )
        
        let sellOrder = SalesCalcResultsRecord(
            shares: sharesUsed,
            rollingGainLoss: (targetPrice - actualCostPerShare) * sharesUsed,
            breakEven: actualCostPerShare,
            gain: gainAtTarget,
            sharesToSell: sharesUsed,
            trailingStop: trailingStop,
            entry: currentPrice * (1.0 - trailingStop / 100.0),
            target: targetPrice,
            cancel: targetPrice * 0.95,
            description: description,
            openDate: "MaxShares"
        )
        
        return sellOrder
    }
    
    private func calculateTargetPriceForGain(
        currentPrice: Double,
        avgCostPerShare: Double,
        currentProfitPercent: Double,
        targetGainPercent: Double,
        totalShares: Double,
        sharesToBuy: Double
    ) -> Double? {
        
        // Calculate total cost of current position
        let totalCost = avgCostPerShare * totalShares
        
        let targetGainRatio = 1.0 + targetGainPercent / 100.0
        let denominator = (totalShares + sharesToBuy) - sharesToBuy * targetGainRatio
        
        guard denominator > 0 else { return nil }
        
        let targetPrice = totalCost * targetGainRatio / denominator
        
        // Constrain target price to be between 5% and 30% above current price
        let minTargetPrice = currentPrice * 1.05
        let maxTargetPrice = currentPrice * 1.30
        
        let constrainedTargetPrice: Double
        if targetPrice < minTargetPrice {
            constrainedTargetPrice = minTargetPrice
        } else if targetPrice > maxTargetPrice {
            constrainedTargetPrice = maxTargetPrice
        } else {
            constrainedTargetPrice = targetPrice
        }
        
        // Check if target price is reasonable
        guard constrainedTargetPrice > 0 else { return nil }
        
        // Check if target price is within bounds (5% to 30% above current price)
        let priceRatio = constrainedTargetPrice / currentPrice
        guard priceRatio >= 1.05 && priceRatio <= 1.30 else { return nil }
        
        return constrainedTargetPrice
    }
    
    private func calculateMinimumSharesForGain(
        targetGainPercent: Double,
        targetPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord]
    ) -> (sharesToSell: Double, totalGain: Double, actualCostPerShare: Double)? {
        
        // First, separate profitable and unprofitable lots
        var profitableLots: [SalesCalcPositionsRecord] = []
        var unprofitableLots: [SalesCalcPositionsRecord] = []
        
        for lot in sortedTaxLots {
            let gainAtTarget = ((targetPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            
            if gainAtTarget > 0 {
                profitableLots.append(lot)
            } else {
                unprofitableLots.append(lot)
            }
        }
        
        // Always start with unprofitable shares first (FIFO-like selling)
        // Then add minimum profitable shares needed to achieve target gain
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        
        // First, add unprofitable shares
        for lot in unprofitableLots {
            let sharesFromLot = lot.quantity
            let costFromLot = sharesFromLot * lot.costPerShare
            
            cumulativeShares += sharesFromLot
            cumulativeCost += costFromLot
            let avgCost = cumulativeCost / cumulativeShares
            
            // Check if this combination achieves the target gain at target price
            let gainPercent = ((targetPrice - avgCost) / avgCost) * 100.0
            
            if gainPercent >= targetGainPercent {
                let sharesToSell = cumulativeShares
                let totalGain = cumulativeShares * (targetPrice - avgCost)
                let actualCostPerShare = avgCost
                
                return (sharesToSell, totalGain, actualCostPerShare)
            }
        }
        
        // If we still need more shares, add profitable shares one by one
        for lot in profitableLots {
            // Try adding shares from this lot one by one
            for sharesToAdd in stride(from: 1.0, through: lot.quantity, by: 1.0) {
                let testShares = cumulativeShares + sharesToAdd
                let testCost = cumulativeCost + (sharesToAdd * lot.costPerShare)
                let testAvgCost = testCost / testShares
                let testGainPercent = ((targetPrice - testAvgCost) / testAvgCost) * 100.0
                
                if testGainPercent >= targetGainPercent {
                    let sharesToSell = testShares
                    let totalGain = testShares * (targetPrice - testAvgCost)
                    let actualCostPerShare = testAvgCost
                    
                    return (sharesToSell, totalGain, actualCostPerShare)
                }
            }
            
            // If we get here, we need all shares from this lot
            let sharesFromLot = lot.quantity
            let costFromLot = sharesFromLot * lot.costPerShare
            
            cumulativeShares += sharesFromLot
            cumulativeCost += costFromLot
            let avgCost = cumulativeCost / cumulativeShares
            
            // Check if this combination achieves the target gain at target price
            let gainPercent = ((targetPrice - avgCost) / avgCost) * 100.0
            
            if gainPercent >= targetGainPercent {
                let sharesToSell = cumulativeShares
                let totalGain = cumulativeShares * (targetPrice - avgCost)
                let actualCostPerShare = avgCost
                
                return (sharesToSell, totalGain, actualCostPerShare)
            }
        }
        
        return nil
    }
    
    private func calculateMinimumSharesForRemainingProfit(
        targetProfitPercent: Double,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord]
    ) -> (sharesToSell: Double, totalGain: Double, actualCostPerShare: Double)? {
        
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        
        var sharesToSell: Double = 0
        var totalGain: Double = 0
        var remainingShares = totalShares
        var remainingCost = totalCost
        
        for lot in sortedTaxLots {
            let lotGainPercent = ((currentPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            
            if lotGainPercent >= targetProfitPercent {
                // Calculate how many shares from this lot we need to sell
                let sharesFromLot = min(lot.quantity, remainingShares)
                let costFromLot = sharesFromLot * lot.costPerShare
                
                // Check if selling these shares would achieve target profit overall
                let newRemainingShares = remainingShares - sharesFromLot
                let newRemainingCost = remainingCost - costFromLot
                let newAvgCost = newRemainingCost / newRemainingShares
                let newProfitPercent = ((currentPrice - newAvgCost) / newAvgCost) * 100.0
                
                if newProfitPercent >= targetProfitPercent {
                    // We can sell these shares and still maintain target profit
                    sharesToSell += sharesFromLot
                    totalGain += sharesFromLot * (currentPrice - lot.costPerShare)
                    remainingShares = newRemainingShares
                    remainingCost = newRemainingCost
                } else {
                    // Selling these shares would drop us below target profit
                    // Only sell enough to maintain target profit
                    let targetRemainingCost = (currentPrice * remainingShares) / (1.0 + targetProfitPercent / 100.0)
                    let maxCostToSell = remainingCost - targetRemainingCost
                    let maxSharesToSell = maxCostToSell / lot.costPerShare
                    
                    if maxSharesToSell > 0 {
                        let actualSharesToSell = min(maxSharesToSell, lot.quantity)
                        sharesToSell += actualSharesToSell
                        totalGain += actualSharesToSell * (currentPrice - lot.costPerShare)
                    }
                    break
                }
            }
        }
        
        guard sharesToSell > 0 else { return nil }
        
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
    
    private func calculateCostBasisForShares(
        sharesNeeded: Double,
        startingTaxLotIndex: Int,
        sortedTaxLots: [SalesCalcPositionsRecord],
        cumulativeSharesUsed: Double
    ) -> (actualCostPerShare: Double, sharesUsed: Double)? {
        
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        var sharesRemaining = sharesNeeded
        
        // Start from the highest cost tax lots (index 0) and work down
        for taxLotIndex in startingTaxLotIndex..<sortedTaxLots.count {
            let taxLot = sortedTaxLots[taxLotIndex]
            
            // Calculate how many shares are available from this tax lot
            let sharesAvailableFromLot = taxLot.quantity
            let sharesToUseFromLot = min(sharesAvailableFromLot, sharesRemaining)
            
            if sharesToUseFromLot > 0 {
                let costFromLot = sharesToUseFromLot * taxLot.costPerShare
                
                cumulativeShares += sharesToUseFromLot
                cumulativeCost += costFromLot
                let avgCost = cumulativeCost / cumulativeShares
                
                sharesRemaining -= sharesToUseFromLot
                
                if sharesRemaining <= 0 {
                    // We have enough shares
                    return (actualCostPerShare: avgCost, sharesUsed: cumulativeShares)
                }
            }
        }
        
        return nil
    }
}
