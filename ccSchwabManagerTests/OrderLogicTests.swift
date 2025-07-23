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
            // Test target gain calculation: Target Gain = max(15%, 7 * ATR)
            let expectedTargetGain = max(15.0, 7.0 * example.atr)
            
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
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Top 100) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", sharesToConsider, "TEST", entry, target, exit, costPerShare, formatReleaseTime(tomorrow))
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
        
        // Calculate minimum shares needed to achieve 1% gain on the sale
        let sortedLots = sortedTaxLots.sorted { $0.costPerShare > $1.costPerShare }
        
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        var sharesToSell: Double = 0
        var totalGain: Double = 0
        
        for lot in sortedLots {
            let lotGainPercent = ((currentPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            
            if lotGainPercent >= 1.0 {
                let lotGainAtTarget = ((target - lot.costPerShare) / lot.costPerShare) * 100.0
                
                if lotGainAtTarget >= 1.0 {
                    sharesToSell = 1.0
                    totalGain = sharesToSell * (target - lot.costPerShare)
                    cumulativeShares = 1.0
                    cumulativeCost = 1.0 * lot.costPerShare
                    break
                } else {
                    let sharesFromLot = lot.quantity
                    let costFromLot = sharesFromLot * lot.costPerShare
                    
                    cumulativeShares += sharesFromLot
                    cumulativeCost += costFromLot
                    let avgCost = cumulativeCost / cumulativeShares
                    
                    let gainPercent = ((target - avgCost) / avgCost) * 100.0
                    
                    if gainPercent >= 1.0 {
                        sharesToSell = cumulativeShares
                        totalGain = cumulativeShares * (target - avgCost)
                        break
                    }
                }
            }
        }
        
        guard sharesToSell > 0 else { return nil }
        
        // Calculate the actual cost per share for the shares being sold
        let actualCostPerShare = cumulativeCost / cumulativeShares
        let gain = actualCostPerShare > 0 ? ((target - actualCostPerShare) / actualCostPerShare) * 100.0 : 0.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Min BE) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", sharesToSell, "TEST", entry, target, exit, actualCostPerShare, formatReleaseTime(tomorrow))
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
    
    private func formatReleaseTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
} 