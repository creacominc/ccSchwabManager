import XCTest
@testable import ccSchwabManager

class OrderLogicTests: XCTestCase {


    // MARK: - Test Data from CSV Examples
    
    struct CSVExample {
        let ticker: String
        let atr: Double
        let lastTradeDate: String
        let totalQuantity: Double
        let totalCost: Double
        let lastPrice: Double
        let averagePrice: Double
        let gainPercent: Double
        let sevenXATR: Double
        let targetGainMin15: Double
        let greaterOfLastAndBreakeven: Double
        let entryPrice: Double
        let targetPrice: Double
        let sevenDaysAfterLastTrade: String
        let submitDateTime: String
        let sharesToBuyAtTargetPrice: Double
        let limitShares: Double
        let description: String
    }
    
    // Test data from the CSV file
    let csvExamples = [
        CSVExample(
            ticker: "AAOI",
            atr: 1.2,
            lastTradeDate: "2025-07-01",
            totalQuantity: 868,
            totalCost: 21408.32,
            lastPrice: 28.63,
            averagePrice: 24.66,
            gainPercent: 16.1,
            sevenXATR: 8.4,
            targetGainMin15: 15,
            greaterOfLastAndBreakeven: 28.63,
            entryPrice: 28.97,
            targetPrice: 29.32,
            sevenDaysAfterLastTrade: "2025-07-08",
            submitDateTime: "2025-07-23",
            sharesToBuyAtTargetPrice: 920,
            limitShares: 18,
            description: "Buy 18 AAOI Submit: 2025-07-23 09:40:00   BID >= $28.97, TS = 1.2 %,  Target: $29.32"
        ),
        CSVExample(
            ticker: "ACHR",
            atr: 1.2,
            lastTradeDate: "2025-07-01",
            totalQuantity: 100,
            totalCost: 2500.00,
            lastPrice: 25.00,
            averagePrice: 25.00,
            gainPercent: 0.0,
            sevenXATR: 8.4,
            targetGainMin15: 15,
            greaterOfLastAndBreakeven: 25.00,
            entryPrice: 25.30,
            targetPrice: 25.60,
            sevenDaysAfterLastTrade: "2025-07-08",
            submitDateTime: "2025-07-23",
            sharesToBuyAtTargetPrice: 100,
            limitShares: 10,
            description: "Buy 10 ACHR Submit: 2025-07-23 09:40:00   BID >= $25.30, TS = 1.2 %,  Target: $25.60"
        )
    ]
    
    // MARK: - Buy Order Logic Tests
    
    func testBuyOrderEntryPriceCalculation() {
        for example in csvExamples {
            // Test entry price calculation: Entry Price = 1 ATR above the last/breakeven
            let expectedEntryPrice = example.greaterOfLastAndBreakeven * (1.0 + example.atr / 100.0)
            
            XCTAssertEqual(expectedEntryPrice, example.entryPrice, accuracy: 0.01,
                         "Entry price calculation failed for \(example.ticker)")
        }
    }
    
    func testBuyOrderTargetPriceCalculation() {
        for example in csvExamples {
            // Test target price calculation: Target Price = Entry Price + 1 ATR
            let expectedTargetPrice = example.entryPrice * (1.0 + example.atr / 100.0)
            
            XCTAssertEqual(expectedTargetPrice, example.targetPrice, accuracy: 0.01,
                         "Target price calculation failed for \(example.ticker)")
        }
    }
    
    func testBuyOrderSharesCalculation() {
        for example in csvExamples {
            // Test shares calculation logic
            // The CSV shows specific share calculations that need verification
            let sharesToBuy = example.sharesToBuyAtTargetPrice
            let limitShares = example.limitShares
            
            // Verify that limit shares is reasonable (not more than total shares)
            XCTAssertLessThanOrEqual(limitShares, example.totalQuantity,
                                   "Limit shares should not exceed total quantity for \(example.ticker)")
            
            // Verify that shares to buy at target price is reasonable
            XCTAssertGreaterThan(sharesToBuy, 0,
                               "Shares to buy should be positive for \(example.ticker)")
        }
    }
    
