import Foundation

// Test the mathematical logic for tax lot splitting
// Example: 100 shares at $8, 10 shares at $10, current price $9
// Target: 5% profit (breakeven at $9/1.05 = $8.57)

func calculateSharesForBreakeven(existingShares: Double, existingCost: Double, newLotCostPerShare: Double, targetProfitPercent: Double, currentPrice: Double) -> Double {
    let targetCostPerShare = currentPrice / (1 + targetProfitPercent)
    
    let numerator = existingCost - (targetCostPerShare * existingShares)
    let denominator = targetCostPerShare - newLotCostPerShare
    
    if abs(denominator) < 0.001 {
        return 0 // Avoid division by zero
    }
    
    let sharesNeeded = numerator / denominator
    return max(0, sharesNeeded) // Return 0 if negative
}

// Test the user's example
let existingShares: Double = 10.0  // 10 shares at $10
let existingCost: Double = 100.0   // 10 * $10 = $100
let newLotCostPerShare: Double = 8.0  // $8 per share for the 100-share lot
let targetProfitPercent: Double = 0.05  // 5% profit
let currentPrice: Double = 9.0  // $9 current price

let sharesNeeded = calculateSharesForBreakeven(
    existingShares: existingShares,
    existingCost: existingCost,
    newLotCostPerShare: newLotCostPerShare,
    targetProfitPercent: targetProfitPercent,
    currentPrice: currentPrice
)

print("=== Tax Lot Splitting Test ===")
print("Existing: \(existingShares) shares at cost of $\(existingCost) (avg: $\(existingCost/existingShares))")
print("New lot: Cost per share $\(newLotCostPerShare)")
print("Current price: $\(currentPrice)")
print("Target profit: \(targetProfitPercent * 100)%")
print("Target cost per share: $\(currentPrice / (1 + targetProfitPercent))")
print("Shares needed from new lot: \(sharesNeeded)")

// Verify the calculation
if sharesNeeded > 0 {
    let totalShares = existingShares + sharesNeeded
    let totalCost = existingCost + (sharesNeeded * newLotCostPerShare)
    let averageCost = totalCost / totalShares
    let profitPercent = (currentPrice - averageCost) / averageCost
    
    print("\n=== Verification ===")
    print("Total shares to sell: \(totalShares)")
    print("Total cost: $\(totalCost)")
    print("Average cost per share: $\(averageCost)")
    print("Profit at current price: \(profitPercent * 100)%")
    print("Expected profit: \(targetProfitPercent * 100)%")
    print("Match: \(abs(profitPercent - targetProfitPercent) < 0.001)")
} else {
    print("No shares needed - calculation failed")
}