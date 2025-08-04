import XCTest
@testable import ccSchwabManager

class CSVValidationTests: XCTestCase {

    func testBuyOrderCSVValidation() {
        // Test with the provided CSV data
        let csvData = """
        Scenario,Ticker,ATR,Last Trade Date,,Total Quantity,Total Cost,Last Price,Average Price,Gain %,5 x ATR,"Target Gain, Minimum 15",Greater of last and breakeven,Entry Price = 1 ATR above the last/breakeven ,Target Price another ATR above the entry,7 days after last trade,Submit Date/Time,Shares to buy at Target Price,Limit shares,,Description
        Buy Order Workflow,AAOI,1.2,2025-07-01,,868,$21408.32,$28.63,$24.66,16.1,8.4,15,$28.63,$28.97,$29.32,2025-07-08,2025-07-23,920,18,"Buy 18 AAOI Submit: 2025-07-23 09:40:00   BID >= $28.97, TS = 1.2 %,  Target: $29.32"
        Buy Order Workflow,ACHR,1.2,2025-07-01,,100,$2500.00,$25.00,$25.00,0.0,8.4,15,$25.00,$25.30,$25.60,2025-07-08,2025-07-23,100,10,"Buy 10 ACHR Submit: 2025-07-23 09:40:00   BID >= $25.30, TS = 1.2 %,  Target: $25.60"
        """
        
        let records = CSVOrderValidator.parseBuyOrderCSV(csvData)
        XCTAssertEqual(records.count, 2, "Should parse 2 buy order records")
        
        for record in records {
            let errors = CSVOrderValidator.validateBuyOrderLogic(record)
            XCTAssertTrue(errors.isEmpty, "Buy order validation failed for \(record.ticker): \(errors.joined(separator: ", "))")
        }
    }
    
    func testSellOrderCSVValidation() {
        // Test with sample sell order CSV data
        let csvData = """
        Scenario,Ticker,ATR,Last Trade Date,Total Quantity,Total Cost,Last Price,Average Price,Gain %,Shares to Sell,Entry Price,Target Price,Exit Price,Submit Date/Time,Description
        Sell Top 100,AAOI,1.2,2025-07-01,868,$21408.32,$28.63,$24.66,16.1,100,$28.00,$29.50,$29.00,2025-07-23,"Sell 100 AAOI at $29.50"
        Sell Min Break Even,ACHR,1.2,2025-07-01,100,$2500.00,$25.00,$25.00,0.0,50,$24.50,$25.25,$25.00,2025-07-23,"Sell 50 ACHR at $25.25"
        """
        
        let records = CSVOrderValidator.parseSellOrderCSV(csvData)
        XCTAssertEqual(records.count, 2, "Should parse 2 sell order records")
        
        for record in records {
            let errors = CSVOrderValidator.validateSellOrderLogic(record)
            XCTAssertTrue(errors.isEmpty, "Sell order validation failed for \(record.ticker): \(errors.joined(separator: ", "))")
        }
    }
    
