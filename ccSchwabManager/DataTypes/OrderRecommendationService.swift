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
        
        AppLogger.shared.debug("=== calculateRecommendedSellOrders ===")
        AppLogger.shared.debug("Symbol: \(symbol), ATR: \(atrValue)%, Current Price: \(currentPrice), Shares Available: \(sharesAvailableForTrading)")
        
        // Validate ATR value is reasonable (should be between 0.1% and 50%)
        guard atrValue >= 0.1 && atrValue <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid ATR value: \(atrValue)%. Expected range: 0.1% to 50%")
            return []
        }
        
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
                    symbol: symbol,
                    currentPrice: currentPrice,
                    sortedTaxLots: sortedTaxLots,
                    sharesAvailableForTrading: sharesAvailableForTrading,
                    atrValue: atrValue
                )
            }
            
            // Min Shares Order
            group.addTask {
                return await self.calculateMinSharesFor5PercentProfit(
                    symbol: symbol,
                    currentPrice: currentPrice,
                    sortedTaxLots: sortedTaxLots,
                    atrValue: atrValue,
                    sharesAvailableForTrading: sharesAvailableForTrading
                )
            }
            
            // Min Break Even Order
            group.addTask {
                return await self.calculateMinBreakEvenOrder(
                    symbol: symbol,
                    currentPrice: currentPrice,
                    sortedTaxLots: sortedTaxLots,
                    atrValue: atrValue,
                    sharesAvailableForTrading: sharesAvailableForTrading
                )
            }
            
            // Top 200 Order
            group.addTask {
                return await self.calculateTop200Order(
                    symbol: symbol,
                    currentPrice: currentPrice,
                    sortedTaxLots: sortedTaxLots,
                    sharesAvailableForTrading: sharesAvailableForTrading,
                    atrValue: atrValue
                )
            }
            
            // Top 300 Order
            group.addTask {
                return await self.calculateTop300Order(
                    symbol: symbol,
                    currentPrice: currentPrice,
                    sortedTaxLots: sortedTaxLots,
                    sharesAvailableForTrading: sharesAvailableForTrading,
                    atrValue: atrValue
                )
            }
            
            // Top 400 Order
            group.addTask {
                return await self.calculateTop400Order(
                    symbol: symbol,
                    currentPrice: currentPrice,
                    sortedTaxLots: sortedTaxLots,
                    sharesAvailableForTrading: sharesAvailableForTrading,
                    atrValue: atrValue
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
                symbol: symbol,
                currentPrice: currentPrice,
                sortedTaxLots: sortedTaxLots,
                minBreakEvenOrder: minBreakEvenOrder,
                sharesAvailableForTrading: sharesAvailableForTrading,
                atrValue: atrValue
            )
            recommended.append(contentsOf: additionalOrders)
        }
        
        // Sort sell orders by shares descending, then by trailing stop ascending
        recommended.sort { first, second in
            if first.shares != second.shares {
                return first.shares > second.shares
            }
            return first.trailingStop < second.trailingStop
        }
        
        return recommended
    }
    
    /// Calculates recommended buy orders for a given position
    /// - Parameters:
    ///   - symbol: The trading symbol
    ///   - atrValue: Average True Range value
    ///   - taxLotData: Tax lot information for the position
    ///   - sharesAvailableForTrading: Number of shares available for trading
    ///   - currentPrice: Current market price
    ///   - totalShares: Total shares from position (Quantity)
    ///   - totalCost: Total cost from position (Average Price * Quantity)
    ///   - avgCostPerShare: Average cost per share from position (Average Price)
    ///   - currentProfitPercent: Current profit percentage from position (P/L%)
    /// - Returns: Array of recommended buy orders
    func calculateRecommendedBuyOrders(
        symbol: String,
        atrValue: Double,
        taxLotData: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        currentPrice: Double,
        totalShares: Double,
        totalCost: Double,
        avgCostPerShare: Double,
        currentProfitPercent: Double
    ) -> [BuyOrderRecord] {
        
        AppLogger.shared.debug("=== calculateRecommendedBuyOrders ===")
        AppLogger.shared.debug("Symbol: \(symbol), ATR: \(atrValue)%, Current Price: \(currentPrice), Shares Available: \(sharesAvailableForTrading)")
        
        // Validate ATR value is reasonable (should be between 0.1% and 50%)
        guard atrValue >= 0.1 && atrValue <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid ATR value: \(atrValue)%. Expected range: 0.1% to 50%")
            return []
        }

        // Early validation
        guard !taxLotData.isEmpty else { return [] }

        

        // Use values from position object (passed from higher levels, same source as DetailsTab)
        // totalShares, totalCost, avgCostPerShare, currentProfitPercent are now parameters

        // the currentProfitPercent does not seem to match the value from the call to calculatePLPercent
        /** remove */
        AppLogger.shared.info( "symbol: \(symbol), atrValue: \(atrValue)%, sharesAvailableForTrading: \(sharesAvailableForTrading), currentPrice: \(currentPrice), avgCostPerShare: \(avgCostPerShare), currentProfitPercent: \(currentProfitPercent)%  " )
        /** remove */

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
            
            // For buy orders, we need Target > Stop Price > Current Price
            // Calculate trailing stop as 2x ATR above current price, also > 1% and <= 15%
            let trailingStopPercent = max( 1, min( 15, atrValue * 2.0 ) )  // 2x ATR as per user preference
            let stopPrice = currentPrice * (1.0 + trailingStopPercent / 100.0)
            
            // Calculate entry price (1 ATR below target)
            let entryPrice = targetBuyPrice * (1.0 - atrValue / 100.0)
            
            // Ensure target price is above stop price for logical buy order
            let minTargetPrice = stopPrice * 1.02  // Target must be at least 2% above stop price
            let finalTargetPrice = max(targetBuyPrice, minTargetPrice)
            
            AppLogger.shared.debug("  Buy order calculation: ATR=\(atrValue)%, trailingStopPercent=\(trailingStopPercent)%")
            
            // Calculate order cost using final target price
            let orderCost = sharesToBuy * finalTargetPrice
            
            // Skip orders that cost more than $2000
            guard orderCost < 2000.0 else { continue }
            
            // Create the buy order
            let formattedDescription = String(
                format: "BUY %.0f %@ (%.0f%%) Target=%.2f TS=%.1f%% Gain=%.1f%% Cost=%.2f",
                sharesToBuy,
                symbol,
                percentage,
                finalTargetPrice,
                trailingStopPercent,
                targetGainPercent,
                orderCost
            )
            
            AppLogger.shared.debug("  Creating buy order: trailingStop=\(trailingStopPercent)%, shares=\(sharesToBuy), target=\(finalTargetPrice)")
            
            // Final validation of trailing stop value
            guard trailingStopPercent >= 0.1 && trailingStopPercent <= 50.0 else {
                AppLogger.shared.error("⚠️ Invalid trailing stop value in buy order: \(trailingStopPercent)%")
                continue
            }
            
            let buyOrder = BuyOrderRecord(
                shares: sharesToBuy,
                targetBuyPrice: finalTargetPrice,
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
        
        // Add additional buy order for securities trading under $350
        if currentPrice < 350.0 {
            let additionalBuyOrder = createAdditionalBuyOrderForLowPriceSecurity(
                symbol: symbol,
                currentPrice: currentPrice,
                atrValue: atrValue,
                targetGainPercent: targetGainPercent
            )
            if let additionalOrder = additionalBuyOrder {
                recommended.append(additionalOrder)
            }
        }
        
        // Add special 1-share buy with trailing stop = 5% + ATR%
        if let oneShareOrder = createOneShareBuyOrderWithFivePlusATRTrail(
            symbol: symbol,
            currentPrice: currentPrice,
            atrValue: atrValue,
            targetGainPercent: targetGainPercent
        ) {
            recommended.append(oneShareOrder)
        }
        
        // Add special 5% DAY buy with 0.95% trail of current holdings
        do {
            let specialPercentage: Double = 5.0
            let sharesToBuy = ceil(totalShares * specialPercentage / 100.0)
            let shareCount = Int(sharesToBuy)
            if shareCount >= 1 {
                // Trail fixed at 0.95%
                let trailingStopPercent = 0.95
                // Limit (target) set to exactly 2% above the last price
                let finalTargetPrice = currentPrice * 1.02
                let entryPrice = finalTargetPrice * (1.0 - atrValue / 100.0)

                let orderCost = sharesToBuy * finalTargetPrice
                if orderCost < 2000.0 {
                    let formattedDescription = String(
                        format: "BUY %.0f %@ (5%% DAY) Target=%.2f TS=%.2f%% Gain=%.1f%% Cost=%.2f",
                        sharesToBuy,
                        symbol,
                        finalTargetPrice,
                        trailingStopPercent,
                        targetGainPercent,
                        orderCost
                    )

                    let specialBuy = BuyOrderRecord(
                        shares: sharesToBuy,
                        targetBuyPrice: finalTargetPrice,
                        entryPrice: entryPrice,
                        trailingStop: trailingStopPercent,
                        targetGainPercent: targetGainPercent,
                        currentGainPercent: currentProfitPercent,
                        sharesToBuy: sharesToBuy,
                        orderCost: orderCost,
                        description: formattedDescription,
                        orderType: "BUY",
                        submitDate: "",
                        isImmediate: false,
                        preferDayDuration: true
                    )

                    recommended.append(specialBuy)
                }
            }
        }


        AppLogger.shared.debug("    symbol=\(symbol), currentPrice=\(currentPrice), atrValue=\(atrValue), targetGainPercent=\(targetGainPercent), currentProfitPercent=\(currentProfitPercent)")

        // Add special 1-share "when profitable" buy for positions at a loss
        // Trail = abs(P/L%) + 3*ATR%
        if currentProfitPercent < 0 {
            if let whenProfitableOrder = createWhenProfitableBuyOrderForLossPosition(
                symbol: symbol,
                currentPrice: currentPrice,
                atrValue: atrValue,
                targetGainPercent: targetGainPercent,
                currentProfitPercent: currentProfitPercent
            ) {
                AppLogger.shared.debug("  whenProfitableOrder=\(whenProfitableOrder)")
                recommended.append(whenProfitableOrder)
            }
        }

        // Sort buy orders by shares ascending, then by trailing stop descending
        recommended.sort { first, second in
            if first.shares != second.shares {
                return first.shares < second.shares
            }
            return first.trailingStop > second.trailingStop
        }
        
        return recommended
    }
    
    // MARK: - Private Helper Methods
    
    private func sortTaxLotsByCost(_ taxLots: [SalesCalcPositionsRecord]) -> [SalesCalcPositionsRecord] {
        return taxLots.sorted { $0.costPerShare > $1.costPerShare }
    }
    
    private func calculateTop100Order(
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) async -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("  Top 100 order: ATR=\(atrValue)%")
        
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
        AppLogger.shared.debug("  Top 100 cost calculation: totalCost=\(totalCostOfTop100), shares=\(finalSharesToConsider), costPerShare=\(actualCostPerShare)")
        
        // Check if the top 100 shares are profitable at current price
        let currentProfitPercent = ((currentPrice - actualCostPerShare) / actualCostPerShare) * 100.0
        let isTop100Profitable = currentProfitPercent > 0
        AppLogger.shared.debug("  Profit check: currentProfit=\(currentProfitPercent)%, isProfitable=\(isTop100Profitable)")
        
        let entry: Double
        let target: Double
        let trailingStop: Double
        
        if isTop100Profitable {
            // If top 100 shares are profitable, use profit-based logic
            target = (currentPrice + actualCostPerShare) / 2.0
            entry = (currentPrice - actualCostPerShare) / 4.0 + target
            trailingStop = ((entry - target) / target) * 100.0
            AppLogger.shared.debug("  Top 100 profitable: entry=\(entry), target=\(target), trailingStop=\(trailingStop)%")
        } else {
            // If top 100 shares are not profitable, use ATR-based logic
            entry = currentPrice * (1.0 - atrValue / 100.0)
            target = entry * (1.0 - 2.0 * atrValue / 100.0)
            trailingStop = atrValue
            AppLogger.shared.debug("  Top 100 unprofitable: entry=\(entry), target=\(target), trailingStop=\(trailingStop)%")
        }
        
        // Calculate exit price
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let totalGain = finalSharesToConsider * (target - actualCostPerShare)
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Create description
        let profitIndicator = isTop100Profitable ? "(Top 100)" : "(Top 100 - UNPROFITABLE)"
        let formattedDescription = String(format: "%@ SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f", 
                                          profitIndicator, Int(finalSharesToConsider), symbol, target, trailingStop, actualCostPerShare)
        
        // Final validation of trailing stop value
        guard trailingStop >= 0.1 && trailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in Top 100 order: \(trailingStop)%")
            return nil
        }
        
        AppLogger.shared.debug("  Creating Top 100 order: trailingStop=\(trailingStop)%, shares=\(finalSharesToConsider), target=\(target)")
        
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
    
    private func calculateTop200Order(
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) async -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("  Top 200 order: ATR=\(atrValue)%")
        
        // Early exit conditions
        guard !sortedTaxLots.isEmpty else { return nil }
        
        // Check if position has at least 200 shares total (based on holdings summary)
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        guard totalShares >= 200.0 else { return nil }
        
        let finalSharesToConsider = 200.0
        
        // Calculate the cost per share for the 200 most expensive shares
        var sharesRemaining = finalSharesToConsider
        var totalCostOfTop200 = 0.0
        
        for lot in sortedTaxLots {
            if sharesRemaining <= 0 { break }
            
            let sharesFromThisLot = min(lot.quantity, sharesRemaining)
            totalCostOfTop200 += sharesFromThisLot * lot.costPerShare
            sharesRemaining -= sharesFromThisLot
        }
        
        let actualCostPerShare = totalCostOfTop200 / finalSharesToConsider
        AppLogger.shared.debug("  Top 200 cost calculation: totalCost=\(totalCostOfTop200), shares=\(finalSharesToConsider), costPerShare=\(actualCostPerShare)")
        
        // Determine profitability at current price (but still show even if unprofitable)
        let currentProfitPercent = ((currentPrice - actualCostPerShare) / actualCostPerShare) * 100.0
        let isTop200Profitable = currentProfitPercent > 0
        AppLogger.shared.debug("  Profit check (Top 200): currentProfit=\(currentProfitPercent)%, isProfitable=\(isTop200Profitable)")
        
        // Use same structure as Top 100 for targets and stops
        let entry: Double
        let target: Double
        let trailingStop: Double
        
        if isTop200Profitable {
            target = (currentPrice + actualCostPerShare) / 2.0
            entry = (currentPrice - actualCostPerShare) / 4.0 + target
            trailingStop = ((entry - target) / target) * 100.0
            AppLogger.shared.debug("  Top 200 profitable: entry=\(entry), target=\(target), trailingStop=\(trailingStop)%")
        } else {
            // ATR-based logic when not profitable
            entry = currentPrice * (1.0 - atrValue / 100.0)
            target = entry * (1.0 - 2.0 * atrValue / 100.0)
            trailingStop = atrValue
            AppLogger.shared.debug("  Top 200 unprofitable: entry=\(entry), target=\(target), trailingStop=\(trailingStop)%")
        }
        
        // Calculate exit price
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let totalGain = finalSharesToConsider * (target - actualCostPerShare)
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Create description
        let profitIndicator = isTop200Profitable ? "(Top 200)" : "(Top 200 - UNPROFITABLE)"
        let formattedDescription = String(format: "%@ SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f", 
                                          profitIndicator, Int(finalSharesToConsider), symbol, target, trailingStop, actualCostPerShare)
        
        // Final validation of trailing stop value
        guard trailingStop >= 0.1 && trailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in Top 200 order: \(trailingStop)%")
            return nil
        }
        
        AppLogger.shared.debug("  Creating Top 200 order: trailingStop=\(trailingStop)%, shares=\(finalSharesToConsider), target=\(target)")
        
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
            openDate: "Top200"
        )
    }

    private func calculateTop300Order(
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) async -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("  Top 300 order: ATR=\(atrValue)%")
        
        guard !sortedTaxLots.isEmpty else { return nil }
        
        // Check if position has at least 300 shares total
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        guard totalShares >= 300.0 else { return nil }
        
        let finalSharesToConsider = 300.0
        
        // Calculate the cost per share for the 300 most expensive shares
        var sharesRemaining = finalSharesToConsider
        var totalCostOfTop300 = 0.0
        
        for lot in sortedTaxLots {
            if sharesRemaining <= 0 { break }
            let sharesFromThisLot = min(lot.quantity, sharesRemaining)
            totalCostOfTop300 += sharesFromThisLot * lot.costPerShare
            sharesRemaining -= sharesFromThisLot
        }
        
        let actualCostPerShare = totalCostOfTop300 / finalSharesToConsider
        AppLogger.shared.debug("  Top 300 cost calculation: totalCost=\(totalCostOfTop300), shares=\(finalSharesToConsider), costPerShare=\(actualCostPerShare)")
        
        let currentProfitPercent = ((currentPrice - actualCostPerShare) / actualCostPerShare) * 100.0
        let isTop300Profitable = currentProfitPercent > 0
        AppLogger.shared.debug("  Profit check (Top 300): currentProfit=\(currentProfitPercent)%, isProfitable=\(isTop300Profitable)")
        
        let entry: Double
        let target: Double
        let trailingStop: Double
        
        if isTop300Profitable {
            target = (currentPrice + actualCostPerShare) / 2.0
            entry = (currentPrice - actualCostPerShare) / 4.0 + target
            trailingStop = ((entry - target) / target) * 100.0
            AppLogger.shared.debug("  Top 300 profitable: entry=\(entry), target=\(target), trailingStop=\(trailingStop)%")
        } else {
            entry = currentPrice * (1.0 - atrValue / 100.0)
            target = entry * (1.0 - 2.0 * atrValue / 100.0)
            trailingStop = atrValue
            AppLogger.shared.debug("  Top 300 unprofitable: entry=\(entry), target=\(target), trailingStop=\(trailingStop)%")
        }
        
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let totalGain = finalSharesToConsider * (target - actualCostPerShare)
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        let profitIndicator = isTop300Profitable ? "(Top 300)" : "(Top 300 - UNPROFITABLE)"
        let formattedDescription = String(format: "%@ SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                                          profitIndicator, Int(finalSharesToConsider), symbol, target, trailingStop, actualCostPerShare)
        
        guard trailingStop >= 0.1 && trailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in Top 300 order: \(trailingStop)%")
            return nil
        }
        
        AppLogger.shared.debug("  Creating Top 300 order: trailingStop=\(trailingStop)%, shares=\(finalSharesToConsider), target=\(target)")
        
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
            openDate: "Top300"
        )
    }

    private func calculateTop400Order(
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) async -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("  Top 400 order: ATR=\(atrValue)%")
        
        guard !sortedTaxLots.isEmpty else { return nil }
        
        // Check if position has at least 400 shares total
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        guard totalShares >= 400.0 else { return nil }
        
        let finalSharesToConsider = 400.0
        
        // Calculate the cost per share for the 400 most expensive shares
        var sharesRemaining = finalSharesToConsider
        var totalCostOfTop400 = 0.0
        
        for lot in sortedTaxLots {
            if sharesRemaining <= 0 { break }
            let sharesFromThisLot = min(lot.quantity, sharesRemaining)
            totalCostOfTop400 += sharesFromThisLot * lot.costPerShare
            sharesRemaining -= sharesFromThisLot
        }
        
        let actualCostPerShare = totalCostOfTop400 / finalSharesToConsider
        AppLogger.shared.debug("  Top 400 cost calculation: totalCost=\(totalCostOfTop400), shares=\(finalSharesToConsider), costPerShare=\(actualCostPerShare)")
        
        let currentProfitPercent = ((currentPrice - actualCostPerShare) / actualCostPerShare) * 100.0
        let isTop400Profitable = currentProfitPercent > 0
        AppLogger.shared.debug("  Profit check (Top 400): currentProfit=\(currentProfitPercent)%, isProfitable=\(isTop400Profitable)")
        
        let entry: Double
        let target: Double
        let trailingStop: Double
        
        if isTop400Profitable {
            target = (currentPrice + actualCostPerShare) / 2.0
            entry = (currentPrice - actualCostPerShare) / 4.0 + target
            trailingStop = ((entry - target) / target) * 100.0
            AppLogger.shared.debug("  Top 400 profitable: entry=\(entry), target=\(target), trailingStop=\(trailingStop)%")
        } else {
            entry = currentPrice * (1.0 - atrValue / 100.0)
            target = entry * (1.0 - 2.0 * atrValue / 100.0)
            trailingStop = atrValue
            AppLogger.shared.debug("  Top 400 unprofitable: entry=\(entry), target=\(target), trailingStop=\(trailingStop)%")
        }
        
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let totalGain = finalSharesToConsider * (target - actualCostPerShare)
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        let profitIndicator = isTop400Profitable ? "(Top 400)" : "(Top 400 - UNPROFITABLE)"
        let formattedDescription = String(format: "%@ SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                                          profitIndicator, Int(finalSharesToConsider), symbol, target, trailingStop, actualCostPerShare)
        
        guard trailingStop >= 0.1 && trailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in Top 400 order: \(trailingStop)%")
            return nil
        }
        
        AppLogger.shared.debug("  Creating Top 400 order: trailingStop=\(trailingStop)%, shares=\(finalSharesToConsider), target=\(target)")
        
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
            openDate: "Top400"
        )
    }
    
    private func calculateMinSharesFor5PercentProfit(
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        atrValue: Double,
        sharesAvailableForTrading: Double
    ) async -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("  Min Shares order: ATR=\(atrValue)%")
        
        // Only show if position is at least 6% and at least (3.5 * ATR) profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        let minProfitPercent = max(6.0, 3.5 * min(atrValue, TradingConfig.atrMultiplier))
        
        AppLogger.shared.debug("  Profit check: currentProfit=\(currentProfitPercent)%, minRequired=\(minProfitPercent)%")
        
        guard currentProfitPercent >= minProfitPercent else { return nil }
        
        // Use 1 * ATR as the trailing stop amount for Min ATR orders
        let targetTrailingStop = atrValue
        AppLogger.shared.debug("  Min ATR order: ATR=\(atrValue)%, targetTrailingStop=\(targetTrailingStop)%")
        
        // Calculate stop price (1 * ATR below current price)
        let stopPrice = currentPrice * (1.0 - targetTrailingStop / 100.0)
        
        // Use the helper function to calculate minimum shares needed to achieve 5% gain
        // We'll use a temporary target price for the calculation, then adjust it based on the new logic
        let tempTarget = stopPrice * 1.01 // Temporary target for calculation
        guard let result = calculateMinimumSharesForGain(
            targetGainPercent: 5.0,
            targetPrice: tempTarget,
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
        
        // Calculate the final target price based on the new logic:
        // If cost-per-share is below 2*ATR below last price, use 2*ATR below last as limit
        // Otherwise, use midpoint between stop price and cost-per-share
        let twoATRBelowLast = currentPrice * (1.0 - 2.0 * atrValue / 100.0)
        let target: Double
        
        if actualCostPerShare < twoATRBelowLast {
            // Cost-per-share is below 2*ATR below last price
            target = twoATRBelowLast
            AppLogger.shared.debug("  Min Shares: cost below 2*ATR, target=\(target)")
        } else {
            // Cost-per-share is at or above 2*ATR below last price
            // Use midpoint between stop price and cost-per-share
            target = (stopPrice + actualCostPerShare) / 2.0
            AppLogger.shared.debug("  Min Shares: cost above 2*ATR, target=\(target)")
        }
        
        // Ensure target is never higher than last price minus trailing stop percent
        let maxTarget = currentPrice * (1.0 - targetTrailingStop / 100.0)
        let finalTarget = min(target, maxTarget)
        
        // Validate final target is above cost per share
        guard finalTarget > actualCostPerShare else { return nil }
        
        // Calculate exit price (2 ATR below final target)
        let exit = max(finalTarget * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        // Recalculate total gain with the final target
        let finalTotalGain = sharesToSell * (finalTarget - actualCostPerShare)
        let gain = actualCostPerShare > 0 ? ((finalTarget - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        let formattedDescription = String( format: "(Min ATR) SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f", 
                                                    Int(sharesToSell), symbol, finalTarget, 
                                                    targetTrailingStop, actualCostPerShare )
        
        AppLogger.shared.debug("  Creating Min ATR order: trailingStop=\(targetTrailingStop)%, shares=\(sharesToSell), target=\(finalTarget)")
        
        // Final validation of trailing stop value
        guard targetTrailingStop >= 0.1 && targetTrailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in Min ATR order: \(targetTrailingStop)%")
            return nil
        }
        
        return SalesCalcResultsRecord(
            shares: sharesToSell,
            rollingGainLoss: finalTotalGain,
            breakEven: actualCostPerShare,
            gain: gain,
            sharesToSell: sharesToSell,
            trailingStop: targetTrailingStop,
            entry: stopPrice,
            target: finalTarget,
            cancel: exit,
            description: formattedDescription,
            openDate: "MinATR"
        )
    }
    
    private func calculateMinBreakEvenOrder(
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        atrValue: Double,
        sharesAvailableForTrading: Double
    ) async -> SalesCalcResultsRecord? {
        
        let adjustedATR = atrValue / 5.0
        AppLogger.shared.debug("  Min Break Even order: ATR=\(atrValue)%, adjustedATR=\(adjustedATR)%")
        
        // Only show if position is at least 1% profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        AppLogger.shared.debug("  Profit check: currentProfit=\(currentProfitPercent)%, minRequired=1.0%")
        guard currentProfitPercent >= 1.0 else { return nil }
        
        // Check if the highest cost-per-share tax lot is profitable
        guard let highestCostLot = sortedTaxLots.first else { return nil }
        let highestCostProfitPercent = ((currentPrice - highestCostLot.costPerShare) / highestCostLot.costPerShare) * 100.0
        let isHighestCostLotProfitable = highestCostProfitPercent > 0
        AppLogger.shared.debug("  Highest cost lot: costPerShare=\(highestCostLot.costPerShare), profitPercent=\(highestCostProfitPercent)%, isProfitable=\(isHighestCostLotProfitable)")
        
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
            AppLogger.shared.debug("  Min BE profitable: entry=\(entry), target=\(target)")
        } else {
            // Original logic: Entry = Last - 1 AATR%, Target = Entry - 2 AATR%
            entry = currentPrice * (1.0 - adjustedATR / 100.0)
            target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
            AppLogger.shared.debug("  Min BE unprofitable: entry=\(entry), target=\(target)")
            
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
        
        // Calculate trailing stop value - always use ATR-based values for consistency
        let trailingStopValue = adjustedATR
        
        let formattedDescription = String(format: "(Min BE) SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                                          Int(sharesToSell), symbol, target, trailingStopValue, actualCostPerShare)
        
        // Final validation of trailing stop value
        guard trailingStopValue >= 0.1 && trailingStopValue <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in Min Break Even order: \(trailingStopValue)%")
            return nil
        }
        
        AppLogger.shared.debug("  Creating Min Break Even order: trailingStop=\(trailingStopValue)%, shares=\(sharesToSell), target=\(target)")
        
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
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) -> [SalesCalcResultsRecord] {
        
        AppLogger.shared.debug("  Additional sell orders: ATR=\(atrValue)%")
        
        var additionalOrders: [SalesCalcResultsRecord] = []
        var currentTaxLotIndex = 0
        
        // Create 1% higher trailing stop order
        if let higherTSOrder = createOnePercentHigherTrailingStopOrder(
            symbol: symbol,
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots,
            minBreakEvenOrder: minBreakEvenOrder,
            currentTaxLotIndex: &currentTaxLotIndex,
            sharesAvailableForTrading: sharesAvailableForTrading,
            atrValue: atrValue
        ) {
            additionalOrders.append(higherTSOrder)
        }
        
        // Create 1.5*ATR sell order
        if let onePointFiveATROrder = createOnePointFiveATRSellOrder(
            symbol: symbol,
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots,
            minBreakEvenOrder: minBreakEvenOrder,
            currentTaxLotIndex: &currentTaxLotIndex,
            sharesAvailableForTrading: sharesAvailableForTrading,
            atrValue: atrValue
        ) {
            additionalOrders.append(onePointFiveATROrder)
        }
        
        // Create 2*ATR sell order
        if let twoATROrder = createTwoATRSellOrder(
            symbol: symbol,
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots,
            minBreakEvenOrder: minBreakEvenOrder,
            currentTaxLotIndex: &currentTaxLotIndex,
            sharesAvailableForTrading: sharesAvailableForTrading,
            atrValue: atrValue
        ) {
            additionalOrders.append(twoATROrder)
        }
        
        // Create 3*ATR sell order (larger gap)
        if let threeATROrder = createThreeATRSellOrder(
            symbol: symbol,
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots,
            minBreakEvenOrder: minBreakEvenOrder,
            currentTaxLotIndex: &currentTaxLotIndex,
            sharesAvailableForTrading: sharesAvailableForTrading,
            atrValue: atrValue
        ) {
            additionalOrders.append(threeATROrder)
        }
	        
	        // Create 4*ATR sell order (even larger gap)
	        if let fourATROrder = createFourATRSellOrder(
	            symbol: symbol,
	            currentPrice: currentPrice,
	            sortedTaxLots: sortedTaxLots,
	            minBreakEvenOrder: minBreakEvenOrder,
	            currentTaxLotIndex: &currentTaxLotIndex,
	            sharesAvailableForTrading: sharesAvailableForTrading,
	            atrValue: atrValue
	        ) {
	            additionalOrders.append(fourATROrder)
	        }
	        
	        // Create 5*ATR sell order (largest gap)
	        if let fiveATROrder = createFiveATRSellOrder(
	            symbol: symbol,
	            currentPrice: currentPrice,
	            sortedTaxLots: sortedTaxLots,
	            minBreakEvenOrder: minBreakEvenOrder,
	            currentTaxLotIndex: &currentTaxLotIndex,
	            sharesAvailableForTrading: sharesAvailableForTrading,
	            atrValue: atrValue
	        ) {
	            additionalOrders.append(fiveATROrder)
	        }
        
        // Create max shares sell order
        if let maxSharesOrder = createMaxSharesSellOrder(
            symbol: symbol,
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
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        currentTaxLotIndex: inout Int,
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("  Creating 1% higher trailing stop order: ATR=\(atrValue)%, minBreakEven trailingStop=\(minBreakEvenOrder.trailingStop)%")
        
        // Calculate trailing stop as ATR + 1% (similar to Min ATR but with higher trailing stop)
        let targetTrailingStop: Double = atrValue + 1.0
        AppLogger.shared.debug("  Target trailing stop calculation: ATR + 1% = \(atrValue)% + 1% = \(targetTrailingStop)%")
        
        // Calculate entry price (1 ATR below current price)
        let entry = currentPrice * (1.0 - atrValue / 100.0)
        AppLogger.shared.debug("  Entry calculation: currentPrice=\(currentPrice), ATR=\(atrValue)%, entry=\(entry)")
        
        // Calculate target price based on trailing stop
        let target = entry / (1.0 + targetTrailingStop / 100.0)
        AppLogger.shared.debug("  Target calculation: entry=\(entry), targetTrailingStop=\(targetTrailingStop)%, target=\(target)")
        
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
        AppLogger.shared.debug("  Shares calculation: sharesToSell=\(sharesToSell), actualCostPerShare=\(actualCostPerShare)")
        
        // Validate shares to sell
        guard sharesToSell >= 1.0 && sharesToSell <= sharesAvailableForTrading else {
            return nil
        }
        
        // Validate target is above cost per share
        guard target > actualCostPerShare else { return nil }
        
        // Calculate exit price (2 ATR below target)
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Final validation of trailing stop value
        guard targetTrailingStop >= 0.1 && targetTrailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in 1% higher trailing stop order: \(targetTrailingStop)%")
            return nil
        }
        
        AppLogger.shared.debug("  Creating 1% higher trailing stop order: trailingStop=\(targetTrailingStop)%, shares=\(sharesToSell), target=\(target)")
        
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
            description: String(format: "(1%% TS) SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                               Int(sharesToSell), symbol, target, targetTrailingStop, actualCostPerShare),
            openDate: "1%TS"
        )
        
        return sellOrder
    }
    
    private func createOnePointFiveATRSellOrder(
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        currentTaxLotIndex: inout Int,
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("  Creating 1.5*ATR sell order: ATR=\(atrValue)%, trailingStop=\(atrValue * 1.5)%")
        
        // Calculate trailing stop as 1.5 * ATR
        let targetTrailingStop: Double = atrValue * 1.5
        AppLogger.shared.debug("  Target trailing stop calculation: 1.5 * ATR = 1.5 * \(atrValue)% = \(targetTrailingStop)%")
        
        // Calculate entry price (1 ATR below current price)
        let entry = currentPrice * (1.0 - atrValue / 100.0)
        AppLogger.shared.debug("  Entry calculation: currentPrice=\(currentPrice), ATR=\(atrValue)%, entry=\(entry)")
        
        // Calculate target price based on trailing stop
        let target = entry / (1.0 + targetTrailingStop / 100.0)
        AppLogger.shared.debug("  Target calculation: entry=\(entry), targetTrailingStop=\(targetTrailingStop)%, target=\(target)")
        
        // For ATR orders, prioritize selling the most expensive shares first
        // Calculate shares needed to achieve 5% gain using highest cost shares
        guard let result = calculateSharesForATROrder(
            targetGainPercent: 5.0,
            targetPrice: target,
            sortedTaxLots: sortedTaxLots
        ) else {
            return nil
        }
        
        let sharesToSell = result.sharesToSell
        let actualCostPerShare = result.actualCostPerShare
        AppLogger.shared.debug("  Shares calculation: sharesToSell=\(sharesToSell), actualCostPerShare=\(actualCostPerShare)")
        
        // Validate shares to sell
        guard sharesToSell >= 1.0 && sharesToSell <= sharesAvailableForTrading else {
            return nil
        }
        
        // Validate target is above cost per share
        guard target > actualCostPerShare else { return nil }
        
        // Calculate exit price (2 ATR below target)
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Final validation of trailing stop value
        guard targetTrailingStop >= 0.1 && targetTrailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in 1.5*ATR order: \(targetTrailingStop)%")
            return nil
        }
        
        AppLogger.shared.debug("  Creating 1.5*ATR order: trailingStop=\(targetTrailingStop)%, shares=\(sharesToSell), target=\(target)")
        
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
            description: String(format: "(1.5*ATR) SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                               Int(sharesToSell), symbol, target, targetTrailingStop, actualCostPerShare),
            openDate: "1.5ATR"
        )
        
        return sellOrder
    }
    
    private func createTwoATRSellOrder(
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        currentTaxLotIndex: inout Int,
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("  Creating 2*ATR sell order: ATR=\(atrValue)%, trailingStop=\(atrValue * 2.0)%")
        
        // Calculate trailing stop as 2 * ATR
        let targetTrailingStop: Double = atrValue * 2.0
        AppLogger.shared.debug("  Target trailing stop calculation: 2 * ATR = 2 * \(atrValue)% = \(targetTrailingStop)%")
        
        // Calculate entry price (1 ATR below current price)
        let entry = currentPrice * (1.0 - atrValue / 100.0)
        AppLogger.shared.debug("  Entry calculation: currentPrice=\(currentPrice), ATR=\(atrValue)%, entry=\(entry)")
        
        // Calculate target price based on trailing stop
        let target = entry / (1.0 + targetTrailingStop / 100.0)
        AppLogger.shared.debug("  Target calculation: entry=\(entry), targetTrailingStop=\(targetTrailingStop)%, target=\(target)")
        
        // For ATR orders, prioritize selling the most expensive shares first
        // Calculate shares needed to achieve 5% gain using highest cost shares
        guard let result = calculateSharesForATROrder(
            targetGainPercent: 5.0,
            targetPrice: target,
            sortedTaxLots: sortedTaxLots
        ) else {
            return nil
        }
        
        let sharesToSell = result.sharesToSell
        let actualCostPerShare = result.actualCostPerShare
        AppLogger.shared.debug("  Shares calculation: sharesToSell=\(sharesToSell), actualCostPerShare=\(actualCostPerShare)")
        
        // Validate shares to sell
        guard sharesToSell >= 1.0 && sharesToSell <= sharesAvailableForTrading else {
            return nil
        }
        
        // Validate target is above cost per share
        guard target > actualCostPerShare else { return nil }
        
        // Calculate exit price (2 ATR below target)
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Final validation of trailing stop value
        guard targetTrailingStop >= 0.1 && targetTrailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in 2*ATR order: \(targetTrailingStop)%")
            return nil
        }
        
        AppLogger.shared.debug("  Creating 2*ATR order: trailingStop=\(targetTrailingStop)%, shares=\(sharesToSell), target=\(target)")
        
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
            description: String(format: "(2*ATR) SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                               Int(sharesToSell), symbol, target, targetTrailingStop, actualCostPerShare),
            openDate: "2ATR"
        )
        
        return sellOrder
    }
    
    private func createThreeATRSellOrder(
        symbol: String,
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        currentTaxLotIndex: inout Int,
        sharesAvailableForTrading: Double,
        atrValue: Double
    ) -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("  Creating 3*ATR sell order: ATR=\(atrValue)%, trailingStop=\(atrValue * 3.0)%")
        
        // Calculate trailing stop as 3 * ATR
        let targetTrailingStop: Double = atrValue * 3.0
        AppLogger.shared.debug("  Target trailing stop calculation: 3 * ATR = 3 * \(atrValue)% = \(targetTrailingStop)%")
        
        // Calculate entry price (1 ATR below current price)
        let entry = currentPrice * (1.0 - atrValue / 100.0)
        AppLogger.shared.debug("  Entry calculation: currentPrice=\(currentPrice), ATR=\(atrValue)%, entry=\(entry)")
        
        // Calculate target price based on trailing stop
        let target = entry / (1.0 + targetTrailingStop / 100.0)
        AppLogger.shared.debug("  Target calculation: entry=\(entry), targetTrailingStop=\(targetTrailingStop)%, target=\(target)")
        
        // For ATR orders, prioritize selling the most expensive shares first
        guard let result = calculateSharesForATROrder(
            targetGainPercent: 5.0,
            targetPrice: target,
            sortedTaxLots: sortedTaxLots
        ) else {
            return nil
        }
        
        let sharesToSell = result.sharesToSell
        let actualCostPerShare = result.actualCostPerShare
        AppLogger.shared.debug("  Shares calculation: sharesToSell=\(sharesToSell), actualCostPerShare=\(actualCostPerShare)")
        
        // Validate shares to sell
        guard sharesToSell >= 1.0 && sharesToSell <= sharesAvailableForTrading else {
            return nil
        }
        
        // Validate target is above cost per share
        guard target > actualCostPerShare else { return nil }
        
        // Calculate exit price (2 ATR below target)
        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
        
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Final validation of trailing stop value
        guard targetTrailingStop >= 0.1 && targetTrailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in 3*ATR order: \(targetTrailingStop)%")
            return nil
        }
        
        AppLogger.shared.debug("  Creating 3*ATR order: trailingStop=\(targetTrailingStop)%, shares=\(sharesToSell), target=\(target)")
        
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
            description: String(format: "(3*ATR) SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                               Int(sharesToSell), symbol, target, targetTrailingStop, actualCostPerShare),
            openDate: "3ATR"
        )
        
        return sellOrder
    }
	    
	    private func createFourATRSellOrder(
	        symbol: String,
	        currentPrice: Double,
	        sortedTaxLots: [SalesCalcPositionsRecord],
	        minBreakEvenOrder: SalesCalcResultsRecord,
	        currentTaxLotIndex: inout Int,
	        sharesAvailableForTrading: Double,
	        atrValue: Double
	    ) -> SalesCalcResultsRecord? {
	        
	        AppLogger.shared.debug("  Creating 4*ATR sell order: ATR=\(atrValue)%, trailingStop=\(atrValue * 4.0)%")
	        
	        // Calculate trailing stop as 4 * ATR
	        let targetTrailingStop: Double = atrValue * 4.0
	        AppLogger.shared.debug("  Target trailing stop calculation: 4 * ATR = 4 * \(atrValue)% = \(targetTrailingStop)%")
	        
	        // Calculate entry price (1 ATR below current price)
	        let entry = currentPrice * (1.0 - atrValue / 100.0)
	        AppLogger.shared.debug("  Entry calculation: currentPrice=\(currentPrice), ATR=\(atrValue)%, entry=\(entry)")
	        
	        // Calculate target price based on trailing stop
	        let target = entry / (1.0 + targetTrailingStop / 100.0)
	        AppLogger.shared.debug("  Target calculation: entry=\(entry), targetTrailingStop=\(targetTrailingStop)%, target=\(target)")
	        
	        // For ATR orders, prioritize selling the most expensive shares first
	        guard let result = calculateSharesForATROrder(
	            targetGainPercent: 5.0,
	            targetPrice: target,
	            sortedTaxLots: sortedTaxLots
	        ) else {
	            return nil
	        }
	        
	        let sharesToSell = result.sharesToSell
	        let actualCostPerShare = result.actualCostPerShare
	        AppLogger.shared.debug("  Shares calculation: sharesToSell=\(sharesToSell), actualCostPerShare=\(actualCostPerShare)")
	        
	        // Validate shares to sell
	        guard sharesToSell >= 1.0 && sharesToSell <= sharesAvailableForTrading else {
	            return nil
	        }
	        
	        // Validate target is above cost per share
	        guard target > actualCostPerShare else { return nil }
	        
	        // Calculate exit price (2 ATR below target)
	        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
	        
	        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
	        
	        // Final validation of trailing stop value
	        guard targetTrailingStop >= 0.1 && targetTrailingStop <= 50.0 else {
	            AppLogger.shared.error("⚠️ Invalid trailing stop value in 4*ATR order: \(targetTrailingStop)%")
	            return nil
	        }
	        
	        AppLogger.shared.debug("  Creating 4*ATR order: trailingStop=\(targetTrailingStop)%, shares=\(sharesToSell), target=\(target)")
	        
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
	            description: String(format: "(4*ATR) SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
	                               Int(sharesToSell), symbol, target, targetTrailingStop, actualCostPerShare),
	            openDate: "4ATR"
	        )
	        
	        return sellOrder
	    }
	    
	    private func createFiveATRSellOrder(
	        symbol: String,
	        currentPrice: Double,
	        sortedTaxLots: [SalesCalcPositionsRecord],
	        minBreakEvenOrder: SalesCalcResultsRecord,
	        currentTaxLotIndex: inout Int,
	        sharesAvailableForTrading: Double,
	        atrValue: Double
	    ) -> SalesCalcResultsRecord? {
	        
	        AppLogger.shared.debug("  Creating 5*ATR sell order: ATR=\(atrValue)%, trailingStop=\(atrValue * 5.0)%")
	        
	        // Calculate trailing stop as 5 * ATR
	        let targetTrailingStop: Double = atrValue * 5.0
	        AppLogger.shared.debug("  Target trailing stop calculation: 5 * ATR = 5 * \(atrValue)% = \(targetTrailingStop)%")
	        
	        // Calculate entry price (1 ATR below current price)
	        let entry = currentPrice * (1.0 - atrValue / 100.0)
	        AppLogger.shared.debug("  Entry calculation: currentPrice=\(currentPrice), ATR=\(atrValue)%, entry=\(entry)")
	        
	        // Calculate target price based on trailing stop
	        let target = entry / (1.0 + targetTrailingStop / 100.0)
	        AppLogger.shared.debug("  Target calculation: entry=\(entry), targetTrailingStop=\(targetTrailingStop)%, target=\(target)")
	        
	        // For ATR orders, prioritize selling the most expensive shares first
	        guard let result = calculateSharesForATROrder(
	            targetGainPercent: 5.0,
	            targetPrice: target,
	            sortedTaxLots: sortedTaxLots
	        ) else {
	            return nil
	        }
	        
	        let sharesToSell = result.sharesToSell
	        let actualCostPerShare = result.actualCostPerShare
	        AppLogger.shared.debug("  Shares calculation: sharesToSell=\(sharesToSell), actualCostPerShare=\(actualCostPerShare)")
	        
	        // Validate shares to sell
	        guard sharesToSell >= 1.0 && sharesToSell <= sharesAvailableForTrading else {
	            return nil
	        }
	        
	        // Validate target is above cost per share
	        guard target > actualCostPerShare else { return nil }
	        
	        // Calculate exit price (2 ATR below target)
	        let exit = max(target * (1.0 - 2.0 * atrValue / 100.0), actualCostPerShare)
	        
	        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
	        
	        // Final validation of trailing stop value
	        guard targetTrailingStop >= 0.1 && targetTrailingStop <= 50.0 else {
	            AppLogger.shared.error("⚠️ Invalid trailing stop value in 5*ATR order: \(targetTrailingStop)%")
	            return nil
	        }
	        
	        AppLogger.shared.debug("  Creating 5*ATR order: trailingStop=\(targetTrailingStop)%, shares=\(sharesToSell), target=\(target)")
	        
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
	            description: String(format: "(5*ATR) SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
	                               Int(sharesToSell), symbol, target, targetTrailingStop, actualCostPerShare),
	            openDate: "5ATR"
	        )
	        
	        return sellOrder
	    }

    private func createMaxSharesSellOrder(
        symbol: String,
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
        AppLogger.shared.debug("  Profitable target calculation: actualCostPerShare=\(actualCostPerShare), profitableTarget=\(profitableTarget)")
        
        // Calculate the trailing stop from current price to this target
        let trailingStop = ((currentPrice - profitableTarget) / currentPrice) * 100.0
        
        AppLogger.shared.debug("  Max shares order calculation: currentPrice=\(currentPrice), profitableTarget=\(profitableTarget), trailingStop=\(trailingStop)%")
        
        // Validate the trailing stop is reasonable
        guard trailingStop >= 0.1 && trailingStop <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in max shares order: \(trailingStop)%")
            return nil
        }
        
        // Calculate the proper target price: midway between stop price and cost per share
        let stopPrice = currentPrice * (1.0 - trailingStop / 100.0)
        let targetPrice = stopPrice + (actualCostPerShare - stopPrice) / 2.0
        
        // Calculate gain at this target
        let gainAtTarget = ((targetPrice - actualCostPerShare) / actualCostPerShare) * 100.0
        
        // Create the sell order
        let description = String(
            format: "(Max Shares) SELL -%d %@ Target %.2f TS %.2f%% Cost/Share %.2f",
            Int(sharesUsed),
            symbol,
            targetPrice,
            trailingStop,
            actualCostPerShare
        )
        
        AppLogger.shared.debug("  Creating max shares order: trailingStop=\(trailingStop)%, shares=\(sharesUsed), target=\(targetPrice)")
        
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
        
        // Always prioritize selling the most expensive shares first (highest-cost first)
        // Start with the highest cost shares and work down until we achieve target gain
        // Only use whole shares - truncate fractional shares
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        
        for lot in sortedTaxLots {
            // Only add whole shares from this lot (truncate fractional shares)
            let wholeSharesFromLot = floor(lot.quantity)
            
            // Skip if no whole shares available in this lot
            if wholeSharesFromLot < 1.0 {
                continue
            }
            
            // Try adding shares from this lot one by one (whole shares only)
            for sharesToAdd in stride(from: 1.0, through: wholeSharesFromLot, by: 1.0) {
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
            
            // If we get here, we need all whole shares from this lot
            let costFromLot = wholeSharesFromLot * lot.costPerShare
            
            cumulativeShares += wholeSharesFromLot
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
    
    private func calculateSharesForATROrder(
        targetGainPercent: Double,
        targetPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord]
    ) -> (sharesToSell: Double, totalGain: Double, actualCostPerShare: Double)? {
        
        // For ATR orders, prioritize selling the most expensive shares first (highest-cost first)
        // Start with the highest cost shares and work down until we achieve target gain
        // Only use whole shares - truncate fractional shares
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        
        for lot in sortedTaxLots {
            // Only add whole shares from this lot (truncate fractional shares)
            let wholeSharesFromLot = floor(lot.quantity)
            
            // Skip if no whole shares available in this lot
            if wholeSharesFromLot < 1.0 {
                continue
            }
            
            let costFromLot = wholeSharesFromLot * lot.costPerShare
            
            cumulativeShares += wholeSharesFromLot
            cumulativeCost += costFromLot
            let avgCost = cumulativeCost / cumulativeShares
            
            // Check if this combination achieves the target gain at target price
            let gainPercent = ((targetPrice - avgCost) / avgCost) * 100.0
            
            if gainPercent >= targetGainPercent {
                let sharesToSell = cumulativeShares
                let totalGain = cumulativeShares * (targetPrice - avgCost)
                let actualCostPerShare = avgCost
                
                AppLogger.shared.debug("  ATR order calculation: sharesToSell=\(sharesToSell), actualCostPerShare=\(actualCostPerShare), gainPercent=\(gainPercent)%")
                
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
        // Only use whole shares - truncate fractional shares
        for taxLotIndex in startingTaxLotIndex..<sortedTaxLots.count {
            let taxLot = sortedTaxLots[taxLotIndex]
            
            // Calculate how many whole shares are available from this tax lot
            let wholeSharesAvailableFromLot = floor(taxLot.quantity)
            let sharesToUseFromLot = min(wholeSharesAvailableFromLot, sharesRemaining)
            
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
    
    /// Creates an additional buy order for securities trading under $350
    /// - Parameters:
    ///   - symbol: The trading symbol
    ///   - currentPrice: Current market price
    ///   - atrValue: Average True Range value
    ///   - targetGainPercent: Target gain percentage
    /// - Returns: Additional buy order record or nil if not applicable
    private func createAdditionalBuyOrderForLowPriceSecurity(
        symbol: String,
        currentPrice: Double,
        atrValue: Double,
        targetGainPercent: Double
    ) -> BuyOrderRecord? {
        
        // Calculate number of shares that can be bought for $500, rounded up
        let sharesFor500 = ceil(500.0 / currentPrice)
        
        // Ensure we have at least 1 share
        guard sharesFor500 >= 1.0 else { return nil }
        
        // Calculate target price (maintains the same target gain percentage)
        let targetBuyPrice = currentPrice * (1.0 + targetGainPercent / 100.0)
        
        // Calculate trailing stop (2x ATR as per user preference)
        let trailingStopPercent = atrValue * 2.0
        let stopPrice = currentPrice * (1.0 + trailingStopPercent / 100.0)
        
        // Ensure target price is above stop price for logical buy order
        let minTargetPrice = stopPrice * 1.02  // Target must be at least 2% above stop price
        let finalTargetPrice = max(targetBuyPrice, minTargetPrice)
        
        // Calculate entry price (1 ATR below target)
        let entryPrice = finalTargetPrice * (1.0 - atrValue / 100.0)
        
        AppLogger.shared.debug("  Additional buy order: ATR=\(atrValue)%, trailingStopPercent=\(trailingStopPercent)%")
        
        // Calculate actual order cost
        let orderCost = sharesFor500 * finalTargetPrice
        
        // Create description
        let formattedDescription = String(
            format: "BUY %.0f %@ ($500) Target=%.2f TS=%.1f%% Gain=%.1f%% Cost=%.2f",
            sharesFor500,
            symbol,
            finalTargetPrice,
            trailingStopPercent,
            targetGainPercent,
            orderCost
        )
        
        AppLogger.shared.debug("  Creating additional buy order: trailingStop=\(trailingStopPercent)%, shares=\(sharesFor500), target=\(finalTargetPrice)")
        
        // Final validation of trailing stop value
        guard trailingStopPercent >= 0.1 && trailingStopPercent <= 50.0 else {
            AppLogger.shared.error("⚠️ Invalid trailing stop value in additional buy order: \(trailingStopPercent)%")
            return nil
        }
        
        let additionalBuyOrder = BuyOrderRecord(
            shares: sharesFor500,
            targetBuyPrice: finalTargetPrice,
            entryPrice: entryPrice,
            trailingStop: trailingStopPercent,
            targetGainPercent: targetGainPercent,
            currentGainPercent: 0.0, // No existing position gain for this additional order
            sharesToBuy: sharesFor500,
            orderCost: orderCost,
            description: formattedDescription,
            orderType: "BUY",
            submitDate: "",
            isImmediate: false
        )
        
        return additionalBuyOrder
    }

    private func createOneShareBuyOrderWithFivePlusATRTrail(
        symbol: String,
        currentPrice: Double,
        atrValue: Double,
        targetGainPercent: Double
    ) -> BuyOrderRecord? {
        // Fixed one share
        let sharesToBuy: Double = 1.0
        
        // Trailing stop percent = 5% + ATR%
        let trailingStopPercent = max(0.1, min(50.0, 5.0 + atrValue))
        let stopPrice = currentPrice * (1.0 + trailingStopPercent / 100.0)
        
        // Target maintains the same target gain percent, but must be at least 2% above stop
        let baseTargetPrice = currentPrice * (1.0 + targetGainPercent / 100.0)
        let minTargetPrice = stopPrice * 1.02
        let finalTargetPrice = max(baseTargetPrice, minTargetPrice)
        
        // Entry price one ATR below target
        let entryPrice = finalTargetPrice * (1.0 - atrValue / 100.0)
        
        // Order cost threshold consistent with other small buys ($2000 cap)
        let orderCost = sharesToBuy * finalTargetPrice
        guard orderCost < 2000.0 else { return nil }
        
        let formattedDescription = String(
            format: "BUY %.0f %@ (1 sh, 5%%+ATR) Target=%.2f TS=%.2f%% Gain=%.1f%% Cost=%.2f",
            sharesToBuy,
            symbol,
            finalTargetPrice,
            trailingStopPercent,
            targetGainPercent,
            orderCost
        )
        
        // Final trailing stop validation
        guard trailingStopPercent >= 0.1 && trailingStopPercent <= 50.0 else { return nil }
        
        AppLogger.shared.debug("  One-share buy: TS=\(trailingStopPercent)% (5%+ATR), target=\(finalTargetPrice)")
        
        return BuyOrderRecord(
            shares: sharesToBuy,
            targetBuyPrice: finalTargetPrice,
            entryPrice: entryPrice,
            trailingStop: trailingStopPercent,
            targetGainPercent: targetGainPercent,
            currentGainPercent: 0.0,
            sharesToBuy: sharesToBuy,
            orderCost: orderCost,
            description: formattedDescription,
            orderType: "BUY",
            submitDate: "",
            isImmediate: false
        )
    }
    
    /// Creates a "when profitable" buy order for positions currently at a loss
    /// - Parameters:
    ///   - symbol: The trading symbol
    ///   - currentPrice: Current market price
    ///   - atrValue: Average True Range value
    ///   - targetGainPercent: Target gain percentage
    ///   - currentProfitPercent: Current profit percentage (negative for loss positions)
    /// - Returns: Buy order record or nil if not applicable
    private func createWhenProfitableBuyOrderForLossPosition(
        symbol: String,
        currentPrice: Double,
        atrValue: Double,
        targetGainPercent: Double,
        currentProfitPercent: Double
    ) -> BuyOrderRecord? {
        // Only for positions at a loss
        guard currentProfitPercent < 0 else { return nil }
        
        // Fixed one share
        let sharesToBuy: Double = 1.0
        
        // Trailing stop percent = abs(P/L%) + 3 * ATR%
        // Example: -7.6% P/L + 3 * 1.67% ATR = 7.6 + 5.01 = 12.61%
        let lossPercent = abs(currentProfitPercent)
        let trailingStopPercent = max(0.1, min(50.0, lossPercent + 3.0 * atrValue))
        
        // For buy orders: current price < stop price < target price
        // Stop price is current price + trailing stop percentage
        let stopPrice = currentPrice * (1.0 + trailingStopPercent / 100.0)
        
        // Target price should be above stop price
        // Use the standard target gain percent or at least 2% above stop
        let baseTargetPrice = currentPrice * (1.0 + targetGainPercent / 100.0)
        let minTargetPrice = stopPrice * 1.02
        let finalTargetPrice = max(baseTargetPrice, minTargetPrice)
        
        // Entry price one ATR below target
        let entryPrice = finalTargetPrice * (1.0 - atrValue / 100.0)
        
        // Order cost threshold consistent with other small buys ($2000 cap)
        let orderCost = sharesToBuy * finalTargetPrice
        guard orderCost < 2000.0 else { return nil }
        
        let formattedDescription = String(
            format: "BUY %.0f %@ (When Profitable) P/L=%.1f%% Target=%.2f TS=%.2f%% Gain=%.1f%% Cost=%.2f",
            sharesToBuy,
            symbol,
            currentProfitPercent,
            finalTargetPrice,
            trailingStopPercent,
            targetGainPercent,
            orderCost
        )
        
        // Final trailing stop validation
        guard trailingStopPercent >= 0.1 && trailingStopPercent <= 50.0 else { return nil }
        
        AppLogger.shared.debug("  When Profitable buy: currentP/L=\(currentProfitPercent)%, loss=\(lossPercent)%, ATR=\(atrValue)%, TS=\(trailingStopPercent)%, target=\(finalTargetPrice)")
        
        return BuyOrderRecord(
            shares: sharesToBuy,
            targetBuyPrice: finalTargetPrice,
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
    }
}
