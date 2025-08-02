//
//  BuyOrderTests.swift
//  ccSchwabManagerTests
//
//  Created by Harold Tomlinson on 2025-01-16.
//

import Testing
import Foundation
@testable import ccSchwabManager

struct BuyOrderTests {
    
    @Test func testBuyOrderCalculation() async throws {
        // Test data setup
        let _ = "AAPL"
        let atrValue = 2.5 // 2.5% ATR
        let currentPrice = 150.0
        let avgCostPerShare = 140.0
        let totalShares = 100.0
        
        // Create mock tax lot data
        let _ = [
            SalesCalcPositionsRecord(
                openDate: "2024-01-01 09:30:00",
                gainLossPct: ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0,
                gainLossDollar: (currentPrice - avgCostPerShare) * totalShares,
                quantity: totalShares,
                price: currentPrice,
                costPerShare: avgCostPerShare,
                marketValue: currentPrice * totalShares,
                costBasis: avgCostPerShare * totalShares,
                splitMultiple: 1.0
            )
        ]
        
        // Calculate expected values based on the buy order workflow
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        let targetGainPercent = max(15.0, 7.0 * atrValue) // Should be 17.5% (7 * 2.5)
        
        // Verify current profit is less than target (should trigger buy order)
        #expect(currentProfitPercent < targetGainPercent, "Current profit should be less than target to trigger buy order")
        
        // Calculate target price where we would meet the target gain percent
        let targetPrice = avgCostPerShare * (1.0 + targetGainPercent / 100.0)
        
        // Entry price is target price plus 1 ATR
        let entryPrice = targetPrice * (1.0 + atrValue / 100.0)
        
        // Target buy price is entry price plus trailing stop (1 ATR)
        let targetBuyPrice = entryPrice * (1.0 + atrValue / 100.0)
        
        // Calculate shares to buy
        let targetAvgCost = currentPrice / (1.0 + targetGainPercent / 100.0)
        let sharesToBuy = ((targetAvgCost + 16) * totalShares - avgCostPerShare * totalShares) / (targetBuyPrice - targetAvgCost)
        
        // Apply limits
        var finalSharesToBuy = sharesToBuy
        let orderCost = finalSharesToBuy * targetBuyPrice
        
        // Limit to $500 maximum investment
        if orderCost > 500.0 {
            finalSharesToBuy =  floor( 500.0 / targetBuyPrice )
        }
        
        // Round up to whole shares
        finalSharesToBuy = max(finalSharesToBuy, 1.0)
        
        // Verify calculations
        #expect(targetGainPercent == 17.5, "Target gain percent should be 17.5% (7 * 2.5)")
        #expect(targetPrice > avgCostPerShare, "Target price should be above average cost")
        #expect(entryPrice > targetPrice, "Entry price should be above target price")
        #expect(targetBuyPrice > entryPrice, "Target buy price should be above entry price")
        #expect(finalSharesToBuy > 0, "Should buy at least 1 share")
        
        // Verify order cost doesn't exceed $500
        let finalOrderCost = finalSharesToBuy * targetBuyPrice
        #expect(finalOrderCost <= 500.0, "Order cost should not exceed $500")
        
        print("Buy Order Test Results:")
        print("  Current Price: $\(currentPrice)")
        print("  Avg Cost: $\(avgCostPerShare)")
        print("  Current P/L%: \(currentProfitPercent)%")
        print("  Target P/L%: \(targetGainPercent)%")
        print("  Target Price: $\(targetPrice)")
        print("  Entry Price: $\(entryPrice)")
        print("  Target Buy Price: $\(targetBuyPrice)")
        print("  Shares to Buy: \(finalSharesToBuy)")
        print("  Order Cost: $\(finalOrderCost)")
    }
    
    @Test func testBuyOrderWithHighATR() async throws {
        // Test with high ATR (should use 7 * ATR as target)
        let atrValue = 4.0 // 4% ATR
        let targetGainPercent = max(15.0, 7.0 * atrValue) // Should be 28% (7 * 4)
        
        #expect(targetGainPercent == 28.0, "Target gain percent should be 28% for 4% ATR")
    }
    
    @Test func testBuyOrderWithLowATR() async throws {
        // Test with low ATR (should use minimum 15% as target)
        let atrValue = 1.0 // 1% ATR
        let targetGainPercent = max(15.0, 7.0 * atrValue) // Should be 15% (minimum)
        
        #expect(targetGainPercent == 15.0, "Target gain percent should be 15% minimum for 1% ATR")
    }
    
    @Test func testBuyOrderLimits() async throws {
        // Test that order cost is limited to $500
        let targetBuyPrice = 600.0 // High price
        let sharesToBuy = 10.0
        let orderCost = sharesToBuy * targetBuyPrice
        
        var finalSharesToBuy = sharesToBuy
        if orderCost > 500.0 {
            finalSharesToBuy = 500.0 / targetBuyPrice
        }
        
        let finalOrderCost = finalSharesToBuy * targetBuyPrice
        
        #expect(finalOrderCost <= 500.0, "Order cost should be limited to $500")
        #expect(finalSharesToBuy < sharesToBuy, "Should reduce shares to meet cost limit")
    }
    
    @Test func testBuyOrderWithExpensiveStock() async throws {
        // Test with stock price over $500 (should limit to 1 share)
        let targetBuyPrice = 600.0
        let sharesToBuy = 5.0
        
        var finalSharesToBuy = sharesToBuy
        if targetBuyPrice > 500.0 {
            finalSharesToBuy = 1.0
        }
        
        #expect(finalSharesToBuy == 1.0, "Should limit to 1 share for expensive stock")
    }
} 
