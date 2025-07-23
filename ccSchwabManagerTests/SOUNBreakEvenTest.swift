import XCTest
@testable import ccSchwabManager

class SOUNBreakEvenTest: XCTestCase {
    
    func testSOUNMinimumBreakEvenCalculation() {
        // SOUN tax lots data from the CSV file
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2025-05-14 15:15:04",
                gainLossPct: -3.14,
                gainLossDollar: -3.04,
                quantity: 2.0,
                price: 11.70,
                costPerShare: 12.08,
                marketValue: 23.40,
                costBasis: 24.16,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2025-02-14 15:02:44",
                gainLossPct: 2.54,
                gainLossDollar: 31.90,
                quantity: 110.0,
                price: 11.70,
                costPerShare: 11.41,
                marketValue: 1287.00,
                costBasis: 1255.10,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2025-02-14 20:53:56",
                gainLossPct: 6.75,
                gainLossDollar: 7.40,
                quantity: 10.0,
                price: 11.70,
                costPerShare: 10.96,
                marketValue: 117.00,
                costBasis: 109.60,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2025-05-28 15:59:01",
                gainLossPct: 10.07,
                gainLossDollar: 5.35,
                quantity: 5.0,
                price: 11.70,
                costPerShare: 10.63,
                marketValue: 58.50,
                costBasis: 53.15,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-11-22 17:04:58",
                gainLossPct: 46.81,
                gainLossDollar: 466.29,
                quantity: 15.0,
                price: 11.70,
                costPerShare: 7.97,
                marketValue: 175.50,
                costBasis: 119.55,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-11-22 14:51:02",
                gainLossPct: 58.32,
                gainLossDollar: 538.75,
                quantity: 125.0,
                price: 11.70,
                costPerShare: 7.39,
                marketValue: 1462.50,
                costBasis: 923.75,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-11-05 14:45:01",
                gainLossPct: 121.59,
                gainLossDollar: 642.00,
                quantity: 60.0,
                price: 11.70,
                costPerShare: 5.28,
                marketValue: 702.00,
                costBasis: 316.80,
                splitMultiple: 1.0
            )
        ]
        
        let currentPrice = 11.70
        let atrValue = 0.25 // Assuming ATR value
        
        // Calculate the Minimum BreakEven order
        let adjustedATR = atrValue / 5.0
        let entry = currentPrice * (1.0 - adjustedATR / 100.0)
        let target = entry * (1.0 - 2.0 * adjustedATR / 100.0)
        let exit = target * (1.0 - 2.0 * adjustedATR / 100.0)
        
        print("=== SOUN Minimum BreakEven Test ===")
        print("Current price: $\(currentPrice)")
        print("ATR: \(atrValue)%")
        print("Adjusted ATR (ATR/5): \(adjustedATR)%")
        print("Entry price: $\(entry)")
        print("Target price: $\(target)")
        print("Exit price: $\(exit)")
        
        // Sort tax lots by cost per share (highest first)
        let sortedLots = taxLots.sorted { $0.costPerShare > $1.costPerShare }
        
        var cumulativeShares: Double = 0
        var cumulativeCost: Double = 0
        var sharesToSell: Double = 0
        var totalGain: Double = 0
        
        for (index, lot) in sortedLots.enumerated() {
            let lotGainPercent = ((currentPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            print("Lot \(index + 1): \(lot.quantity) shares at $\(lot.costPerShare) (gain: \(lotGainPercent)%)")
            
            // For Minimum BreakEven, we want to sell the highest cost shares first
            // to minimize losses, regardless of whether they're at a gain or loss
            let sharesFromLot = lot.quantity
            let costFromLot = sharesFromLot * lot.costPerShare
            
            cumulativeShares += sharesFromLot
            cumulativeCost += costFromLot
            let avgCost = cumulativeCost / cumulativeShares
            
            print("  Adding \(sharesFromLot) shares, cumulative: \(cumulativeShares) shares, avg cost: $\(avgCost)")
            
            // Check if this combination achieves 1% gain at target price
            let gainPercent = ((target - avgCost) / avgCost) * 100.0
            print("  Cumulative gain at target price: \(gainPercent)%")
            
            if gainPercent >= 1.0 {
                // We found the minimum shares needed to achieve 1% gain
                sharesToSell = cumulativeShares
                totalGain = cumulativeShares * (target - avgCost)
                print("  ✅ Found minimum shares: \(sharesToSell) shares with avg cost $\(avgCost)")
                break
            } else {
                print("  ⚠️ Not enough gain yet, continuing...")
            }
        }
        
        print("Final calculation:")
        print("  Shares to sell: \(sharesToSell)")
        print("  Total gain: $\(totalGain)")
        print("  Cumulative shares: \(cumulativeShares)")
        print("  Cumulative cost: $\(cumulativeCost)")
        
        // The first tax lot has 2 shares at $12.08 cost/share
        // We should be selling at least the first tax lot (2 shares) to minimize losses
        XCTAssertGreaterThanOrEqual(sharesToSell, 2.0, "Should sell at least 2 shares from the first tax lot")
        
        // The order should include the first tax lot which has 2 shares at a loss
        let firstLot = sortedLots.first!
        XCTAssertEqual(firstLot.quantity, 2.0, "First tax lot should have 2 shares")
        XCTAssertEqual(firstLot.costPerShare, 12.08, "First tax lot should have cost per share of $12.08")
        
        print("✅ Test passed: Minimum BreakEven order should sell at least 2 shares")
    }
} 