import SwiftUI

struct RecommendedOCOOrdersSection: View {

    let symbol: String
    let atrValue: Double
    @State private var taxLotData: [SalesCalcPositionsRecord] = []
    let sharesAvailableForTrading: Double
    let quoteData: QuoteData?
    let accountNumber: String
    
    // Configuration constants
    private let maxAdditionalSellOrders = 7
    
    @State private var selectedSellOrderIndex: Int? = nil
    @State private var selectedBuyOrderIndex: Int? = nil
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
    
    // Cache for calculated orders to avoid repeated expensive calculations
    @State private var cachedSellOrders: [SalesCalcResultsRecord] = []
    @State private var cachedBuyOrders: [BuyOrderRecord] = []
    @State private var cachedAllOrders: [(String, Any)] = []
    @State private var lastCalculatedSymbol: String = ""
    @State private var lastCalculatedDataHash: String = ""
    
    // State to hold the current orders to avoid recomputation on selection changes
    @State private var currentOrders: [(String, Any)] = []
    
    // Cache for current price to avoid repeated calculations
    @State private var cachedCurrentPrice: Double?
    @State private var cachedPriceSymbol: String = ""
    
    // Cache for sorted tax lots to avoid repeated sorting
    @State private var cachedSortedTaxLots: [SalesCalcPositionsRecord] = []
    @State private var cachedTaxLotsHash: String = ""
    
    @State private var isLoadingTaxLots = false
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage = "Loading tax lot data..."
    
    // Background task for tax lot calculation
    @State private var taxLotCalculationTask: Task<Void, Never>?
    
    private func getDataHash() -> String {
        // Create a hash of the data that affects calculations
        // Use more efficient string concatenation and avoid creating new strings on every call
        var hash = symbol
        hash += "-"
        hash += quoteData?.symbol ?? "nil"
        hash += "-"
        hash += String(format: "%.2f", atrValue)
        hash += "-"
        hash += String(format: "%.0f", sharesAvailableForTrading)
        hash += "-"
        
        // Only process tax lots if they've changed
        if taxLotData.count <= 10 { // Limit for performance
            for lot in taxLotData {
                hash += String(format: "%.0f-%.2f", lot.quantity, lot.costPerShare)
                hash += "|"
            }
        } else {
            // For large datasets, use a summary hash
            let totalShares = taxLotData.reduce(0.0) { $0 + $1.quantity }
            let avgCost = taxLotData.reduce(0.0) { $0 + $1.costBasis } / totalShares
            hash += String(format: "%.0f-%.2f", totalShares, avgCost)
        }
        
        hash += "-"
        hash += quoteData?.quote?.lastPrice?.description ?? "nil"
        return hash
    }
    
    private func getRecommendedSellOrders() async -> [SalesCalcResultsRecord] {
        // Return cached results if available
        if !cachedSellOrders.isEmpty {
            return cachedSellOrders
        }
        
        // Calculate new results
        let orders = await calculateRecommendedSellOrders()
        cachedSellOrders = orders
        return orders
    }
    
    private func getRecommendedBuyOrders() -> [BuyOrderRecord] {
        // Return cached results if available
        if !cachedBuyOrders.isEmpty {
            return cachedBuyOrders
        }
        
        // Calculate new results
        let orders = calculateRecommendedBuyOrders()
        cachedBuyOrders = orders
        return orders
    }
    
    private func getAllOrders() -> [(String, Any)] {
        // Return cached results if available
        if !cachedAllOrders.isEmpty {
            return cachedAllOrders
        }
        
        var orders: [(String, Any)] = []
        
        AppLogger.shared.debug("=== getAllOrders called ===")
        
        // Get sell orders (these are already calculated and cached)
        let sellOrders = recommendedSellOrders
        AppLogger.shared.debug("Sell orders count: \(sellOrders.count)")
        
        // Add sell orders first
        for (index, order) in sellOrders.enumerated() {
            AppLogger.shared.debug("  Adding SELL order \(index + 1): sharesToSell=\(order.sharesToSell), entry=\(order.entry), target=\(order.target), cancel=\(order.cancel)")
            orders.append(("SELL", order))
        }
        
        // Get buy orders (these are already calculated and cached)
        let buyOrders = recommendedBuyOrders
        AppLogger.shared.debug("Buy orders count: \(buyOrders.count)")
        
        // Add buy orders
        for (index, order) in buyOrders.enumerated() {
            AppLogger.shared.debug("  Adding BUY order \(index + 1): sharesToBuy=\(order.sharesToBuy), targetBuyPrice=\(order.targetBuyPrice), entryPrice=\(order.entryPrice), targetGainPercent=\(order.targetGainPercent)")
            orders.append(("BUY", order))
        }
        
        AppLogger.shared.debug("Total orders created: \(orders.count)")
        
        // Cache the result
        cachedAllOrders = orders
        return orders
    }
    