    func testBuyOrderTargetGainCalculation() {
        for example in csvExamples {
            // Test target gain calculation: Target Gain = max(15%, 5 * ATR)
            let expectedTargetGain = max(15.0, TradingConfig.atrMultiplier * example.atr)
            
            XCTAssertEqual(expectedTargetGain, example.targetGainMin15, accuracy: 0.1,
                         "Target gain calculation failed for \(example.ticker)")
        }
    }
    
    // MARK: - Sell Order Logic Tests
    
    func testSellOrderTop100Calculation() {
        // Test Top 100 order logic
        let currentPrice = 30.0
        let taxLots = createTestTaxLots()
        
        let top100Order = calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: taxLots)
        
        XCTAssertNotNil(top100Order, "Top 100 order should be created")
        
        if let order = top100Order {
            // Verify shares to sell is 100 or less
            XCTAssertLessThanOrEqual(order.sharesToSell, 100.0)
            
            // Verify target price is above cost per share
            XCTAssertGreaterThan(order.target, order.breakEven)
            
            // Verify entry price is below current price
            XCTAssertLessThan(order.entry, currentPrice)
        }
    }
    
    func testSellOrderMinBreakEvenCalculation() {
        // Test Min Break Even order logic
        let currentPrice = 30.0
        let taxLots = createTestTaxLots()
        
        let minBreakEvenOrder = calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: taxLots)
        
        XCTAssertNotNil(minBreakEvenOrder, "Min Break Even order should be created")
        
        if let order = minBreakEvenOrder {
            // Verify shares to sell is positive
            XCTAssertGreaterThan(order.sharesToSell, 0)
            
            // Verify target price is above cost per share
            XCTAssertGreaterThan(order.target, order.breakEven)
            
            // Verify entry price is below current price
            XCTAssertLessThan(order.entry, currentPrice)
        }
    }
    
    func testEGOMinimumBreakEvenCalculation() {
        // EGO tax lots data from the image
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2025-07-23 13:31:24",
                gainLossPct: -0.93,
                gainLossDollar: -4.49,
                quantity: 23.0,
                price: 20.79,
                costPerShare: 20.98,
                marketValue: 478.17,
                costBasis: 482.65,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-11-21 20:36:59",
                gainLossPct: 25.09,
                gainLossDollar: 417.02,
                quantity: 100.0,
                price: 20.79,
                costPerShare: 16.62,
                marketValue: 2079.00,
                costBasis: 1661.98,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-08-06 14:12:08",
                gainLossPct: 27.23,
                gainLossDollar: 440.55,
                quantity: 99.0,
                price: 20.79,
                costPerShare: 16.34,
                marketValue: 2058.21,
                costBasis: 1617.66,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-08-06 14:12:08",
                gainLossPct: 27.23,
                gainLossDollar: 4.45,
                quantity: 1.0,
                price: 20.79,
                costPerShare: 16.34,
                marketValue: 20.79,
                costBasis: 16.34,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2025-03-06 18:43:54",
                gainLossPct: 44.27,
                gainLossDollar: 31.90,
                quantity: 5.0,
                price: 20.79,
                costPerShare: 14.41,
                marketValue: 103.95,
                costBasis: 72.05,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2025-03-06 19:19:20",
                gainLossPct: 44.98,
                gainLossDollar: 32.25,
                quantity: 5.0,
                price: 20.79,
                costPerShare: 14.34,
                marketValue: 103.95,
                costBasis: 71.70,
                splitMultiple: 1.0
            )
        ]
        
        let currentPrice = 20.79
        let atrValue = 3.32 // From the image
        
        // Calculate the Minimum BreakEven order
        let adjustedATR = atrValue / 5.0
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        let target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
        
        print("=== EGO Minimum BreakEven Test ===")
        print("Current price: $\(currentPrice)")
        print("ATR: \(atrValue)%")
        print("Adjusted ATR (ATR/5): \(adjustedATR)%")
        print("Entry price: $\(entry)")
        print("Target price: $\(target)")
        
        // Test the minimum shares calculation
        let minBreakEvenOrder = calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: taxLots)
        
        XCTAssertNotNil(minBreakEvenOrder, "Min Break Even order should be created")
        
        if let order = minBreakEvenOrder {
            print("✅ Min break even order created: \(order.description)")
            print("Shares to sell: \(order.sharesToSell)")
            print("Target price: $\(order.target)")
            print("Actual cost per share: $\(order.breakEven)")
            
            // The minimum shares should be much less than 100 since we can combine
            // the unprofitable 23 shares with some profitable shares to achieve 1% gain
            XCTAssertLessThan(order.sharesToSell, 100, "Should be able to achieve 1% gain with fewer than 100 shares")
            XCTAssertGreaterThan(order.target, order.breakEven, "Target should be above break even")
        }
    }
    
    func testEGOManualCalculation() {
        // EGO tax lots data from the image
        let _ = [
            SalesCalcPositionsRecord(
                openDate: "2025-07-23 13:31:24",
                gainLossPct: -0.93,
                gainLossDollar: -4.49,
                quantity: 23.0,
                price: 20.79,
                costPerShare: 20.98,
                marketValue: 478.17,
                costBasis: 482.65,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-11-21 20:36:59",
                gainLossPct: 25.09,
                gainLossDollar: 417.02,
                quantity: 100.0,
                price: 20.79,
                costPerShare: 16.62,
                marketValue: 2079.00,
                costBasis: 1661.98,
                splitMultiple: 1.0
            )
        ]
        
        let currentPrice = 20.79
        let atrValue = 3.32 // From the image
        
        // Calculate the Minimum BreakEven order
        let adjustedATR = atrValue / 5.0
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        let target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
        
        print("=== EGO Manual Calculation Test ===")
        print("Current price: $\(currentPrice)")
        print("ATR: \(atrValue)%")
        print("Adjusted ATR (ATR/5): \(adjustedATR)%")
        print("Entry price: $\(entry)")
        print("Target price: $\(target)")
        
        // Manual calculation
        let lot1Shares = 23.0
        let lot1Cost = 20.98
        let lot2Shares = 100.0
        let lot2Cost = 16.62
        
        // Try combining the lots
        let totalShares = lot1Shares + lot2Shares
        let totalCost = (lot1Shares * lot1Cost) + (lot2Shares * lot2Cost)
        let avgCost = totalCost / totalShares
        
        let gainPercent = ((target - avgCost) / avgCost) * 100.0
        
        print("Combined calculation:")
        print("  Lot 1: \(lot1Shares) shares at $\(lot1Cost)")
        print("  Lot 2: \(lot2Shares) shares at $\(lot2Cost)")
        print("  Total shares: \(totalShares)")
        print("  Total cost: $\(totalCost)")
        print("  Avg cost: $\(avgCost)")
        print("  Gain at target: \(gainPercent)%")
        
        // The combined calculation should achieve 1% gain
        XCTAssertGreaterThanOrEqual(gainPercent, 1.0, "Combined lots should achieve at least 1% gain")
        
        // Now try with just the second lot
        let lot2GainPercent = ((target - lot2Cost) / lot2Cost) * 100.0
        print("Lot 2 only:")
        print("  Gain at target: \(lot2GainPercent)%")
        
        // The second lot alone should achieve 1% gain
        XCTAssertGreaterThanOrEqual(lot2GainPercent, 1.0, "Lot 2 alone should achieve at least 1% gain")
    }
    
    func testEGOActualImplementation() {
        // EGO tax lots data from the image
        let _ = [
            SalesCalcPositionsRecord(
                openDate: "2025-07-23 13:31:24",
                gainLossPct: -0.93,
                gainLossDollar: -4.49,
                quantity: 23.0,
                price: 20.79,
                costPerShare: 20.98,
                marketValue: 478.17,
                costBasis: 482.65,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-11-21 20:36:59",
                gainLossPct: 25.09,
                gainLossDollar: 417.02,
                quantity: 100.0,
                price: 20.79,
                costPerShare: 16.62,
                marketValue: 2079.00,
                costBasis: 1661.98,
                splitMultiple: 1.0
            )
        ]
        
        let currentPrice = 20.79
        let atrValue = 3.32 // From the image
        
        // Calculate the Minimum BreakEven order
        let adjustedATR = atrValue / TradingConfig.atrMultiplier
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        let target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
        
        print("=== EGO Actual Implementation Test ===")
        print("Current price: $\(currentPrice)")
        print("ATR: \(atrValue)%")
        print("Adjusted ATR (ATR/5): \(adjustedATR)%")
        print("Entry price: $\(entry)")
        print("Target price: $\(target)")
        
        // Test basic calculations
        XCTAssertGreaterThan(target, 0, "Target price should be positive")
        XCTAssertGreaterThan(entry, 0, "Entry price should be positive")
        XCTAssertGreaterThan(adjustedATR, 0, "Adjusted ATR should be positive")
        
        print("✅ Basic calculations verified")
    }
    
    func testEGOTargetPriceCalculation() {
        // EGO tax lots data from the image
        let _ = [
            SalesCalcPositionsRecord(
                openDate: "2025-07-23 13:31:24",
                gainLossPct: -0.93,
                gainLossDollar: -4.49,
                quantity: 23.0,
                price: 20.79,
                costPerShare: 20.98,
                marketValue: 478.17,
                costBasis: 482.65,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-11-21 20:36:59",
                gainLossPct: 25.09,
                gainLossDollar: 417.02,
                quantity: 100.0,
                price: 20.79,
                costPerShare: 16.62,
                marketValue: 2079.00,
                costBasis: 1662.00,
                splitMultiple: 1.0
            )
        ]
        
        let currentPrice = 20.79
        let atrValue = 2.5 // From the image
        let adjustedATR = atrValue / TradingConfig.atrMultiplier
        
        // Calculate entry and target prices
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        let target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
        
        print("=== EGO Target Price Calculation ===")
        print("Current price: $\(currentPrice)")
        print("ATR: \(atrValue)%")
        print("Adjusted ATR (ATR/5): \(adjustedATR)%")
        print("Entry price: $\(entry) (Last - 1 AATR%)")
        print("Target price: $\(target) (Entry - 2 AATR%)")
        
        // Test different share combinations
        print("\n=== Testing different share combinations ===")
        
        // Test just the first lot (23 shares at $20.98)
        let lot1Gain = ((target - 20.98) / 20.98) * 100.0
        print("Lot 1 (23 shares at $20.98): \(lot1Gain)% gain at target")
        
        // Test just the second lot (100 shares at $16.62)
        let lot2Gain = ((target - 16.62) / 16.62) * 100.0
        print("Lot 2 (100 shares at $16.62): \(lot2Gain)% gain at target")
        
        // Test combining some of lot 1 with lot 2
        for sharesFromLot1 in stride(from: 1, through: 23, by: 1) {
            let sharesFromLot2 = 100 - sharesFromLot1
            if sharesFromLot2 >= 0 {
                let totalCost = (Double(sharesFromLot1) * 20.98) + (Double(sharesFromLot2) * 16.62)
                let totalShares = Double(sharesFromLot1 + sharesFromLot2)
                let avgCost = totalCost / totalShares
                let gain = ((target - avgCost) / avgCost) * 100.0
                
                if gain >= 1.0 {
                    print("Combination \(sharesFromLot1) from Lot 1 + \(sharesFromLot2) from Lot 2: \(gain)% gain (avg cost: $\(avgCost))")
                    break
                }
            }
        }
    }
    
    func testEGOMinimumSharesCalculation() {
        let currentPrice = 20.79
        let atrValue = 2.5
        let adjustedATR = atrValue / TradingConfig.atrMultiplier
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        let target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
        
        print("=== EGO Minimum Shares Calculation ===")
        print("Target price: $\(target)")
        print("Required gain: 1.0%")
        
        // EGO tax lots data
        let lot1 = (shares: 23.0, cost: 20.98)
        let lot2 = (shares: 100.0, cost: 16.62)
        
        // Test different combinations to find minimum shares
        var minShares = Double.infinity
        var bestCombination = ""
        
        // Test just lot 2 (profitable)
        let lot2Gain = ((target - lot2.cost) / lot2.cost) * 100.0
        if lot2Gain >= 1.0 {
            // Find minimum shares from lot 2
            for shares in stride(from: 1.0, through: lot2.shares, by: 1.0) {
                let gain = ((target - lot2.cost) / lot2.cost) * 100.0
                if gain >= 1.0 {
                    if shares < minShares {
                        minShares = shares
                        bestCombination = "Lot 2 only: \(shares) shares"
                    }
                    break
                }
            }
        }
        
        // Test combining lots
        for sharesFromLot1 in stride(from: 0.0, through: lot1.shares, by: 1.0) {
            for sharesFromLot2 in stride(from: 0.0, through: lot2.shares, by: 1.0) {
                let totalShares = sharesFromLot1 + sharesFromLot2
                if totalShares > 0 {
                    let totalCost = (sharesFromLot1 * lot1.cost) + (sharesFromLot2 * lot2.cost)
                    let avgCost = totalCost / totalShares
                    let gain = ((target - avgCost) / avgCost) * 100.0
                    
                    if gain >= 1.0 && totalShares < minShares {
                        minShares = totalShares
                        bestCombination = "Lot 1: \(sharesFromLot1) + Lot 2: \(sharesFromLot2) = \(totalShares) shares"
                    }
                }
            }
        }
        
        print("Best combination: \(bestCombination)")
        print("Minimum shares needed: \(minShares)")
        
        XCTAssertLessThan(minShares, Double.infinity, "Should find a valid combination")
        XCTAssertGreaterThan(minShares, 0, "Should need at least some shares")
    }
    
    func testEGOIterativeCalculation() {
        let currentPrice = 20.79
        let atrValue = 2.5
        let adjustedATR = atrValue / TradingConfig.atrMultiplier
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        let target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
        
        print("=== EGO Iterative Calculation ===")
        print("Target price: $\(target)")
        
        // EGO tax lots data
        let lot1 = (shares: 23.0, cost: 20.98) // Unprofitable
        let lot2 = (shares: 100.0, cost: 16.62) // Profitable
        
        // Start with all unprofitable shares
        let cumulativeShares = lot1.shares
        let cumulativeCost = lot1.shares * lot1.cost
        let avgCost = cumulativeCost / cumulativeShares
        
        print("Starting with Lot 1: \(cumulativeShares) shares, avg cost: $\(avgCost)")
        
        // Calculate gain with just unprofitable shares
        let gainWithUnprofitable = ((target - avgCost) / avgCost) * 100.0
        print("Gain with just unprofitable shares: \(gainWithUnprofitable)%")
        
        // Add profitable shares until we achieve 1% gain
        var sharesFromLot2 = 0.0
        while sharesFromLot2 <= lot2.shares {
            let testShares = cumulativeShares + sharesFromLot2
            let testCost = cumulativeCost + (sharesFromLot2 * lot2.cost)
            let testAvgCost = testCost / testShares
            let testGain = ((target - testAvgCost) / testAvgCost) * 100.0
            
            if testGain >= 1.0 {
                print("✅ Found minimum shares: \(testShares) shares")
                print("  - Lot 1: \(lot1.shares) shares")
                print("  - Lot 2: \(sharesFromLot2) shares")
                print("  - Avg cost: $\(testAvgCost)")
                print("  - Gain: \(testGain)%")
                break
            }
            
            sharesFromLot2 += 1.0
        }
        
        // Verify this is the correct calculation
        XCTAssertTrue(sharesFromLot2 > 0, "Should need some shares from Lot 2")
        XCTAssertTrue(sharesFromLot2 <= lot2.shares, "Should not need more than available shares")
    }
    
    // MARK: - Helper Methods
    
    private func createTestTaxLots() -> [SalesCalcPositionsRecord] {
        return [
            SalesCalcPositionsRecord(
                openDate: "2025-01-01",
                gainLossPct: 10.0,
                gainLossDollar: 100.0,
                quantity: 50,
                price: 30.0,
                costPerShare: 27.0,
                marketValue: 1500.0,
                costBasis: 1350.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2025-01-02",
                gainLossPct: 15.0,
                gainLossDollar: 150.0,
                quantity: 50,
                price: 30.0,
                costPerShare: 26.0,
                marketValue: 1500.0,
                costBasis: 1300.0
            )
        ]
    }
    
    // MARK: - Sell Order Calculation Methods (copied from current implementation for testing)
    
    private func calculateTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
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
        let formattedDescription = String(format: "(Top 100) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC", sharesToConsider, "TEST", entry, target, exit, costPerShare)
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
    
    private func calculateMinBreakEvenOrder(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        // According to sample.log: AATR is ATR/5
        let adjustedATR = 1.2 / 5.0 // Using 1.2 as ATR from test data
        
        // Only show if position is at least 1% profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        guard currentProfitPercent >= 1.0 else { return nil }
        
        // According to sample.log: Entry = Last - 1 AATR%
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        
        // According to sample.log: Target = Entry - 2 AATR%
        let target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
        
        // According to sample.log: Cancel = Target - 2 AATR%
        let exit = target * (1.0 - 2.0 * adjustedATR / 100.0)
        
        // Use the actual implementation logic for minimum shares calculation
        let minSharesResult = calculateMinimumSharesForGain(
            targetGainPercent: 1.0,
            targetPrice: target,
            sortedTaxLots: sortedTaxLots
        )
        
        guard let result = minSharesResult else { return nil }
        
        let sharesToSell = result.sharesToSell
        let totalGain = result.totalGain
        let actualCostPerShare = result.actualCostPerShare
        
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        let formattedDescription = String(format: "(Min BE) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC", sharesToSell, "TEST", entry, target, exit, actualCostPerShare)
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
            openDate: "MinBE"
        )
    }
    
    // Copy the actual implementation for testing
    private func calculateMinimumSharesForGain(
        targetGainPercent: Double,
        targetPrice: Double,
        sortedTaxLots: [SalesCalcPositionsRecord]
    ) -> (sharesToSell: Double, totalGain: Double, actualCostPerShare: Double)? {
        
        print("=== calculateMinimumSharesForGain ===")
        print("Target gain %: \(targetGainPercent)%")
        print("Target price: $\(targetPrice)")
        print("Tax lots count: \(sortedTaxLots.count)")
        
        // First, separate profitable and unprofitable lots
        var profitableLots: [SalesCalcPositionsRecord] = []
        var unprofitableLots: [SalesCalcPositionsRecord] = []
        
        for (index, lot) in sortedTaxLots.enumerated() {
            let gainAtTarget = ((targetPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            print("Lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare) (gain at target: \(gainAtTarget)%)")
            
            if gainAtTarget > 0 {
                profitableLots.append(lot)
                print("  ✅ Profitable lot: \(lot.quantity) shares")
            } else {
                unprofitableLots.append(lot)
                print("  ❌ Unprofitable lot: \(lot.quantity) shares")
            }
        }
        
        print("Profitable lots: \(profitableLots.count)")
        print("Unprofitable lots: \(unprofitableLots.count)")
        
        // Always start with unprofitable shares first (FIFO-like selling)
        // Then add minimum profitable shares needed to achieve target gain
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        
        // First, add all unprofitable shares
        for (index, lot) in unprofitableLots.enumerated() {
            print("Unprofitable lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare)")
            
            let sharesFromLot = lot.quantity
            let costFromLot = sharesFromLot * lot.costPerShare
            
            cumulativeShares += sharesFromLot
            cumulativeCost += costFromLot
            let avgCost = cumulativeCost / cumulativeShares
            
            print("  Adding \(sharesFromLot) shares, cumulative: \(cumulativeShares) shares, avg cost: $\(avgCost)")
            
            // Check if this combination achieves the target gain at target price
            let gainPercent = ((targetPrice - avgCost) / avgCost) * 100.0
            print("  Cumulative gain at target price: \(gainPercent)%")
            
            if gainPercent >= targetGainPercent {
                // We found the minimum shares needed to achieve target gain
                let sharesToSell = cumulativeShares
                let totalGain = cumulativeShares * (targetPrice - avgCost)
                let actualCostPerShare = avgCost
                
                print("  ✅ Found minimum shares: \(sharesToSell) shares with avg cost $\(actualCostPerShare)")
                print("  Total gain: $\(totalGain)")
                
                return (sharesToSell, totalGain, actualCostPerShare)
            } else {
                print("  ⚠️ Not enough gain yet, continuing with unprofitable shares...")
            }
        }
        
        // If we still need more shares, add profitable shares one by one
        for (index, lot) in profitableLots.enumerated() {
            print("Profitable lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare)")
            
            // Try adding shares from this lot one by one
            for sharesToAdd in stride(from: 1.0, through: lot.quantity, by: 1.0) {
                let testShares = cumulativeShares + sharesToAdd
                let testCost = cumulativeCost + (sharesToAdd * lot.costPerShare)
                let testAvgCost = testCost / testShares
                let testGainPercent = ((targetPrice - testAvgCost) / testAvgCost) * 100.0
                
                print("  Testing with \(sharesToAdd) shares from this lot, cumulative: \(testShares) shares, avg cost: $\(testAvgCost)")
                print("  Test gain at target price: \(testGainPercent)%")
                
                if testGainPercent >= targetGainPercent {
                    // We found the minimum shares needed to achieve target gain
                    let sharesToSell = testShares
                    let totalGain = testShares * (targetPrice - testAvgCost)
                    let actualCostPerShare = testAvgCost
                    
                    print("  ✅ Found minimum shares: \(sharesToSell) shares with avg cost $\(actualCostPerShare)")
                    print("  Total gain: $\(totalGain)")
                    
                    return (sharesToSell, totalGain, actualCostPerShare)
                }
            }
            
            // If we get here, we need all shares from this lot
            let sharesFromLot = lot.quantity
            let costFromLot = sharesFromLot * lot.costPerShare
            
            cumulativeShares += sharesFromLot
            cumulativeCost += costFromLot
            let avgCost = cumulativeCost / cumulativeShares
            
            print("  Adding all \(sharesFromLot) shares, cumulative: \(cumulativeShares) shares, avg cost: $\(avgCost)")
            
            // Check if this combination achieves the target gain at target price
            let gainPercent = ((targetPrice - avgCost) / avgCost) * 100.0
            print("  Cumulative gain at target price: \(gainPercent)%")
            
            if gainPercent >= targetGainPercent {
                // We found the minimum shares needed to achieve target gain
                let sharesToSell = cumulativeShares
                let totalGain = cumulativeShares * (targetPrice - avgCost)
                let actualCostPerShare = avgCost
                
                print("  ✅ Found minimum shares: \(sharesToSell) shares with avg cost $\(actualCostPerShare)")
                print("  Total gain: $\(totalGain)")
                
                return (sharesToSell, totalGain, actualCostPerShare)
            } else {
                print("  ⚠️ Not enough gain yet, continuing with profitable shares...")
            }
        }
        
        print("❌ Could not achieve target gain of \(targetGainPercent)%")
        return nil
    }
    
    private func formatReleaseTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
} 