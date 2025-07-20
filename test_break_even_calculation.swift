#!/usr/bin/env swift

// Test script to verify break-even sell order calculation
// Based on README specification

func testBreakEvenCalculation() {
    print("=== Testing Break-Even Sell Order Calculation ===")
    
    // Test parameters from the screenshot
    let currentPrice = 153.52  // Last price from screenshot
    let avgCostPerShare = 64.88  // Cost/Share from screenshot
    let adjustedATR = 0.75  // Fixed AATR for break-even orders
    
    print("Input parameters:")
    print("  Current price: $\(currentPrice)")
    print("  Avg cost per share: $\(avgCostPerShare)")
    print("  Adjusted ATR: \(adjustedATR)%")
    
    // Calculate current profit percentage
    let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
    print("  Current profit %: \(currentProfitPercent)%")
    
    // According to README: Target price is 3.25% above the breakeven (avg cost per share)
    let target = avgCostPerShare * 1.0325
    print("\nTarget calculation:")
    print("  Target = avg cost * 1.0325")
    print("  Target = \(avgCostPerShare) * 1.0325 = \(target)")
    
    // According to README: Entry price is below the current (last) price by 1.5 * AATR %
    // ASK <= last / (1 + (1.5*AATR/100))
    let entry = currentPrice / (1.0 + (1.5 * adjustedATR / 100.0))
    print("\nEntry calculation:")
    print("  Entry = last / (1 + (1.5*AATR/100))")
    print("  Entry = \(currentPrice) / (1 + (1.5*\(adjustedATR)/100))")
    print("  Entry = \(currentPrice) / \(1.0 + (1.5 * adjustedATR / 100.0)) = \(entry)")
    
    // According to README: Exit price should be 0.9% below the target
    let exit = target * 0.991
    print("\nExit calculation:")
    print("  Exit = target * 0.991")
    print("  Exit = \(target) * 0.991 = \(exit)")
    
    print("\nExpected results:")
    print("  Entry: $\(String(format: "%.2f", entry))")
    print("  Target: $\(String(format: "%.2f", target))")
    print("  Exit: $\(String(format: "%.2f", exit))")
    
    // Compare with screenshot values
    print("\nComparison with screenshot:")
    print("  Screenshot Entry: $150.57")
    print("  Calculated Entry: $\(String(format: "%.2f", entry))")
    print("  Difference: \(String(format: "%.2f", abs(150.57 - entry)))")
    
    print("  Screenshot Target: $66.99")
    print("  Calculated Target: $\(String(format: "%.2f", target))")
    print("  Difference: \(String(format: "%.2f", abs(66.99 - target)))")
    
    print("  Screenshot Exit: $66.39")
    print("  Calculated Exit: $\(String(format: "%.2f", exit))")
    print("  Difference: \(String(format: "%.2f", abs(66.39 - exit)))")
    
    // Check if the calculation is correct
    let entryDiff = abs(150.57 - entry)
    let targetDiff = abs(66.99 - target)
    let exitDiff = abs(66.39 - exit)
    
    print("\nAccuracy check:")
    print("  Entry difference: \(String(format: "%.2f", entryDiff)) (should be < 0.01)")
    print("  Target difference: \(String(format: "%.2f", targetDiff)) (should be < 0.01)")
    print("  Exit difference: \(String(format: "%.2f", exitDiff)) (should be < 0.01)")
    
    if entryDiff < 0.01 && targetDiff < 0.01 && exitDiff < 0.01 {
        print("✅ All calculations match expected values!")
    } else {
        print("❌ Some calculations don't match expected values")
    }
}

// Run the test
testBreakEvenCalculation() 