    private func calculateRecommendedSellOrders() async -> [SalesCalcResultsRecord] {
        var recommended: [SalesCalcResultsRecord] = []
        
        guard let currentPrice = getCurrentPrice() else {
            AppLogger.shared.debug("❌ No current price available for \(symbol)")
            return recommended
        }
        
        let sortedTaxLots = getSortedTaxLots()
        
        AppLogger.shared.debug("=== calculateRecommendedSellOrders ===")
        AppLogger.shared.debug("Symbol: \(symbol)")
        AppLogger.shared.debug("ATR: \(atrValue)%")
        AppLogger.shared.debug("Tax lots count: \(taxLotData.count)")
        AppLogger.shared.debug("Shares available for trading: \(sharesAvailableForTrading)")
        AppLogger.shared.debug("Current price: $\(currentPrice)")
        AppLogger.shared.debug("Sorted tax lots by cost per share (highest first): \(sortedTaxLots.count) lots")
        
        // Early exit if no tax lots or insufficient shares
        guard !sortedTaxLots.isEmpty, sharesAvailableForTrading > 0 else {
            AppLogger.shared.debug("❌ No tax lots or insufficient shares available")
            return recommended
        }
        
        // Use TaskGroup for parallel processing of different order types
        let orders = await withTaskGroup(of: SalesCalcResultsRecord?.self) { group in
            var results: [SalesCalcResultsRecord?] = []
            
            // Add Top 100 Order calculation
            group.addTask {
                return await self.calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
            }
            
            // Add Min Shares Order calculation
            group.addTask {
                return await self.calculateMinSharesFor5PercentProfit(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
            }
            
            // Add Min Break Even Order calculation
            group.addTask {
                return await self.calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
            }
            
            // Collect results
            for await result in group {
                results.append(result)
            }
            
            return results
        }
        
        // Process results and add to recommended list
        for order in orders {
            if let order = order {
                recommended.append(order)
            }
        }
        
        // Calculate additional orders only if we have a min break even order
        if let minBreakEvenOrder = orders[2] { // Index 2 is Min Break Even Order
            let additionalOrders = calculateAdditionalSellOrdersFromTaxLots(
                currentPrice: currentPrice,
                sortedTaxLots: sortedTaxLots,
                minBreakEvenOrder: minBreakEvenOrder
            )
            recommended.append(contentsOf: additionalOrders)
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
        
        AppLogger.shared.debug("=== calculateRecommendedBuyOrders (NEW LOGIC) ===")
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
        
        // Calculate target gain percent based on ATR (limited to 5% to 35%)
        let targetGainPercent = max(5.0, min(35.0, TradingConfig.atrMultiplier * atrValue))
        AppLogger.shared.debug("Target gain percent: \(targetGainPercent)% (ATR: \(atrValue)%, limited to 5%-35%)")
        
        // Define the share percentages to consider
        let sharePercentages: [Double] = [1.0, 5.0, 10.0, 15.0, 25.0, 50.0] // 1 share, then percentages
        
        // Track unique share counts to avoid duplicates
        var uniqueShareCounts: Set<Int> = []
        
        for percentage in sharePercentages {
            let sharesToBuy: Double
            
            if percentage == 1.0 {
                // Single share
                sharesToBuy = 1.0
            } else {
                // Calculate as percentage of current shares
                sharesToBuy = ceil(totalShares * percentage / 100.0)
            }
            
            // Convert to integer for uniqueness check
            let shareCount = Int(sharesToBuy)
            
            // Skip if we already have this share count
            if uniqueShareCounts.contains(shareCount) {
                AppLogger.shared.debug("⚠️ Skipping \(percentage)% (\(sharesToBuy) shares) - duplicate share count")
                continue
            }
            
            uniqueShareCounts.insert(shareCount)
            
            // Calculate target price that maintains current gain level
            let targetPrice = calculateTargetPriceForGain(
                currentPrice: currentPrice,
                avgCostPerShare: avgCostPerShare,
                currentProfitPercent: currentProfitPercent,
                targetGainPercent: targetGainPercent,
                totalShares: totalShares,
                sharesToBuy: sharesToBuy
            )
            
            guard let targetBuyPrice = targetPrice else {
                AppLogger.shared.error("❌ Could not calculate target price for \(sharesToBuy) shares")
                continue
            }
            
            // Calculate entry price (1 ATR below target)
            let entryPrice = targetBuyPrice * (1.0 - atrValue / 100.0)
            
            // Calculate trailing stop (75% of the distance from current price to target)
            let trailingStopPercent = ((targetBuyPrice - currentPrice) / currentPrice) * 100.0 * 0.75
            
            // Calculate order cost
            let orderCost = sharesToBuy * targetBuyPrice
            
            AppLogger.shared.debug("✅ Buy order for \(sharesToBuy) shares (\(percentage)%):")
            AppLogger.shared.debug("  Target price: $\(targetBuyPrice)")
            AppLogger.shared.debug("  Entry price: $\(entryPrice)")
            AppLogger.shared.debug("  Trailing stop: \(trailingStopPercent)%")
            AppLogger.shared.debug("  Order cost: $\(orderCost)")
            
            // Skip orders that cost more than $2000
            guard orderCost < 2000.0 else {
                AppLogger.shared.debug("⚠️ Skipping order - cost $\(orderCost) exceeds $2000 limit")
                continue
            }
            
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
        
        AppLogger.shared.debug("=== Final result: \(recommended.count) recommended buy orders ===")
        return recommended
    }
    
    /// Calculate the target price that would result in the target gain percentage
    /// when buying the specified number of shares
    private func calculateTargetPriceForGain(
        currentPrice: Double,
        avgCostPerShare: Double,
        currentProfitPercent: Double,
        targetGainPercent: Double,
        totalShares: Double,
        sharesToBuy: Double
    ) -> Double? {
        
        AppLogger.shared.debug("=== calculateTargetPriceForGain ===")
        AppLogger.shared.debug("Current price: $\(currentPrice)")
        AppLogger.shared.debug("Avg cost per share: $\(avgCostPerShare)")
        AppLogger.shared.debug("Current P/L%: \(currentProfitPercent)%")
        AppLogger.shared.debug("Target gain %: \(targetGainPercent)%")
        AppLogger.shared.debug("Total shares: \(totalShares)")
        AppLogger.shared.debug("Shares to buy: \(sharesToBuy)")
        
        // Calculate total cost of current position
        let totalCost = avgCostPerShare * totalShares
        
        // We want to find a target price where:
        // (targetPrice - newAvgCost) / newAvgCost = targetGainPercent / 100
        // where newAvgCost = (totalCost + sharesToBuy * targetPrice) / (totalShares + sharesToBuy)
        
        // Rearranging the equation:
        // targetPrice = newAvgCost * (1 + targetGainPercent/100)
        // newAvgCost = (totalCost + sharesToBuy * targetPrice) / (totalShares + sharesToBuy)
        // 
        // Substituting:
        // targetPrice = ((totalCost + sharesToBuy * targetPrice) / (totalShares + sharesToBuy)) * (1 + targetGainPercent/100)
        //
        // Solving for targetPrice:
        // targetPrice * (totalShares + sharesToBuy) = (totalCost + sharesToBuy * targetPrice) * (1 + targetGainPercent/100)
        // targetPrice * (totalShares + sharesToBuy) = totalCost * (1 + targetGainPercent/100) + sharesToBuy * targetPrice * (1 + targetGainPercent/100)
        // targetPrice * (totalShares + sharesToBuy) - sharesToBuy * targetPrice * (1 + targetGainPercent/100) = totalCost * (1 + targetGainPercent/100)
        // targetPrice * ((totalShares + sharesToBuy) - sharesToBuy * (1 + targetGainPercent/100)) = totalCost * (1 + targetGainPercent/100)
        // targetPrice = totalCost * (1 + targetGainPercent/100) / ((totalShares + sharesToBuy) - sharesToBuy * (1 + targetGainPercent/100))
        
        let targetGainRatio = 1.0 + targetGainPercent / 100.0
        let denominator = (totalShares + sharesToBuy) - sharesToBuy * targetGainRatio
        
        guard denominator > 0 else {
            AppLogger.shared.debug("❌ Denominator is zero or negative, cannot calculate target price")
            return nil
        }
        
        let targetPrice = totalCost * targetGainRatio / denominator
        
        AppLogger.shared.debug("Target gain ratio: \(targetGainRatio)")
        AppLogger.shared.debug("Denominator: \(denominator)")
        AppLogger.shared.debug("Calculated target price: $\(targetPrice)")
        
        // Constrain target price to be between 5% and 30% above current price
        let minTargetPrice = currentPrice * 1.05  // 5% above current price
        let maxTargetPrice = currentPrice * 1.30  // 30% above current price
        
        let constrainedTargetPrice: Double
        if targetPrice < minTargetPrice {
            constrainedTargetPrice = minTargetPrice
            AppLogger.shared.debug("⚠️ Target price $\(targetPrice) below minimum, constrained to $\(constrainedTargetPrice) (5% above current)")
        } else if targetPrice > maxTargetPrice {
            constrainedTargetPrice = maxTargetPrice
            AppLogger.shared.debug("⚠️ Target price $\(targetPrice) above maximum, constrained to $\(constrainedTargetPrice) (30% above current)")
        } else {
            constrainedTargetPrice = targetPrice
            AppLogger.shared.debug("✅ Target price $\(targetPrice) within bounds")
        }
        
        // Verify the calculation with the constrained target price
        let newTotalCost = totalCost + sharesToBuy * constrainedTargetPrice
        let newTotalShares = totalShares + sharesToBuy
        let newAvgCost = newTotalCost / newTotalShares
        let actualGainPercent = ((constrainedTargetPrice - newAvgCost) / newAvgCost) * 100.0
        
        AppLogger.shared.debug("Verification with constrained price:")
        AppLogger.shared.debug("  New total cost: $\(newTotalCost)")
        AppLogger.shared.debug("  New total shares: \(newTotalShares)")
        AppLogger.shared.debug("  New avg cost: $\(newAvgCost)")
        AppLogger.shared.debug("  Actual gain %: \(actualGainPercent)%")
        AppLogger.shared.debug("  Target gain %: \(targetGainPercent)%")
        AppLogger.shared.debug("  Difference: \(abs(actualGainPercent - targetGainPercent))%")
        
        // Check if the target price is reasonable
        guard constrainedTargetPrice > 0 else {
            AppLogger.shared.debug("❌ Target price is not positive")
            return nil
        }
        
        // Check if target price is within bounds (5% to 30% above current price)
        let priceRatio = constrainedTargetPrice / currentPrice
        guard priceRatio >= 1.05 && priceRatio <= 1.30 else {
            AppLogger.shared.debug("❌ Target price $\(constrainedTargetPrice) is outside bounds (ratio: \(priceRatio))")
            return nil
        }
        
        AppLogger.shared.debug("✅ Target price calculation successful")
        return constrainedTargetPrice
    }
    
    // MARK: - Sell Order Calculations (copied from RecommendedSellOrdersSection)
    
    private func getCurrentPrice() -> Double? {
        // Use cached price if available and symbol matches
        if cachedPriceSymbol == symbol, let cachedPrice = cachedCurrentPrice {
            return cachedPrice
        }
        
        // Ensure we never use a quote for the wrong symbol (avoids stale carryover on navigation)
        if let dataSymbol = quoteData?.symbol, dataSymbol != symbol {
            AppLogger.shared.debug("❌ QuoteData symbol (\(dataSymbol)) does not match current symbol (\(symbol)); ignoring quote data and deferring price")
            cachedCurrentPrice = nil
            cachedPriceSymbol = ""
            return nil
        } else {
            // First try to get the real-time quote price
            if let quote = quoteData?.quote?.lastPrice {
                AppLogger.shared.debug("✅ Using real-time quote price: $\(quote)")
                cachedCurrentPrice = quote
                cachedPriceSymbol = symbol
                return quote
            }
            
            // Fallback to extended market price if available
            if let extendedPrice = quoteData?.extended?.lastPrice {
                AppLogger.shared.debug("✅ Using extended market price: $\(extendedPrice)")
                cachedCurrentPrice = extendedPrice
                cachedPriceSymbol = symbol
                return extendedPrice
            }
            
            // Fallback to regular market price if available
            if let regularPrice = quoteData?.regular?.regularMarketLastPrice {
                AppLogger.shared.debug("✅ Using regular market price: $\(regularPrice)")
                cachedCurrentPrice = regularPrice
                cachedPriceSymbol = symbol
                return regularPrice
            }
        }
        
        // If we reach here and still don't have a quote, do not fallback to tax-lot price
        // until we have confirmed data for the current symbol to avoid cross-symbol leakage.
        AppLogger.shared.debug("⚠️ No valid quote available and symbol alignment unknown; returning nil to defer calculation")
        cachedCurrentPrice = nil
        cachedPriceSymbol = ""
        return nil
    }

    private func isDataReadyForCurrentSymbol() -> Bool {
        // We consider data ready only when quoteData is present and matches the current symbol
        if let dataSymbol = quoteData?.symbol, dataSymbol == symbol { return true }
        return false
    }
    
    private func getLimitedATR() -> Double {
        return max(1.0, min(TradingConfig.atrMultiplier, atrValue))
    }
    
    private func getSortedTaxLots() -> [SalesCalcPositionsRecord] {
        // Create a simple hash of tax lot data to check if sorting is needed
        let taxLotsHash = taxLotData.map { "\($0.quantity)-\($0.costPerShare)" }.joined(separator: "|")
        
        // Return cached result if available and data hasn't changed
        if cachedTaxLotsHash == taxLotsHash && !cachedSortedTaxLots.isEmpty {
            return cachedSortedTaxLots
        }
        
        // Sort tax lots by cost per share (highest first)
        let sorted = taxLotData.sorted { $0.costPerShare > $1.costPerShare }
        
        // Cache the result
        cachedSortedTaxLots = sorted
        cachedTaxLotsHash = taxLotsHash
        
        return sorted
    }
    
    private func calculatePreviewOrders() async {
        // Simplified calculation for previews that processes mock data quickly
        guard let currentPrice = getCurrentPrice() else {
            AppLogger.shared.debug("❌ No current price available for preview")
            return
        }
        
        let sortedTaxLots = getSortedTaxLots()
        
        // Quick preview calculations - simplified versions of the full algorithms
        var sellOrders: [SalesCalcResultsRecord] = []
        var buyOrders: [BuyOrderRecord] = []
        
        // Simple Top 100 order for preview
        if sortedTaxLots.count > 0 && sharesAvailableForTrading >= 100 {
            let top100Order = createSimpleTop100Order(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
            sellOrders.append(top100Order)
        }
        
        // Simple Min Shares order for preview
        if sortedTaxLots.count > 0 {
            let minSharesOrder = createSimpleMinSharesOrder(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
            sellOrders.append(minSharesOrder)
        }
        
        // Simple Buy order for preview
        if let quoteData = quoteData, let lastPrice = quoteData.quote?.lastPrice {
            let buyOrder = createSimpleBuyOrder(currentPrice: lastPrice)
            buyOrders.append(buyOrder)
        }
        
        // Update state on main thread
        await MainActor.run {
            self.recommendedSellOrders = sellOrders
            self.recommendedBuyOrders = buyOrders
            self.currentOrders = self.createPreviewAllOrders(sellOrders: sellOrders, buyOrders: buyOrders)
            self.cachedAllOrders = self.currentOrders
        }
        
        AppLogger.shared.debug("✅ Preview orders calculated: \(sellOrders.count) sell, \(buyOrders.count) buy")
    }
    
    // MARK: - Preview Helper Functions
    
    private func createSimpleTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord {
        // Simplified Top 100 order for previews
        let entry = currentPrice * 0.95  // 5% below current price
        let target = currentPrice * 1.10 // 10% above current price
        let cancel = currentPrice * 0.90 // 10% below current price
        
        var order = SalesCalcResultsRecord()
        order.sharesToSell = 100.0
        order.entry = entry
        order.target = target
        order.cancel = cancel
        order.description = "Top 100 Shares - Preview"
        return order
    }
    
    private func createSimpleMinSharesOrder(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord {
        // Simplified Min Shares order for previews
        let minShares = min(50.0, sharesAvailableForTrading)
        let entry = currentPrice * 0.95  // 5% below current price
        let target = currentPrice * 1.05 // 5% above current price
        let cancel = currentPrice * 0.90 // 10% below current price
        
        var order = SalesCalcResultsRecord()
        order.sharesToSell = minShares
        order.entry = entry
        order.target = target
        order.cancel = cancel
        order.description = "Min Shares - Preview"
        return order
    }
    
    private func createSimpleBuyOrder(currentPrice: Double) -> BuyOrderRecord {
        // Simplified Buy order for previews
        let targetBuyPrice = currentPrice * 0.95  // 5% below current price
        let entryPrice = currentPrice * 0.97      // 3% below current price
        let targetGainPercent = 8.0               // 8% target gain
        
        var order = BuyOrderRecord()
        order.sharesToBuy = 100.0
        order.targetBuyPrice = targetBuyPrice
        order.entryPrice = entryPrice
        order.targetGainPercent = targetGainPercent
        order.description = "Buy Order - Preview"
        return order
    }
    
    private func createPreviewAllOrders(sellOrders: [SalesCalcResultsRecord], buyOrders: [BuyOrderRecord]) -> [(String, Any)] {
        var orders: [(String, Any)] = []
        
        // Add sell orders
        for order in sellOrders {
            orders.append(("SELL", order))
        }
        
        // Add buy orders
        for order in buyOrders {
            orders.append(("BUY", order))
        }
        
        return orders
    }

    // --- Top 100 Standing Sell ---
    private func calculateTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        // Early exit conditions for performance
        guard !sortedTaxLots.isEmpty else { return nil }
        
        // Check if position has more than 100 shares total (not just available for trading)
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        
        guard totalShares >= 100.0 else {
            AppLogger.shared.debug("❌ Top 100 order: Position has only \(totalShares) shares, need at least 100")
            return nil
        }
        
        AppLogger.shared.debug("=== calculateTop100Order ===")
        
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
        AppLogger.shared.debug("  Current price: $\(currentPrice)")
        
        // Check if the top 100 shares are profitable at current price
        let currentProfitPercent = ((currentPrice - actualCostPerShare) / actualCostPerShare) * 100.0
        let isTop100Profitable = currentProfitPercent > 0
        
        AppLogger.shared.debug("  Current profit % for top 100: \(currentProfitPercent)%")
        AppLogger.shared.debug("  Top 100 profitable at current price: \(isTop100Profitable)")
        
        let entry: Double
        let target: Double
        let trailingStop: Double
        
        if isTop100Profitable {
            // If top 100 shares are profitable, use similar logic to Min Break Even
            // Target price = (currentPrice + actualCostPerShare) / 2
            target = (currentPrice + actualCostPerShare) / 2.0
            
            // Entry point = (currentPrice - actualCostPerShare) / 4 + target
            entry = (currentPrice - actualCostPerShare) / 4.0 + target
            
            // Trailing stop = ((entry - target) / target) * 100.0
            trailingStop = ((entry - target) / target) * 100.0
            
            AppLogger.shared.debug("✅ Top 100 profitable - using profit-based logic")
            AppLogger.shared.debug("  Target: $\(target)")
            AppLogger.shared.debug("  Entry: $\(entry)")
            AppLogger.shared.debug("  Trailing stop: \(trailingStop)%")
        } else {
            // If top 100 shares are not profitable, use similar logic to Min ATR
            // Use ATR-based calculation like other sell orders
            let adjustedATR = atrValue / 5.0 // Same as Min Break Even
            
            // Entry = Current - 1 AATR%
            entry = currentPrice * (1.0 - adjustedATR / 100.0)
            
            // Target = Entry - 2 AATR%
            target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
            
            // Trailing stop = adjustedATR
            trailingStop = adjustedATR
            
            AppLogger.shared.debug("⚠️ Top 100 not profitable - using ATR-based logic")
            AppLogger.shared.debug("  Entry: $\(entry)")
            AppLogger.shared.debug("  Target: $\(target)")
            AppLogger.shared.debug("  Trailing stop: \(trailingStop)%")
        }
        
        // Always create the Top-100 order if we have at least 100 shares, regardless of profitability
        // The order description will indicate if it's unprofitable
        
        // Calculate exit price (same logic as other sell orders)
        let exit = max(target * (1.0 - 2.0 * (atrValue / 5.0) / 100.0), actualCostPerShare)
        
        let totalGain = finalSharesToConsider * (target - actualCostPerShare)
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        
        // Create description - always show Top-100 order, indicate if unprofitable
        let profitIndicator = isTop100Profitable ? "(Top 100)" : "(Top 100 - UNPROFITABLE)"
        let formattedDescription = String(format: "%@ SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f", 
                                          profitIndicator, finalSharesToConsider, symbol, target, trailingStop, actualCostPerShare)
        
        AppLogger.shared.debug("✅ Top 100 order created: \(formattedDescription)")
        
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

    // --- Minimum ATR-based Standing Sell ---
    private func calculateMinSharesFor5PercentProfit(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
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

        // Use the same logic as additional sell orders
        // Calculate trailing stop based on ATR
        let adjustedATR = atrValue / 5.0 // Same as Min Break Even
        let targetTrailingStop = adjustedATR
        
        AppLogger.shared.debug("Adjusted ATR: \(adjustedATR)%")
        AppLogger.shared.debug("Target trailing stop: \(targetTrailingStop)%")
        
        // Calculate entry price (same as Min Break Even)
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        AppLogger.shared.debug("Entry price: $\(entry)")
        
        // Calculate target price based on trailing stop (same as additional orders)
        let target = entry / (1.0 + targetTrailingStop / 100.0)
        AppLogger.shared.debug("Target price: $\(target)")
        
        // Use the helper function to calculate minimum shares needed to maintain 5% profit on remaining position
        guard let result = calculateMinimumSharesForRemainingProfit(
            targetProfitPercent: 5.0,
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots
        ) else {
            AppLogger.shared.warning("❌ Min ATR order: Could not achieve 5% profit on remaining position")
            return nil
        }
        
        let sharesToSell = result.sharesToSell
        let totalGain = result.totalGain
        let actualCostPerShare = result.actualCostPerShare
        
        AppLogger.shared.debug("Final calculation:")
        AppLogger.shared.debug("  Shares to sell: \(sharesToSell)")
        AppLogger.shared.debug("  Total gain: $\(totalGain)")
        AppLogger.shared.debug("  Actual cost per share: $\(actualCostPerShare)")
        
        // Validate that shares to sell is at least 1 and doesn't exceed available shares
        guard sharesToSell >= 1.0 else {
            AppLogger.shared.debug("❌ Min ATR order rejected: shares to sell (\(sharesToSell)) is less than 1")
            return nil
        }
        
        guard sharesToSell <= sharesAvailableForTrading else {
            AppLogger.shared.debug("❌ Min ATR order rejected: shares to sell (\(sharesToSell)) exceeds available shares (\(sharesAvailableForTrading))")
            return nil
        }
        
        AppLogger.shared.debug("✅ Min ATR order: shares to sell (\(sharesToSell)) is valid (>= 1 and <= available shares)")
        
        // Validate that target is above the actual cost per share of the shares being sold
        guard target > actualCostPerShare else {
            AppLogger.shared.debug("❌ Min ATR order rejected: target ($\(target)) is not above actual cost per share ($\(actualCostPerShare))")
            return nil
        }
        
        // Calculate exit price (same logic as other sell orders)
        let exit = max(target * (1.0 - 2.0 * (atrValue / 5.0) / 100.0), actualCostPerShare)
        AppLogger.shared.debug("Exit price: $\(exit)")
        
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        let formattedDescription = String(format: "(Min ATR) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f", sharesToSell, symbol, target, targetTrailingStop, actualCostPerShare)
        AppLogger.shared.debug("✅ Min ATR order created: \(formattedDescription)")
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

        // Check if the highest cost-per-share tax lot is profitable
        guard let highestCostLot = sortedTaxLots.first else { return nil }
        let highestCostProfitPercent = ((currentPrice - highestCostLot.costPerShare) / highestCostLot.costPerShare) * 100.0
        let isHighestCostLotProfitable = highestCostProfitPercent > 0
        
        AppLogger.shared.debug("=== calculateMinBreakEvenOrder Highest cost lot: $\(highestCostLot.costPerShare), profit: \(highestCostProfitPercent)%")
        
        let entry: Double
        let target: Double
        let sharesToSell: Double
        let actualCostPerShare: Double
        
        if isHighestCostLotProfitable {
            // New logic: If highest cost lot is profitable
       
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
            // let trailingStopValue = ((entry - target) / target) * 100.0
            
            
            
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
                AppLogger.shared.warning("❌ Min Break Even order: Could not achieve 1% gain at target price")
                return nil
            }
            
            sharesToSell = result.sharesToSell
            actualCostPerShare = result.actualCostPerShare
            
        }
        
        // Validate that shares to sell is at least 1 and doesn't exceed available shares
        guard sharesToSell >= 1.0 else {
            AppLogger.shared.debug("❌ Min Break Even order rejected: shares to sell (\(sharesToSell)) is less than 1")
            return nil
        }
        
        guard sharesToSell <= sharesAvailableForTrading else {
            AppLogger.shared.debug("❌ Min Break Even order rejected: shares to sell (\(sharesToSell)) exceeds available shares (\(sharesAvailableForTrading))")
            return nil
        }
        
        AppLogger.shared.debug("✅ Min Break Even order: shares to sell (\(sharesToSell)) is valid (>= 1 and <= available shares)")
        
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
        

        
        // Verify the ordering: Entry > Target > Exit > Cost-per-share for sell orders

        
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
    

    

    
    /// Calculate additional sell orders from tax lots
    private func calculateAdditionalSellOrdersFromTaxLots(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord
    ) -> [SalesCalcResultsRecord] {
        
        AppLogger.shared.debug("=== calculateAdditionalSellOrdersFromTaxLots ===")
        AppLogger.shared.debug("Current price: \(currentPrice)")
        AppLogger.shared.debug("Min BE order: \(minBreakEvenOrder.description)")
        AppLogger.shared.debug("Shares available for trading: \(sharesAvailableForTrading)")
        
        var additionalOrders: [SalesCalcResultsRecord] = []
        var currentTaxLotIndex = 0
        
        // Create 1% higher trailing stop order
        if let higherTSOrder = createOnePercentHigherTrailingStopOrder(
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots,
            minBreakEvenOrder: minBreakEvenOrder,
            currentTaxLotIndex: &currentTaxLotIndex
        ) {
            additionalOrders.append(higherTSOrder)
            AppLogger.shared.debug("✅ Added 1% higher TS order: \(higherTSOrder.description)")
        }
        
        // Create max shares sell order
        if let maxSharesOrder = createMaxSharesSellOrder(
            currentPrice: currentPrice,
            sortedTaxLots: sortedTaxLots,
            minBreakEvenOrder: minBreakEvenOrder,
            currentTaxLotIndex: &currentTaxLotIndex
        ) {
            additionalOrders.append(maxSharesOrder)
            AppLogger.shared.debug("✅ Added max shares order: \(maxSharesOrder.description)")
        }
        
        // Continue with other additional orders if we haven't reached the limit
        while additionalOrders.count < maxAdditionalSellOrders {
            // ... existing logic for other additional orders ...
            break // For now, just break to avoid infinite loop
        }
        
        AppLogger.shared.debug("Total additional orders created: \(additionalOrders.count)")
        return additionalOrders
    }
    
    /// Create an additional sell order by finding shares from available tax lots
    private func createAdditionalSellOrderFromTaxLots(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        targetTrailingStop: Double,
        atrMultiplier: Double,
        cumulativeSharesUsed: Double,
        currentTaxLotIndex: inout Int
    ) -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("=== createAdditionalSellOrderFromTaxLots ===")
        AppLogger.shared.debug("Target trailing stop: \(targetTrailingStop)%")
        AppLogger.shared.debug("ATR multiplier: \(atrMultiplier)")
        AppLogger.shared.debug("Current tax lot index: \(currentTaxLotIndex)")
        AppLogger.shared.debug("Cumulative shares used: \(cumulativeSharesUsed)")
        
        // Calculate new target price based on the higher trailing stop
        let newTarget = minBreakEvenOrder.entry / (1.0 + targetTrailingStop / 100.0)
        AppLogger.shared.debug("New target price: $\(newTarget)")
        
        // Try different share amounts starting with 1 share
        let shareAmountsToTry = [1.0, 2.0, 3.0, 4.0, 5.0] // Try increasing amounts if needed
        
        for sharesToTry in shareAmountsToTry {
            AppLogger.shared.debug("Trying to create order with \(sharesToTry) shares")
            
            // Check if we have enough remaining shares
            let remainingShares = sharesAvailableForTrading - cumulativeSharesUsed
            guard sharesToTry <= remainingShares else {
                AppLogger.shared.debug("❌ Not enough remaining shares (\(remainingShares)) for \(sharesToTry) shares")
                break
            }
            
            // Try to calculate cost basis for this number of shares
            guard let costBasisResult = calculateCostBasisForShares(
                sharesNeeded: sharesToTry,
                startingTaxLotIndex: 0, // Start from highest cost tax lots
                sortedTaxLots: sortedTaxLots,
                cumulativeSharesUsed: cumulativeSharesUsed
            ) else {
                AppLogger.shared.error("❌ Could not calculate cost basis for \(sharesToTry) shares")
                continue
            }
            
            let avgCostPerShare = costBasisResult.actualCostPerShare
            let sharesToUse = costBasisResult.sharesUsed
            
            AppLogger.shared.debug("✅ Found \(sharesToUse) shares with avg cost $\(avgCostPerShare)")
            
            // Validate that new target is above the weighted average cost per share
            guard newTarget > avgCostPerShare else {
                AppLogger.shared.debug("❌ New target $\(newTarget) is not above weighted avg cost per share $\(avgCostPerShare)")
                continue
            }
            
            // Calculate exit price (same logic as min break-even)
            let exit = max(newTarget * (1.0 - 2.0 * (atrValue / 5.0) / 100.0), avgCostPerShare)
            
            let totalGain = sharesToUse * (newTarget - avgCostPerShare)
            let gain = avgCostPerShare > 0 ? ((newTarget - avgCostPerShare) / avgCostPerShare) * 100.0 : 0.0
            
            let formattedDescription = String(format: "(+%.1fATR) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                                              atrMultiplier, sharesToUse, symbol, newTarget, targetTrailingStop, avgCostPerShare)
            AppLogger.shared.debug("✅ Created additional sell order: \(formattedDescription)")
            
            // Update the tax lot index for future orders
            // Find the next tax lot index after the ones we used
            var nextTaxLotIndex = 0
            var sharesAccountedFor = 0.0
            for (index, taxLot) in sortedTaxLots.enumerated() {
                if sharesAccountedFor >= sharesToUse {
                    nextTaxLotIndex = index
                    break
                }
                sharesAccountedFor += taxLot.quantity
            }
            currentTaxLotIndex = nextTaxLotIndex
            
            return SalesCalcResultsRecord(
                shares: sharesToUse,
                rollingGainLoss: totalGain,
                breakEven: avgCostPerShare,
                gain: gain,
                sharesToSell: sharesToUse,
                trailingStop: targetTrailingStop,
                entry: minBreakEvenOrder.entry,
                target: newTarget,
                cancel: exit,
                description: formattedDescription,
                openDate: "Add\(Int(atrMultiplier * 10))ATR"
            )
        }
        
        AppLogger.shared.debug("❌ No suitable share amount found for additional sell order")
        return nil
    }
    
    /// Calculate the weighted average cost basis for a given number of shares
    /// This function properly accounts for shares from multiple tax lots
    private func calculateCostBasisForShares(
        sharesNeeded: Double,
        startingTaxLotIndex: Int,
        sortedTaxLots: [SalesCalcPositionsRecord],
        cumulativeSharesUsed: Double
    ) -> (actualCostPerShare: Double, sharesUsed: Double)? {
        
        AppLogger.shared.debug("=== calculateCostBasisForShares ===")
        AppLogger.shared.debug("Shares needed: \(sharesNeeded)")
        AppLogger.shared.debug("Starting tax lot index: \(startingTaxLotIndex)")
        AppLogger.shared.debug("Cumulative shares used: \(cumulativeSharesUsed)")
        
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        var sharesRemaining = sharesNeeded
        
        // Start from the highest cost tax lots (index 0) and work down
        for taxLotIndex in startingTaxLotIndex..<sortedTaxLots.count {
            let taxLot = sortedTaxLots[taxLotIndex]
            AppLogger.shared.debug("Examining tax lot \(taxLotIndex + 1): \(taxLot.quantity) shares at $\(taxLot.costPerShare)")
            
            // Calculate how many shares are available from this tax lot
            let sharesAvailableFromLot = taxLot.quantity
            let sharesToUseFromLot = min(sharesAvailableFromLot, sharesRemaining)
            
            if sharesToUseFromLot > 0 {
                let costFromLot = sharesToUseFromLot * taxLot.costPerShare
                
                cumulativeShares += sharesToUseFromLot
                cumulativeCost += costFromLot
                let avgCost = cumulativeCost / cumulativeShares
                
                AppLogger.shared.debug("  Using \(sharesToUseFromLot) shares from this lot")
                AppLogger.shared.debug("  Cumulative: \(cumulativeShares) shares, avg cost: $\(avgCost)")
                
                sharesRemaining -= sharesToUseFromLot
                
                if sharesRemaining <= 0 {
                    // We have enough shares
                    AppLogger.shared.debug("✅ Found enough shares: \(cumulativeShares) shares with avg cost $\(avgCost)")
                    return (actualCostPerShare: avgCost, sharesUsed: cumulativeShares)
                }
            }
        }
        
        AppLogger.shared.debug("❌ Not enough shares available")
        return nil
    }
    
    /// Create a sell order with 1% trailing stop (1% below current price)
    private func createOnePercentHigherTrailingStopOrder(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        currentTaxLotIndex: inout Int
    ) -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("=== +1 = createOnePercentHigherTrailingStopOrder ===")
        
        // Calculate 1% higher trailing stop than Min BE order
        let targetTrailingStop: Double = minBreakEvenOrder.trailingStop + 1.0
        AppLogger.shared.debug("=== +1 = Target trailing stop: \(targetTrailingStop)% (Min BE + 1.0%)")
        
        // Calculate the stop price based on the target trailing stop
        let stopPrice: Double = currentPrice * (1.0 - targetTrailingStop / 100.0)
        AppLogger.shared.debug("=== +1 = Stop price: $\(stopPrice) (based on \(targetTrailingStop)% trailing stop)")
        
        // Find the maximum number of shares where the weighted average cost per share is below the stop price
        // We need to traverse all tax lots and accumulate shares until the weighted average cost exceeds the stop price
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        var maxShares = 0
        
        AppLogger.shared.debug("=== +1 = Looking for shares with weighted avg cost < $\(stopPrice)")
        for (index, taxLot) in sortedTaxLots.enumerated() {
            AppLogger.shared.debug("=== +1 = Tax lot \(index): \(taxLot.quantity) shares, cost per share: $\(taxLot.costPerShare)")
            
            // Add all shares from this tax lot
            let sharesToAdd: Double = taxLot.quantity
            let costToAdd: Double = taxLot.costBasis
            
            // Calculate new weighted average cost
            let newCumulativeShares = cumulativeShares + sharesToAdd
            let newCumulativeCost = cumulativeCost + costToAdd
            let newWeightedAvgCost = newCumulativeCost / newCumulativeShares
            
            AppLogger.shared.debug("=== +1 = Adding \(sharesToAdd) shares at $\(taxLot.costPerShare)")
            AppLogger.shared.debug("=== +1 = New weighted avg cost: $\(newWeightedAvgCost) (cumulative: \(newCumulativeShares) shares, $\(newCumulativeCost))")

            // Check if this would make the weighted average cost too high
            // if newWeightedAvgCost >= stopPrice {
                // if the number of shares in the lots so far exceed the shares available for trading, break
                // if newCumulativeShares > sharesAvailableForTrading {
                //     AppLogger.shared.debug("❌ Stopping at tax lot \(index): new weighted avg cost $\(newWeightedAvgCost) >= stop price $\(stopPrice), but shares available for trading \(sharesAvailableForTrading) < \(newCumulativeShares)")
                //     break
                // }
            //    AppLogger.shared.debug("Skipping tax lot \(index): new weighted avg cost $\(newWeightedAvgCost) >= stop price $\(stopPrice)")
            //    continue
            // }

            // Accept these shares
            cumulativeShares = newCumulativeShares
            cumulativeCost = newCumulativeCost
            maxShares = Int(cumulativeShares)

            if newCumulativeShares > sharesAvailableForTrading {
                AppLogger.shared.debug("=== +1 = ❌ Stopping at tax lot \(index): new weighted avg cost $\(newWeightedAvgCost) >= stop price $\(stopPrice), but shares available for trading \(sharesAvailableForTrading) < \(newCumulativeShares)")
                break
            }
            // stop when the cost per share is low enough
            if newWeightedAvgCost < stopPrice {
                AppLogger.shared.debug("=== +1 = ✅ Stopping at tax lot \(index): new weighted avg cost $\(newWeightedAvgCost) < stop price $\(stopPrice)")
                break
            }
            // AppLogger.shared.debug("=== +1 = ✅ Accepted \(sharesToAdd) shares, total: \(cumulativeShares) shares, avg cost: $\(newWeightedAvgCost)")

        }

        guard maxShares > 0 else {
            AppLogger.shared.debug("=== +1 = ❌ No shares available with weighted avg cost below stop price $\(stopPrice)")
            return nil
        }

        let avgCostPerShare = cumulativeCost / cumulativeShares
        AppLogger.shared.debug("=== +1 = ✅ Found \(maxShares) shares with weighted avg cost $\(avgCostPerShare) below stop price $\(stopPrice)")

        // Calculate a profitable target price (above the average cost per share)
        let targetPrice = max(stopPrice + (avgCostPerShare - stopPrice) / 2.0, avgCostPerShare * 1.005)
        AppLogger.shared.debug("=== +1 = Target price: $\(targetPrice) (profitable above cost $\(avgCostPerShare))")

        // Verify the trailing stop calculation
        let calculatedTrailingStop = ((currentPrice - targetPrice) / currentPrice) * 100.0
        AppLogger.shared.debug("=== +1 = Calculated trailing stop: \(calculatedTrailingStop)% (should be close to \(targetTrailingStop)%)")

        let sellOrder = SalesCalcResultsRecord(
            shares: Double(maxShares),
            rollingGainLoss: Double(maxShares) * (targetPrice - avgCostPerShare),
            breakEven: avgCostPerShare,
            gain: ((targetPrice - avgCostPerShare) / avgCostPerShare) * 100.0,
            sharesToSell: Double(maxShares),
            trailingStop: targetTrailingStop,
            entry: stopPrice,
            target: targetPrice,
            cancel: targetPrice * 0.95,
            description: String(format: "(1%% TS) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f",
                               Double(maxShares), symbol, targetPrice, targetTrailingStop, avgCostPerShare),
            openDate: "1%HigherTS"
        )
        
        return sellOrder
        
    }
    
    /// Create a sell order for the maximum available shares with an appropriately adjusted trailing stop
    private func createMaxSharesSellOrder(
        currentPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord],
        minBreakEvenOrder: SalesCalcResultsRecord,
        currentTaxLotIndex: inout Int
    ) -> SalesCalcResultsRecord? {
        
        AppLogger.shared.debug("=== createMaxSharesSellOrder ===")
        
        // Calculate remaining shares available
        let remainingShares = sharesAvailableForTrading
        guard remainingShares >= 1.0 else {
            AppLogger.shared.debug("❌ No shares available for trading")
            return nil
        }
        
        AppLogger.shared.debug("Creating max shares order with \(remainingShares) shares")
        
        // Calculate cost basis for all remaining shares
        let costBasisResult = calculateCostBasisForShares(
            sharesNeeded: remainingShares,
            startingTaxLotIndex: 0,
            sortedTaxLots: sortedTaxLots,
            cumulativeSharesUsed: 0.0
        )
        
        guard let (actualCostPerShare, sharesUsed) = costBasisResult else {
            AppLogger.shared.debug("❌ Could not calculate cost basis for \(remainingShares) shares")
            return nil
        }
        
        AppLogger.shared.debug("✅ Found \(sharesUsed) shares with avg cost $\(actualCostPerShare)")
        
        // Calculate a profitable target (1% above cost per share)
        let profitableTarget = actualCostPerShare * 1.01
        AppLogger.shared.debug("Profitable target: $\(profitableTarget) (1% above cost $\(actualCostPerShare))")
        
        // Calculate the trailing stop from current price to this target
        let trailingStop = ((currentPrice - profitableTarget) / currentPrice) * 100.0
        AppLogger.shared.debug("Calculated trailing stop: \(trailingStop)%")
        
        // Validate the trailing stop is reasonable
        guard trailingStop >= 0.5 else {
            AppLogger.shared.debug("❌ Calculated trailing stop \(trailingStop)% is too small (< 0.5%)")
            return nil
        }
        
        // Calculate the proper target price: midway between stop price and cost per share
        let stopPrice = currentPrice * (1.0 - trailingStop / 100.0)
        let targetPrice = stopPrice + (actualCostPerShare - stopPrice) / 2.0
        
        AppLogger.shared.debug("Stop price: \(stopPrice), Target price: \(targetPrice), Cost per share: \(actualCostPerShare)")
        
        // Calculate gain at this target
        let gainAtTarget = ((targetPrice - actualCostPerShare) / actualCostPerShare) * 100.0
        AppLogger.shared.debug("Gain at target: \(gainAtTarget)%")
        
        // Create the sell order
        let description = String(
            format: "(Max Shares) SELL -%.0f %@ Target %.2f TS %.2f%% Cost/Share %.2f",
            sharesUsed,
            symbol,
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
        
        AppLogger.shared.debug("✅ Max shares sell order created: \(description)")
        return sellOrder
    }
    
    private func updateRecommendedOrders() async {
        // Use cached results if available and data hasn't changed
        let currentDataHash = getDataHash()
        if currentDataHash == lastCalculatedDataHash && !cachedAllOrders.isEmpty {
            AppLogger.shared.debug("✅ Using cached orders, data unchanged")
            return
        }
        
        AppLogger.shared.debug("🔄 Recalculating orders due to data change")
        
        // Use Task to handle async calculations without blocking the UI
        Task {
            // Calculate new orders in parallel
            async let sellOrders = calculateRecommendedSellOrders()
            async let buyOrders = calculateRecommendedBuyOrders()
            
            // Wait for both to complete
            let (sellResults, buyResults) = await (sellOrders, buyOrders)
            
            await MainActor.run {
                // Update state on main thread
                self.recommendedSellOrders = sellResults
                self.recommendedBuyOrders = buyResults
                
                // Update current orders
                self.currentOrders = self.getAllOrders()
                
                // Update cache
                self.lastCalculatedDataHash = currentDataHash
                AppLogger.shared.debug("✅ Orders updated and cached")
            }
        }
    }
    
    private func checkAndUpdateSymbol() {
        if symbol != lastSymbol {
            AppLogger.shared.debug("Symbol changed from \(lastSymbol) to \(symbol)")
            lastSymbol = symbol
            copiedValue = "TBD"
            selectedSellOrderIndex = nil
            selectedBuyOrderIndex = nil
            // Clear cache when symbol changes
            cachedSellOrders.removeAll()
            cachedBuyOrders.removeAll()
            cachedAllOrders.removeAll()
            lastCalculatedSymbol = ""
            lastCalculatedDataHash = ""
            // Clear price cache
            cachedCurrentPrice = nil
            cachedPriceSymbol = ""
            // Clear tax lots cache
            cachedSortedTaxLots.removeAll()
            cachedTaxLotsHash = ""
            // Avoid computing with stale data from the previous position. Clear UI and
            // wait for new quote/tax-lot inputs to arrive; the onChange handlers will
            // repopulate when fresh data is ready for this symbol.
            currentOrders.removeAll()
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended Orders")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Loading indicator for tax lot calculation
            if isLoadingTaxLots {
                VStack(spacing: 12) {
                    ProgressView(value: loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)
                    
                    Text(loadingMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Cancel") {
                        cancelTaxLotCalculation()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 8) {
                    sellOrdersSection
                    buyOrdersSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                submitButtonSection
                    .frame(maxHeight: .infinity)
            }
            
            // Copy feedback text
            if copiedValue != "TBD" {
                HStack {
                    Spacer()
                    Text("Copied: \(copiedValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        //.background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onChange(of: symbol) { _, newSymbol in
            checkAndUpdateSymbol()
        }
        .onAppear {
            // Load tax lots in background when component appears
            loadTaxLotsInBackground()
            
            // Only populate when we have aligned data for this symbol
            if currentOrders.isEmpty && isDataReadyForCurrentSymbol() {
                Task {
                    await updateRecommendedOrders()
                }
            }
        }
        .onChange(of: symbol) { _, newSymbol in
            checkAndUpdateSymbol()
        }
        .onChange(of: atrValue) { _, _ in
            // Only recalculate if we have data and the symbol matches
            guard isDataReadyForCurrentSymbol() else { return }
            Task {
                await updateRecommendedOrders()
            }
        }
        .onChange(of: sharesAvailableForTrading) { _, _ in
            // Only recalculate if we have data and the symbol matches
            guard isDataReadyForCurrentSymbol() else { return }
            Task {
                await updateRecommendedOrders()
            }
        }
        .onChange(of: quoteData?.quote?.lastPrice) { _, _ in
            // Only recalculate if we have data and the symbol matches
            guard isDataReadyForCurrentSymbol() else { return }
            Task {
                await updateRecommendedOrders()
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
            Text("Your order has been submitted successfully.")
        }
    }
    
    private var confirmationDialogView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Confirm Order Submission")
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
    
    // MARK: - Sell Orders Section
    private var sellOrdersSection: some View {
        VStack(spacing: 8) {
            sellOrdersHeaderRow
            
            if let sellOrders = getSellOrders() {
                ForEach(Array(sellOrders.enumerated()), id: \.element.id) { index, order in
                    sellOrderRow(order: order, index: index)
                }
            } else {
                Text("No sell orders available")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    // MARK: - Buy Orders Section
    private var buyOrdersSection: some View {
        VStack(spacing: 8) {
            buyOrdersHeaderRow
            
            if let buyOrders = getBuyOrders() {
                ForEach(Array(buyOrders.enumerated()), id: \.element.id) { index, order in
                    buyOrderRow(order: order, index: index)
                }
            } else {
                Text("No buy orders available")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    private var sellOrdersHeaderRow: some View {
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
        .background(Color.red.opacity(0.1))
    }
    
    private var buyOrdersHeaderRow: some View {
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
    
    private func sellOrderRow(order: SalesCalcResultsRecord, index: Int) -> some View {
        VStack(spacing: 4) {
            // First line: checkbox, shares, stop, target
            HStack {
                Button(action: {
                    if selectedSellOrderIndex == index {
                        selectedSellOrderIndex = nil  // Deselect if already selected
                    } else {
                        selectedSellOrderIndex = index  // Select this order
                    }
                }) {
                    Image(systemName: selectedSellOrderIndex == index ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 30, alignment: .center)
                
                Spacer()
                
                Text("\(Int(order.sharesToSell))")
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        copyToClipboard(value: Double(order.sharesToSell), format: "%.0f")
                    }
                
                Text(String(format: "%.2f%%", order.trailingStop))
                    .font(.caption)
                    .frame(width: 100, alignment: .trailing)
                    .onTapGesture {
                        copyToClipboard(value: order.trailingStop, format: "%.2f")
                    }
                
                Text(String(format: "%.2f", order.target))
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        copyToClipboard(value: order.target, format: "%.2f")
                    }
            }
            
            // Second line: description
            HStack {
                Text(order.description)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        copyToClipboard(text: order.description)
                    }
            }
            .padding(.leading, 30) // Align with content above checkbox
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(selectedSellOrderIndex == index ? Color.red.opacity(0.2) : Color.red.opacity(0.05))
        .cornerRadius(4)
    }
    
    private func buyOrderRow(order: BuyOrderRecord, index: Int) -> some View {
        VStack(spacing: 4) {
            // First line: checkbox, shares, stop, target
            HStack {
                Button(action: {
                    if selectedBuyOrderIndex == index {
                        selectedBuyOrderIndex = nil  // Deselect if already selected
                    } else {
                        selectedBuyOrderIndex = index  // Select this order
                    }
                }) {
                    Image(systemName: selectedBuyOrderIndex == index ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 30, alignment: .center)
                
                Spacer()
                
                Text("\(Int(order.sharesToBuy))")
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        copyToClipboard(value: Double(order.sharesToBuy), format: "%.0f")
                    }
                
                Text(String(format: "%.2f%%", order.trailingStop))
                    .font(.caption)
                    .frame(width: 100, alignment: .trailing)
                    .onTapGesture {
                        copyToClipboard(value: order.trailingStop, format: "%.2f")
                    }
                
                Text(String(format: "%.2f", order.targetBuyPrice))
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        copyToClipboard(value: order.targetBuyPrice, format: "%.2f")
                    }
            }
            
            // Second line: description
            HStack {
                Text(order.description)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        copyToClipboard(text: order.description)
                    }
            }
            .padding(.leading, 30) // Align with content above checkbox
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(selectedBuyOrderIndex == index ? Color.blue.opacity(0.2) : Color.blue.opacity(0.05))
        .cornerRadius(4)
    }
    
    // MARK: - Submit Button Section
    private var submitButtonSection: some View {
        VStack {
            if selectedSellOrderIndex != nil || selectedBuyOrderIndex != nil {
                Button(action: submitOrders) {
                    VStack(spacing: 4) {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.title3)
                        Text("Submit\nOrder")
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "paperplane.circle")
                        .font(.title3)
                    Text("Submit")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.secondary)
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .frame(width: 40)
        .padding(.leading, 16)
    }
    
    private func submitOrders() {
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] === submitOrders START ===")
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] Selected sell order index: \(selectedSellOrderIndex?.description ?? "nil")")
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] Selected buy order index: \(selectedBuyOrderIndex?.description ?? "nil")")
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] All orders count: \(currentOrders.count)")
        
        // Allow single orders - at least one must be selected
        guard selectedSellOrderIndex != nil || selectedBuyOrderIndex != nil else { 
            AppLogger.shared.debug("🔄 [ORDER-SUBMIT] ❌ At least one order must be selected")
            return 
        }
        
        // Get the selected orders
        let sellOrders = getSellOrders()
        let buyOrders = getBuyOrders()
        
        var selectedOrders: [(String, Any)] = []
        
        // Add sell order if selected
        if let sellIndex = selectedSellOrderIndex,
           let sellOrder = sellOrders?[sellIndex] {
            AppLogger.shared.debug("🔄 [ORDER-SUBMIT] Selected SELL order: sharesToSell=\(sellOrder.sharesToSell), entry=\(sellOrder.entry), target=\(sellOrder.target), cancel=\(sellOrder.cancel)")
            selectedOrders.append(("SELL", sellOrder))
        }
        
        // Add buy order if selected
        if let buyIndex = selectedBuyOrderIndex,
           let buyOrder = buyOrders?[buyIndex] {
            AppLogger.shared.debug("🔄 [ORDER-SUBMIT] Selected BUY order: sharesToBuy=\(buyOrder.sharesToBuy), targetBuyPrice=\(buyOrder.targetBuyPrice), entryPrice=\(buyOrder.entryPrice), targetGainPercent=\(buyOrder.targetGainPercent)")
            selectedOrders.append(("BUY", buyOrder))
        }
        
        // Validate that we have at least one order
        guard !selectedOrders.isEmpty else {
            AppLogger.shared.debug("🔄 [ORDER-SUBMIT] ❌ Could not retrieve selected orders")
            return
        }
        
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] Total orders to submit: \(selectedOrders.count)")
        
        // Get account number from the position
        guard let accountNumberInt = getAccountNumber() else {
            AppLogger.shared.error("🔄 [ORDER-SUBMIT] ❌ Could not get account number for position")
            return
        }
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] Account number: \(accountNumberInt)")
        
        // Create order (single order or OCO if both are selected)
        let orderType = selectedOrders.count == 1 ? "single order" : "OCO order"
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] Creating \(orderType) without timing constraints")
        
        // Create order using SchwabClient (single order or OCO)
        guard let orderToSubmit = SchwabClient.shared.createOrder(
            symbol: symbol,
            accountNumber: accountNumberInt,
            selectedOrders: selectedOrders,
            releaseTime: "" // No release time for simplified orders
        ) else {
            AppLogger.shared.error("🔄 [ORDER-SUBMIT] ❌ Failed to create order")
            return
        }
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] ✅ Order created successfully")
        
        // Create order descriptions for confirmation dialog
        orderDescriptions = createOrderDescriptions(orders: selectedOrders)
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] Created \(orderDescriptions.count) order descriptions:")
        for (index, description) in orderDescriptions.enumerated() {
            AppLogger.shared.debug("🔄 [ORDER-SUBMIT]   \(index + 1): \(description)")
        }
        
        // Create JSON preview
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(orderToSubmit)
            orderJson = String(data: jsonData, encoding: .utf8) ?? "{}"
            AppLogger.shared.debug("🔄 [ORDER-SUBMIT] JSON created successfully, length: \(orderJson.count)")
            AppLogger.shared.debug("🔄 [ORDER-SUBMIT] JSON preview : \(String(orderJson))")
        } catch {
            orderJson = "Error encoding order: \(error)"
            AppLogger.shared.error("🔄 [ORDER-SUBMIT] ❌ JSON encoding error: \(error)")
        }
        
        // Store the order and show confirmation dialog
        self.orderToSubmit = orderToSubmit
        showingConfirmationDialog = true
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] ✅ Showing confirmation dialog")
        AppLogger.shared.debug("🔄 [ORDER-SUBMIT] === submitOrders END ===")
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
                            AppLogger.shared.error("  ❌ Could not convert account number to Int64")
                        }
                    }
                }
            }
        }
        
        // Fallback to the truncated version if full account number not found
        AppLogger.shared.error("❌ No matching account found for symbol \(symbol), using truncated account number: \(accountNumber)")
        return Int64(accountNumber)
    }
    
    private func createOrderDescriptions(orders: [(String, Any)]) -> [String] {
        AppLogger.shared.debug("=== createOrderDescriptions ===")
        AppLogger.shared.debug("Input orders count: \(orders.count)")
        
        var descriptions: [String] = []
        for (index, (orderType, order)) in orders.enumerated() {
            AppLogger.shared.debug("createOrderDescriptions - Processing order \(index + 1): type=\(orderType), order=\(type(of: order))")
            
            if let sellOrder = order as? SalesCalcResultsRecord {
                AppLogger.shared.debug("createOrderDescriptions -   Found SELL order: sharesToSell=\(sellOrder.sharesToSell), entry=\(sellOrder.entry), target=\(sellOrder.target), cancel=\(sellOrder.cancel)")
                let description = sellOrder.description.isEmpty ? 
                    "SELL \(sellOrder.sharesToSell) shares at \(sellOrder.entry) (Target: \(sellOrder.target), Cancel: \(sellOrder.cancel))" :
                    sellOrder.description
                descriptions.append("Order \(index + 1) (SELL): \(description)")
            } else if let buyOrder = order as? BuyOrderRecord {
                AppLogger.shared.debug("createOrderDescriptions -   Found BUY order: sharesToBuy=\(buyOrder.sharesToBuy), targetBuyPrice=\(buyOrder.targetBuyPrice), entryPrice=\(buyOrder.entryPrice), targetGainPercent=\(buyOrder.targetGainPercent)")
                let description = buyOrder.description.isEmpty ?
                    "BUY \(buyOrder.sharesToBuy) shares at \(buyOrder.targetBuyPrice) (Entry: \(buyOrder.entryPrice), Target: \(buyOrder.targetGainPercent)%)" :
                    buyOrder.description
                descriptions.append("Order \(index + 1) (BUY): \(description)")
            } else {
                AppLogger.shared.debug("  ❌ Unknown order type: \(type(of: order))")
            }
        }
        
        AppLogger.shared.debug("createOrderDescriptions - Created \(descriptions.count) descriptions")
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
                selectedSellOrderIndex = nil
                selectedBuyOrderIndex = nil
                
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
    
    private func createOrderDescription(orders: [(String, Any)]) -> String {
        guard !orders.isEmpty else { return "" }
        
        var description = "Orders for \(symbol):\n"
        
        for (index, (_, order)) in orders.enumerated() {
            if let sellOrder = order as? SalesCalcResultsRecord {
                description += "Order \(index + 1) (SELL): \(sellOrder.description)\n"
            } else if let buyOrder = order as? BuyOrderRecord {
                description += "Order \(index + 1) (BUY): \(buyOrder.description)\n"
            }
        }
        
        return description
    }
    
    private func getSellOrders() -> [SalesCalcResultsRecord]? {
        let sellOrders = currentOrders.compactMap { order in
            if order.0 == "SELL", let sellOrder = order.1 as? SalesCalcResultsRecord {
                return sellOrder
            }
            return nil
        }
        return sellOrders.isEmpty ? nil : sellOrders
    }
    
    private func getBuyOrders() -> [BuyOrderRecord]? {
        let buyOrders = currentOrders.compactMap { order in
            if order.0 == "BUY", let buyOrder = order.1 as? BuyOrderRecord {
                return buyOrder
            }
            return nil
        }
        return buyOrders.isEmpty ? nil : buyOrders
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
        
        AppLogger.shared.error("❌ Could not achieve target gain of \(targetGainPercent)%")
        return nil
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
    
    // MARK: - Background Loading Methods
    private func loadTaxLotsInBackground() {
        guard !isLoadingTaxLots else { return }
        
        isLoadingTaxLots = true
        loadingProgress = 0.0
        loadingMessage = "Initializing tax lot calculation..."
        
        taxLotCalculationTask = Task {
            // Simulate progress updates
            await updateLoadingProgress(0.1, "Fetching transaction history...")
            
            // Use the optimized tax lot calculation
            let currentPrice = await MainActor.run { quoteData?.quote?.lastPrice }
            let taxLots = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = SchwabClient.shared.computeTaxLotsOptimized(symbol: symbol, currentPrice: currentPrice)
                    continuation.resume(returning: result)
                }
            }
            
            await updateLoadingProgress(0.8, "Processing tax lot data...")
            
            // Update the UI on main thread
            await MainActor.run {
                self.taxLotData = taxLots
                self.isLoadingTaxLots = false
                self.loadingProgress = 1.0
                self.loadingMessage = "Tax lot calculation complete!"
                
                // Hide the loading message after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.loadingProgress = 0.0
                    self.loadingMessage = ""
                }
            }
        }
    }
    