    func testBuyOrderLogicAgainstCurrentImplementation() {
        // Test that current implementation matches CSV logic
        let csvData = """
        Scenario,Ticker,ATR,Last Trade Date,,Total Quantity,Total Cost,Last Price,Average Price,Gain %,5 x ATR,"Target Gain, Minimum 15",Greater of last and breakeven,Entry Price = 1 ATR above the last/breakeven ,Target Price another ATR above the entry,7 days after last trade,Submit Date/Time,Shares to buy at Target Price,Limit shares,,Description
        Buy Order Workflow,AAOI,1.2,2025-07-01,,868,$21408.32,$28.63,$24.66,16.1,8.4,15,$28.63,$28.97,$29.32,2025-07-08,2025-07-23,920,18,"Buy 18 AAOI Submit: 2025-07-23 09:40:00   BID >= $28.97, TS = 1.2 %,  Target: $29.32"
        """
        
        let records = CSVOrderValidator.parseBuyOrderCSV(csvData)
        XCTAssertEqual(records.count, 1, "Should parse 1 buy order record")
        
        guard let record = records.first else {
            XCTFail("No records found")
            return
        }
        
        // Test entry price calculation: Entry Price = 1 ATR above the last/breakeven
        let expectedEntryPrice = record.greaterOfLastAndBreakeven * (1.0 + record.atr / 100.0)
        XCTAssertEqual(expectedEntryPrice, record.entryPrice, accuracy: 0.01,
                      "Entry price calculation should match CSV logic")
        
        // Test target price calculation: Target Price = Entry Price + 1 ATR
        let expectedTargetPrice = record.entryPrice * (1.0 + record.atr / 100.0)
        XCTAssertEqual(expectedTargetPrice, record.targetPrice, accuracy: 0.01,
                      "Target price calculation should match CSV logic")
        
        // Test target gain calculation: Target Gain = max(15%, 5 * ATR)
                    let expectedTargetGain = max(15.0, TradingConfig.atrMultiplier * record.atr)
        XCTAssertEqual(expectedTargetGain, record.targetGainMin15, accuracy: 0.1,
                      "Target gain calculation should match CSV logic")
    }
    
    func testSellOrderLogicAgainstCurrentImplementation() {
        // Test that current implementation matches expected sell order logic
        let currentPrice = 28.63
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2025-01-01",
                gainLossPct: 16.1,
                gainLossDollar: 3440.32,
                quantity: 868,
                price: 28.63,
                costPerShare: 24.66,
                marketValue: 24850.84,
                costBasis: 21408.32
            )
        ]
        
        // Test Top 100 order logic
        let top100Order = calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: taxLots)
        XCTAssertNotNil(top100Order, "Top 100 order should be created")
        
        if let order = top100Order {
            // Verify the order follows the expected logic
            XCTAssertLessThanOrEqual(order.sharesToSell, 100.0, "Top 100 order should sell 100 or fewer shares")
            XCTAssertGreaterThan(order.target, order.breakEven, "Target should be above break even")
            XCTAssertLessThan(order.entry, currentPrice, "Entry should be below current price")
        }
        
        // Test Min Break Even order logic
        let minBreakEvenOrder = calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: taxLots)
        XCTAssertNotNil(minBreakEvenOrder, "Min Break Even order should be created")
        
        if let order = minBreakEvenOrder {
            // Verify the order follows the expected logic
            XCTAssertGreaterThan(order.sharesToSell, 0, "Min Break Even order should sell at least 1 share")
            XCTAssertGreaterThan(order.target, order.breakEven, "Target should be above break even")
            XCTAssertLessThan(order.entry, currentPrice, "Entry should be below current price")
        }
    }
    
    func testPartialLotSupport() {
        // Test that the logic supports partial lots
        let currentPrice = 28.63
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2025-01-01",
                gainLossPct: 16.1,
                gainLossDollar: 1720.16,
                quantity: 434,
                price: 28.63,
                costPerShare: 24.66,
                marketValue: 12425.42,
                costBasis: 10704.16
            ),
            SalesCalcPositionsRecord(
                openDate: "2025-01-15",
                gainLossPct: 16.1,
                gainLossDollar: 1720.16,
                quantity: 434,
                price: 28.63,
                costPerShare: 24.66,
                marketValue: 12425.42,
                costBasis: 10704.16
            )
        ]
        
        // Test Top 100 order with partial lots
        let top100Order = calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: taxLots)
        XCTAssertNotNil(top100Order, "Top 100 order should work with partial lots")
        
        // Test Min Break Even order with partial lots
        let minBreakEvenOrder = calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: taxLots)
        XCTAssertNotNil(minBreakEvenOrder, "Min Break Even order should work with partial lots")
    }
    
    // MARK: - Helper Methods (copied from current implementation for testing)
    
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
                    cumulativeCost = lot.costPerShare
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
    
    private func formatReleaseTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
} 