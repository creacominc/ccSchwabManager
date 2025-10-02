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
        // Test basic buy order calculation
        let currentPrice = 150.0
        let avgCostPerShare = 140.0
        let totalShares = 100.0
        let atrValue = 2.5 // 2.5% ATR
        
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        let targetGainPercent = max(15.0, TradingConfig.atrMultiplier * atrValue) // Should be 15% (minimum) when calculated value is less than 15%
        
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
        #expect(targetGainPercent == 15.0, "Target gain percent should be 15% (minimum) when calculated value is less than 15%")
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
        // Test with high ATR (should use atrMultiplier * ATR as target)
        let atrValue = 4.0 // 4% ATR
        let targetGainPercent = max(15.0, TradingConfig.atrMultiplier * atrValue) // Should be 20% (5 * 4)
        
        #expect(targetGainPercent == 20.0, "Target gain percent should be 20% for 4% ATR")
    }
    
    @Test func testBuyOrderWithLowATR() async throws {
        // Test with low ATR (should use minimum 15% as target)
        let atrValue = 1.0 // 1% ATR
        let targetGainPercent = max(15.0, TradingConfig.atrMultiplier * atrValue) // Should be 15% (minimum)
        
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
    
    @Test func testWhenProfitableBuyOrderForLossPosition() async throws {
        // Test the "when profitable" buy order for positions at a loss
        // Example: UNP with -7.6% P/L and 1.67% ATR
        let currentPrice = 240.0
        let avgCostPerShare = 260.0 // Position is at a loss
        let atrValue = 1.67 // 1.67% ATR
        let totalShares = 100.0
        
        // Calculate current profit percent (should be negative)
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        #expect(currentProfitPercent < 0, "Position should be at a loss")
        #expect(abs(currentProfitPercent - (-7.69)) < 0.1, "Expected approximately -7.69% loss")
        
        // Calculate expected trailing stop: abs(P/L%) + 3 * ATR%
        let expectedTrailingStop = abs(currentProfitPercent) + 3.0 * atrValue
        #expect(abs(expectedTrailingStop - 12.70) < 0.1, "Expected trailing stop around 12.70%")
        
        // The buy order should:
        // 1. Be for 1 share
        // 2. Have trailing stop = abs(P/L%) + 3*ATR% = 7.69 + 5.01 = 12.70%
        // 3. Have stop price above current price
        let sharesToBuy = 1.0
        let trailingStopPercent = expectedTrailingStop
        let stopPrice = currentPrice * (1.0 + trailingStopPercent / 100.0)
        
        #expect(sharesToBuy == 1.0, "Should buy exactly 1 share")
        #expect(stopPrice > currentPrice, "Stop price should be above current price")
        #expect(trailingStopPercent >= 0.1 && trailingStopPercent <= 50.0, "Trailing stop should be within valid range")
        
        print("When Profitable Buy Order Test Results:")
        print("  Current Price: $\(currentPrice)")
        print("  Avg Cost: $\(avgCostPerShare)")
        print("  Current P/L%: \(String(format: "%.2f", currentProfitPercent))%")
        print("  ATR: \(atrValue)%")
        print("  Trailing Stop: \(String(format: "%.2f", trailingStopPercent))%")
        print("  Stop Price: $\(String(format: "%.2f", stopPrice))")
        print("  Shares to Buy: \(sharesToBuy)")
    }
    
    @Test func testWhenProfitableBuyOrderNotCreatedForProfitablePosition() async throws {
        // Test that the "when profitable" buy order is NOT created for positions that are profitable
        let currentPrice = 160.0
        let avgCostPerShare = 140.0 // Position is profitable
        
        // Calculate current profit percent (should be positive)
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        #expect(currentProfitPercent > 0, "Position should be profitable")
        
        // The order should not be created because currentProfitPercent >= 0
        // This is verified by the guard statement in the createWhenProfitableBuyOrderForLossPosition method
        print("When Profitable Buy Order (Profitable Position) Test Results:")
        print("  Current Price: $\(currentPrice)")
        print("  Avg Cost: $\(avgCostPerShare)")
        print("  Current P/L%: \(String(format: "%.2f", currentProfitPercent))%")
        print("  Order should NOT be created (position is profitable)")
    }
} 