    @MainActor
    private func updateLoadingProgress(_ progress: Double, _ message: String) async {
        loadingProgress = progress
        loadingMessage = message
    }
    
    private func cancelTaxLotCalculation() {
        taxLotCalculationTask?.cancel()
        taxLotCalculationTask = nil
        isLoadingTaxLots = false
        loadingProgress = 0.0
        loadingMessage = ""
    }
} 

// MARK: - Previews

#Preview("RecommendedOCOOrdersSection - Full View", traits: .landscapeLeft) {
    ScrollView {
        RecommendedOCOOrdersSection(
            symbol: "AAPL",
            atrValue: 2.5,
            sharesAvailableForTrading: 150,
            quoteData: QuoteData(
                assetMainType: "EQUITY",
                assetSubType: "COE",
                quoteType: "NBBO",
                realtime: true,
                ssid: 123456789,
                symbol: "AAPL",
                extended: nil,
                fundamental: nil,
                quote: Quote(
                    m52WeekHigh: 200.0,
                    m52WeekLow: 120.0,
                    askMICId: "XNAS",
                    askPrice: 175.5,
                    askSize: 100,
                    askTime: 1736557200000,
                    bidMICId: "XNAS",
                    bidPrice: 174.5,
                    bidSize: 100,
                    bidTime: 1736557200000,
                    closePrice: 172.5,
                    highPrice: 176.0,
                    lastMICId: "XNAS",
                    lastPrice: 175.0,
                    lastSize: 100,
                    lowPrice: 174.0,
                    mark: 175.0,
                    markChange: 2.5,
                    markPercentChange: 1.45,
                    netChange: 2.5,
                    netPercentChange: 1.45,
                    openPrice: 172.5,
                    postMarketChange: 0.0,
                    postMarketPercentChange: 0.0,
                    quoteTime: 1736557200000,
                    securityStatus: "Normal",
                    totalVolume: 50000000,
                    tradeTime: 1736557200000,
                    volatility: 0.25
                ),
                reference: nil,
                regular: nil
            ),
            accountNumber: "123456789"
        )
    }
    .padding()
}

