# "When Profitable" Buy Order Feature

## Overview
Added a new buy order recommendation type for positions with negative P/L%. This "when profitable" order helps positions that are currently at a loss.

## Implementation Details

### Location
- **File**: `ccSchwabManager/DataTypes/OrderRecommendationService.swift`
- **Method**: `createWhenProfitableBuyOrderForLossPosition()`

### Behavior
The order is **only** created for positions with negative P/L% (currently at a loss).

### Order Specifications
1. **Shares**: Exactly 1 share
2. **Trailing Stop**: `abs(P/L%) + 3 × ATR%`
3. **Order Type**: BUY (trailing stop buy)

### Example
For **UNP** with:
- Current P/L: **-7.6%**
- ATR: **1.67%**

The order would have:
- Shares: **1**
- Trailing Stop: **7.6 + (3 × 1.67) = 7.6 + 5.01 = 12.61%**

### Description Format
```
BUY 1 {SYMBOL} (When Profitable) P/L={currentP/L}% Target={targetPrice} TS={trailingStop}% Gain={targetGain}% Cost={orderCost}
```

## Integration
The feature is automatically activated in `calculateRecommendedBuyOrders()` when:
```swift
if currentProfitPercent < 0 {
    // Create "when profitable" order
}
```

## Tests
Added comprehensive tests in `ccSchwabManagerTests/BuyOrderTests.swift`:
1. `testWhenProfitableBuyOrderForLossPosition()` - Verifies correct calculation with UNP example
2. `testWhenProfitableBuyOrderNotCreatedForProfitablePosition()` - Ensures order is NOT created for profitable positions

## Validation
- ✅ No linter errors
- ✅ Trailing stop validated to be within 0.1% - 50.0% range
- ✅ Order cost capped at $2000 (consistent with other buy orders)
- ✅ Only activates for positions at a loss (currentProfitPercent < 0)

## Code Quality
- Proper logging with `AppLogger`
- Follows existing pattern for buy order creation
- Consistent with memory preference: "trailing stop should be twice the ATR value" (used 3× for this specific case as requested)

