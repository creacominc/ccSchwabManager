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
        let avgCostPerShare = totalCost / totalShares
        let currentPrice = 15.62
        let targetBuyPrice = 16.84
        let targetGainPercent = 54.88
        let atrValue = 7.84
        
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
        let avgCostPerShare = totalCost / totalShares
        let currentPrice = 12.0
        let targetBuyPrice = 13.0
        let targetGainPercent = 30.0
        let atrValue = 5.0
        
        let numerator = (totalShares * targetBuyPrice - totalCost) / (0.01 * targetGainPercent) - totalCost
        let sharesToBuy = ceil(numerator / targetBuyPrice)
        
        // Verify the calculation is reasonable
        XCTAssertGreaterThan(sharesToBuy, 0, "Shares to buy should be positive")
        XCTAssertLessThanOrEqual(sharesToBuy * targetBuyPrice, 500.0, "Order cost should not exceed $500")
    }
    
    func testBuyOrderCalculationEdgeCases() {
        // Test edge case where current profit is already above target
        let totalShares = 50.0
        let totalCost = 500.0
        let avgCostPerShare = totalCost / totalShares
        let currentPrice = 15.0
        let targetBuyPrice = 16.0
        let targetGainPercent = 20.0
        let atrValue = 3.0
        
        let numerator = (totalShares * targetBuyPrice - totalCost) / (0.01 * targetGainPercent) - totalCost
        let sharesToBuy = ceil(numerator / targetBuyPrice)
        
        // Should still calculate a reasonable number of shares
        XCTAssertGreaterThanOrEqual(sharesToBuy, 0, "Shares to buy should be non-negative")
    }
} 