#Preview("RecommendedOCOOrdersSection - Simple UI", traits: .landscapeLeft) {
    ScrollView {
        RecommendedOCOOrdersSection(
            symbol: "TSLA",
            atrValue: 1.8,
            sharesAvailableForTrading: 25,
            quoteData: QuoteData(
                assetMainType: "EQUITY",
                assetSubType: "COE",
                quoteType: "NBBO",
                realtime: true,
                ssid: 987654321,
                symbol: "TSLA",
                extended: nil,
                fundamental: nil,
                quote: Quote(
                    m52WeekHigh: 250.0,
                    m52WeekLow: 150.0,
                    askMICId: "XNAS",
                    askPrice: 180.5,
                    askSize: 100,
                    askTime: 1736557200000,
                    bidMICId: "XNAS",
                    bidPrice: 179.5,
                    bidSize: 100,
                    bidTime: 1736557200000,
                    closePrice: 185.0,
                    highPrice: 182.0,
                    lastMICId: "XNAS",
                    lastPrice: 180.0,
                    lastSize: 100,
                    lowPrice: 178.0,
                    mark: 180.0,
                    markChange: -5.0,
                    markPercentChange: -2.7,
                    netChange: -5.0,
                    netPercentChange: -2.7,
                    openPrice: 185.0,
                    postMarketChange: 0.0,
                    postMarketPercentChange: 0.0,
                    quoteTime: 1736557200000,
                    securityStatus: "Normal",
                    totalVolume: 30000000,
                    tradeTime: 1736557200000,
                    volatility: 0.35
                ),
                reference: nil,
                regular: nil
            ),
            accountNumber: "987654321"
        )
    }
    .padding()
}

#Preview("RecommendedOCOOrdersSection - Minimal Data", traits: .landscapeLeft) {
    ScrollView {
        RecommendedOCOOrdersSection(
            symbol: "MSFT",
            atrValue: 1.0,
            sharesAvailableForTrading: 0,
            quoteData: nil, // No quote data to avoid calculations
            accountNumber: "111222333"
        )
    }
    .padding()
}
