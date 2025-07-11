# Tax Lot Splitting at Break-Even Point

## Overview

This implementation adds the ability to split tax lots at the break-even point to achieve precise profit targets. Instead of only being able to sell entire tax lots, the system now calculates the exact number of shares needed to achieve a 5% profit target.

## Problem Solved

**Previous behavior:**
- Tax lots could only be sold in their entirety
- If you had 100 shares at $8 and 10 shares at $10, with current price at $9, you could only sell all 110 shares
- This prevented optimized selling strategies

**New behavior:**
- Tax lots are split when they span the break-even point
- For the same example, you can now sell exactly 35 shares (25 from the $8 lot + 10 from the $10 lot) to achieve a 5% profit target
- This provides more granular control over sell orders

## Mathematical Logic

The system calculates the exact number of shares needed from a tax lot to achieve a target profit percentage:

```
Target Cost Per Share = Current Price / (1 + Target Profit Percentage)

For existing shares + n new shares:
(Existing Cost + n × New Lot Cost Per Share) / (Existing Shares + n) = Target Cost Per Share

Solving for n:
n = (Existing Cost - Target Cost Per Share × Existing Shares) / (Target Cost Per Share - New Lot Cost Per Share)
```

## Example Calculation

Given:
- 10 shares at $10 (cost: $100)
- 100 shares available at $8 per share
- Current price: $9
- Target: 5% profit

Target cost per share: $9 / 1.05 = $8.57

Shares needed from $8 lot:
n = (100 - 8.57 × 10) / (8.57 - 8) = 25.09 ≈ 25 shares

Result: Sell 35 shares total (10 + 25) at average cost of $8.57 for exactly 5% profit.

## Implementation Details

### Files Modified

1. **SellListView.swift**
   - Modified `getResults()` method to implement tax lot splitting
   - Added `calculateSharesForBreakeven()` helper method

2. **RecommendedSellOrdersSection.swift**
   - Applied the same logic for consistency across UI components
   - Added the same helper method

### Key Features

- **Precise Profit Targeting**: Achieves exactly 5% profit instead of approximate values
- **Clear UI Indication**: Split lots show "(X split from lot)" in the description
- **Backward Compatible**: Still handles full tax lots when splitting isn't needed
- **Maintains Existing Logic**: All other calculations (trailing stops, entry prices) remain unchanged

### Algorithm Flow

1. Sort tax lots by cost per share (highest first)
2. For each tax lot:
   - Calculate what the average cost would be if the full lot was added
   - Check if current price provides 5% profit at that average cost
   - If yes: Add the full lot and continue
   - If no: Calculate exact shares needed for 5% profit target
   - Split the lot if shares needed > 0 and <= available shares
3. Generate sell orders with split lot information

## Benefits

- **More Precise Selling**: Sell exactly the right amount for target profit
- **Better Capital Efficiency**: Avoid over-selling when partial lots would suffice
- **Maintained Flexibility**: Still supports full lot sales when appropriate
- **Clear Feedback**: UI clearly indicates when lots are split

## Testing

The implementation maintains the same trailing stop distance calculations and entry/exit price logic as the original system, ensuring consistency while adding the splitting capability.