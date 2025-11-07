# OCO Order Caching Implementation

## Overview

This implementation adds asynchronous computation and caching of OCO (One-Cancels-Other) order recommendations along with the rest of the security data. Previously, order recommendations were computed on-demand when users navigated to the OCO Orders tab. Now, they are computed automatically once all required data is available and cached for immediate retrieval.

## Benefits

1. **Improved Performance**: Order recommendations are computed once and reused, eliminating redundant calculations
2. **Better User Experience**: Orders are ready immediately when users open the OCO Orders tab
3. **Consistent Caching**: Order recommendations are now cached alongside other security data (price history, transactions, tax lots)
4. **Background Processing**: Computations happen asynchronously without blocking the UI

## Changes Made

### 1. SecurityDataCacheManager.swift

#### Added New SecurityDataGroup Case
```swift
enum SecurityDataGroup: CaseIterable {
    case details
    case priceHistory
    case transactions
    case taxLots
    case orderRecommendations  // NEW
}
```

#### Extended SecurityDataSnapshot Structure
Added two new fields to store cached order recommendations:
```swift
struct SecurityDataSnapshot {
    // ... existing fields ...
    var recommendedSellOrders: [SalesCalcResultsRecord]?
    var recommendedBuyOrders: [BuyOrderRecord]?
    // ...
}
```

#### Updated hasData Method
Added handling for the new `orderRecommendations` group:
```swift
case .orderRecommendations:
    return recommendedSellOrders != nil && recommendedBuyOrders != nil
```

### 2. PositionDetailView.swift

#### Added Asynchronous Order Computation
After loading tax lots and price history, the system now automatically computes order recommendations:

```swift
// Compute and cache order recommendations once we have all the necessary data
if Task.isCancelled { return }

if groups.contains(.orderRecommendations) || (groups.contains(.taxLots) && groups.contains(.priceHistory)) {
    await computeAndCacheOrderRecommendations(symbol: symbol, localQuote: localQuote, localHistory: localHistory)
}
```

#### New computeAndCacheOrderRecommendations Method
This method:
1. Validates that all required data is available (ATR value, tax lots, shares available, current price)
2. Marks order recommendations as loading in the cache
3. Creates an OrderRecommendationService instance
4. Computes sell and buy orders in parallel using async/await
5. Caches the results in the SecurityDataSnapshot
6. Updates the UI with the cached snapshot

### 3. RecommendedOCOOrdersSection.swift

#### Updated updateOrdersIfReady Method
Added cache checking logic before computing new orders:

```swift
// First, check if we have cached order recommendations in the SecurityDataSnapshot
if let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol),
   snapshot.isLoaded(.orderRecommendations),
   let cachedSellOrders = snapshot.recommendedSellOrders,
   let cachedBuyOrders = snapshot.recommendedBuyOrders {
    print("✅ Using cached order recommendations from SecurityDataSnapshot for \(symbol)")
    
    viewModel.recommendedSellOrders = cachedSellOrders
    viewModel.recommendedBuyOrders = cachedBuyOrders
    viewModel.currentOrders = createAllOrders(sellOrders: cachedSellOrders, buyOrders: cachedBuyOrders)
    return
}
```

#### Added Helper Method
```swift
private func createAllOrders(sellOrders: [SalesCalcResultsRecord], buyOrders: [BuyOrderRecord]) -> [(String, Any)]
```

## Data Flow

### Before (On-Demand Computation)
1. User opens position details
2. System fetches price history, transactions, tax lots asynchronously
3. User navigates to OCO Orders tab
4. System computes order recommendations (blocking)
5. Orders displayed to user

### After (Async Caching)
1. User opens position details
2. System fetches price history, transactions, tax lots asynchronously
3. **Once tax lots and price history are loaded, system automatically computes order recommendations in background**
4. **Order recommendations cached in SecurityDataSnapshot**
5. User navigates to OCO Orders tab
6. **System instantly retrieves cached orders** (or falls back to computation if cache miss)
7. Orders displayed to user immediately

## Cache Lifecycle

1. **Loading**: When a position is opened, all security data groups (including orderRecommendations) are loaded asynchronously
2. **Caching**: Results are stored in SecurityDataSnapshot with LRU eviction (max 10 securities)
3. **Retrieval**: When OCO Orders tab is opened, cached recommendations are used if available
4. **Invalidation**: Cache is cleared when:
   - User forces a refresh
   - Symbol changes
   - Position is closed
   - LRU eviction occurs (when cache exceeds 10 entries)

## Memory Considerations

The cache maintains at most 10 SecurityDataSnapshot entries (LRU eviction), so memory usage is bounded. Each snapshot now includes:
- Price history
- Transactions
- Tax lots
- Order recommendations (sell and buy orders)

## Performance Impact

- **Initial Load**: Slightly longer as order recommendations are computed asynchronously in parallel with other data
- **Tab Switching**: Significantly faster - orders are retrieved from cache instead of being recomputed
- **Repeat Views**: Orders are reused across multiple views of the same security

## Backward Compatibility

- All changes are additive
- Existing functionality remains unchanged
- Default values ensure existing code continues to work
- Tests do not require updates due to optional fields

## Future Enhancements

Possible improvements:
1. Persist cache to disk for across-session persistence
2. Add cache expiration based on market hours
3. Implement cache warming for frequently viewed securities
4. Add telemetry to track cache hit rates

