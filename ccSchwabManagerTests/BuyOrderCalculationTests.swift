//
//  BuyOrderCalculationTests.swift
//  ccSchwabManagerTests
//
//  Created by Harold Tomlinson on 2025-01-16.
//

import XCTest
@testable import ccSchwabManager

class BuyOrderCalculationTests: XCTestCase {

    
    func testBuyOrderCalculationWithSpreadsheetData() {
        // Test data from the spreadsheet
        let totalShares = 359.0
        let totalCost = 3445.18
        let _ = totalCost / totalShares
        let _ = 15.62
        let targetBuyPrice = 16.84
        let targetGainPercent = 54.88
        let _ = 7.84
        
        // Calculate using the correct formula:
        // ROUNDUP(((Quantity Shares × Quantity Target Buy − Quantity Cost) ÷ (0.01 × Quantity Target Gain) − Quantity Cost) ÷ Quantity Target Buy, 0)
        
        let numerator = (totalShares * targetBuyPrice - totalCost) / (0.01 * targetGainPercent) - totalCost
        let sharesToBuy = ceil(numerator / targetBuyPrice)
        
        // Expected result from spreadsheet: 77 shares
        XCTAssertEqual(sharesToBuy, 77.0, "Buy order calculation should return 77 shares")
        
        // Verify the calculation step by step
        let step1 = totalShares * targetBuyPrice - totalCost
        XCTAssertEqual(step1, 2600.38, accuracy: 0.01, "Step 1: (totalShares × targetBuyPrice - totalCost)")
        
        let step2 = step1 / (0.01 * targetGainPercent)
        XCTAssertEqual(step2, 4738.30, accuracy: 0.01, "Step 2: ÷ (0.01 × targetGainPercent)")
        
        let step3 = step2 - totalCost
        XCTAssertEqual(step3, 1293.12, accuracy: 0.01, "Step 3: - totalCost")
        
        let step4 = step3 / targetBuyPrice
        XCTAssertEqual(step4, 76.79, accuracy: 0.01, "Step 4: ÷ targetBuyPrice")
        
        let step5 = ceil(step4)
        XCTAssertEqual(step5, 77.0, "Step 5: ROUNDUP")
    }
    
    func testBuyOrderCalculationWithDifferentData() {
        // Test with different data to ensure formula works generally
        let totalShares = 100.0
        let totalCost = 1000.0
        let _ = totalCost / totalShares
        let _ = 12.0
        let targetBuyPrice = 13.0
        let targetGainPercent = 30.0
        let _ = 5.0
        
        let numerator = (totalShares * targetBuyPrice - totalCost) / (0.01 * targetGainPercent) - totalCost
        let sharesToBuy = max( ceil(numerator / targetBuyPrice), 1.0 )
        
        // Verify the calculation is reasonable
        XCTAssertGreaterThan(sharesToBuy, 0, "Shares to buy should be positive")
        XCTAssertLessThanOrEqual(sharesToBuy * targetBuyPrice, 500.0, "Order cost should not exceed $500")
    }
    
    func testBuyOrderCalculationEdgeCases() {
        // Test edge case where current profit is already above target
        let totalShares = 50.0
        let totalCost = 500.0
        let _ = totalCost / totalShares
        let _ = 15.0
        let targetBuyPrice = 16.0
        let targetGainPercent = 20.0
        let _ = 3.0
        
        let numerator = (totalShares * targetBuyPrice - totalCost) / (0.01 * targetGainPercent) - totalCost
        let sharesToBuy = ceil(numerator / targetBuyPrice)
        
        // Should still calculate a reasonable number of shares
        XCTAssertGreaterThanOrEqual(sharesToBuy, 0, "Shares to buy should be non-negative")
    }
    
    func testNewBuyOrderLogicForBelowTargetGain() {
        // Test the new logic for positions below target gain
        // Using the user's example: FCX with current price 40.14, avg cost 43.77, ATR 4.76%
        let currentPrice: Double = 40.14
        let avgCostPerShare: Double = 43.77
        let atrValue: Double = 4.76
        let targetGainPercent: Double = TradingConfig.atrMultiplier * atrValue
        
        // Calculate current profit percent
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        // Should be negative (below target gain)
        XCTAssertLessThan(currentProfitPercent, targetGainPercent, "Current position should be below target gain")
        
        // Test the new logic:
        // Target price should be 33% above current price
        let expectedTargetPrice = currentPrice * 1.333
        XCTAssertEqual(expectedTargetPrice, 53.51, accuracy: 0.01, "Target price should be 33% above current price")
        
        // Entry price should be 1 ATR% below target price
        let expectedEntryPrice = expectedTargetPrice * (1.0 - atrValue / 100.0)
        XCTAssertEqual(expectedEntryPrice, 53.51 * 0.9524, accuracy: 0.01, "Entry price should be 1 ATR% below target")
        
        // Trailing stop should be set so that from current price, the stop would be at target price
        let expectedTrailingStop = ((expectedTargetPrice / currentPrice) - 1.0) * 100.0
        XCTAssertEqual(expectedTrailingStop, 33.30, accuracy: 0.1, "Trailing stop should be 33.30%")
        
        print("Test results:")
        print("  Current price: $\(currentPrice)")
        print("  Avg cost per share: $\(avgCostPerShare)")
        print("  Current P/L%: \(currentProfitPercent)%")
        print("  Target gain %: \(targetGainPercent)%")
        print("  ATR: \(atrValue)%")
        print("  Target price: $\(expectedTargetPrice)")
        print("  Entry price: $\(expectedEntryPrice)")
        print("  Trailing stop %: \(expectedTrailingStop)%")
    }
    
    func testSingleOrderCreation() {
        // Test that single orders are created without OCO wrapper
        let symbol = "TEST"
        let accountNumber: Int64 = 487
        
        // Create a single buy order
        let buyOrder = BuyOrderRecord(
            shares: 10.0,
            targetBuyPrice: 50.0,
            entryPrice: 45.0,
            trailingStop: 10.0,
            targetGainPercent: 20.0,
            currentGainPercent: -5.0,
            sharesToBuy: 10.0,
            orderCost: 500.0,
            description: "Test buy order",
            orderType: "BUY",
            submitDate: "2025/01/01 09:30:00",
            isImmediate: false
        )
        
        let selectedOrders: [(String, Any)] = [("BUY", buyOrder)]
        
        // Test the createOrder method
        let order = SchwabClient.shared.createOrder(
            symbol: symbol,
            accountNumber: accountNumber,
            selectedOrders: selectedOrders,
            releaseTime: ""
        )
        
        // Verify that a single order was created (not OCO)
        XCTAssertNotNil(order, "Order should be created successfully")
        XCTAssertEqual(order?.orderStrategyType, .SINGLE, "Single order should have SINGLE strategy type")
        XCTAssertNil(order?.childOrderStrategies, "Single order should not have child strategies")
        
        print("✅ Single order created successfully without OCO wrapper")
    }
    
    func testFCXExampleCalculation() {
        // Test the FCX example: current price 40.14, target price 53.51
        // Trailing stop should be (53.51-40.14)/40.14 = 33.30%
        let currentPrice = 40.14
        let targetPrice = 53.51
        
        // Calculate the trailing stop percentage
        let trailingStopPercent = ((targetPrice - currentPrice) / currentPrice) * 100.0
        let roundedTrailingStopPercent = round(trailingStopPercent * 100) / 100
        
        print("📊 FCX Example Calculation:")
        print("  Current Price: $\(currentPrice)")
        print("  Target Price: $\(targetPrice)")
        print("  Trailing Stop %: \(trailingStopPercent)%")
        print("  Rounded Trailing Stop %: \(roundedTrailingStopPercent)%")
        
        // Verify the calculation is correct
        XCTAssertEqual(roundedTrailingStopPercent, 33.31, accuracy: 0.01, "FCX trailing stop should be 33.31%")
        
        // Test that the price is rounded to the penny
        let roundedTargetPrice = round(targetPrice * 100) / 100
        XCTAssertEqual(roundedTargetPrice, 53.51, accuracy: 0.01, "Target price should be rounded to 53.51")
        
        print("✅ FCX example calculation verified correctly")
    }
    
    func testMultipleOrdersCreateOCO() {
        // Test that multiple orders create an OCO structure
        let symbol = "TEST"
        let accountNumber: Int64 = 487
        
        // Create multiple orders
        let buyOrder = BuyOrderRecord(
            shares: 10.0,
            targetBuyPrice: 50.0,
            entryPrice: 45.0,
            trailingStop: 10.0,
            targetGainPercent: 20.0,
            currentGainPercent: -5.0,
            sharesToBuy: 10.0,
            orderCost: 500.0,
            description: "Test buy order",
            orderType: "BUY",
            submitDate: "2025/01/01 09:30:00",
            isImmediate: false
        )
        
        let sellOrder = SalesCalcResultsRecord(
            shares: 5.0,
            rollingGainLoss: 0.0,
            breakEven: 0.0,
            gain: 0.0,
            sharesToSell: 5.0,
            trailingStop: 10.0,
            entry: 50.0,
            target: 55.0,
            cancel: 45.0,
            description: "Test sell order",
            openDate: "2025/01/01 09:30:00"
        )
        
        let selectedOrders: [(String, Any)] = [("BUY", buyOrder), ("SELL", sellOrder)]
        
        // Test the createOrder method
        let order = SchwabClient.shared.createOrder(
            symbol: symbol,
            accountNumber: accountNumber,
            selectedOrders: selectedOrders,
            releaseTime: ""
        )
        
        // Verify that an OCO order was created
        XCTAssertNotNil(order, "Order should be created successfully")
        XCTAssertEqual(order?.orderStrategyType, .OCO, "Multiple orders should create OCO strategy type")
        XCTAssertNotNil(order?.childOrderStrategies, "OCO order should have child strategies")
        XCTAssertEqual(order?.childOrderStrategies?.count, 2, "OCO order should have 2 child orders")
        
        print("✅ Multiple orders created OCO structure successfully")
    }
} 
