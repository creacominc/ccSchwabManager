# Fix: Clear Stale Data When Switching Securities

## Problem

When navigating between securities (e.g., clicking the Next/Previous button), some data from the previous security would remain visible on screen until new data was downloaded. For example:

- **Symptom**: Click "Next" button → ticker symbol updates immediately → but "Available" shares still shows the old value until new data loads
- **Root Cause**: State variables retained old values when switching securities, only getting updated when new data arrived

This created a confusing UX where partially stale data was displayed during the loading transition.

## Solution

Added a `clearAllData()` method that immediately clears all data-related state variables when switching securities, ensuring users never see stale values from the previous security.

## Changes Made

### 1. Added `clearAllData()` Method

```swift
@MainActor
private func clearAllData() {
    // Clear all data-related state to prevent showing stale values when switching securities
    priceHistory = nil
    transactions = []
    quoteData = nil
    computedATRValue = 0.0
    taxLotData = []
    computedSharesAvailableForTrading = 0.0
    loadStates = [:]
    isLoadingPriceHistory = false
    isLoadingTransactions = false
    isLoadingTaxLots = false
}
```

This method clears:
- `priceHistory`: Chart data
- `transactions`: Transaction history
- `quoteData`: Real-time quote information
- `computedATRValue`: Average True Range calculation
- `taxLotData`: Tax lot information
- `computedSharesAvailableForTrading`: **The "Available" value that was showing stale data**
- `loadStates`: Loading state for each data group
- Loading flags for each data type

### 2. Call `clearAllData()` at Start of `fetchDataForSymbol()`

```swift
private func fetchDataForSymbol(forceRefresh: Bool = false) {
    guard let symbol = position.instrument?.symbol else {
        AppLogger.shared.debug("PositionDetailView: No symbol found for position")
        return
    }

    AppLogger.shared.debug("PositionDetailView: Fetching data for symbol \(symbol)")

    dataLoadTask?.cancel()
    
    // Clear all old data immediately to prevent showing stale values
    clearAllData()  // ← NEW: Clear everything first

    if forceRefresh {
        SecurityDataCacheManager.shared.remove(symbol: symbol)
    }

    let cachedSnapshot = SecurityDataCacheManager.shared.snapshot(for: symbol)
    // ... rest of method
}
```

### 3. Removed Redundant Clearing Code

Removed conditional clearing code that was later in the method:

```swift
// REMOVED (now redundant):
if groupsToLoad.contains(.priceHistory) {
    priceHistory = nil
}
if groupsToLoad.contains(.transactions) {
    transactions = []
}
if groupsToLoad.contains(.taxLots) {
    taxLotData = []
}
```

Since we now clear everything upfront, these conditional clears are unnecessary.

## Behavior Changes

### Before Fix

1. User clicks "Next" button
2. Symbol updates: `AAPL` → `TSLA`
3. Old data persists on screen:
   - **Available**: `145.0` (still showing AAPL's value)
   - ATR: `1.5%` (still showing AAPL's value)
   - Tax Lots: showing AAPL's lots
4. New data starts loading...
5. Each field updates individually as new data arrives
6. **Result**: Confusing mix of old and new data during transition

### After Fix

1. User clicks "Next" button
2. **All data cleared immediately** (fields show empty/zero state)
3. Symbol updates: `AAPL` → `TSLA`
4. New data loads and populates fields
5. **Result**: Clean transition with no stale data

## User Experience Impact

✅ **No more stale data**: Users will never see incorrect values from a different security  
✅ **Clear loading state**: Empty/zero values clearly indicate data is loading  
✅ **Consistent behavior**: All data clears simultaneously when switching securities  
✅ **Cached data still fast**: When cached data exists, it populates immediately after clearing

## Technical Notes

- The `clearAllData()` method is marked `@MainActor` to ensure it runs on the main thread
- Clearing happens before checking the cache, so even cached data goes through a clear → apply cycle
- This ensures consistency: every security switch has the same clear → load → display flow
- Loading flags are also reset to prevent showing stale "loading" indicators

## Files Modified

- `ccSchwabManager/Views/HoldingsView/PositionDetailView/PositionDetailView.swift`
  - Added `clearAllData()` method (lines 40-53)
  - Call `clearAllData()` at start of `fetchDataForSymbol()` (line 104)
  - Removed redundant conditional clearing code (lines 132-140 removed)

## Testing

✅ Build successful (exit code 0)  
✅ No linter errors  
✅ All existing tests pass  
✅ No breaking changes  

## Related Issues

This fix complements the OCO order caching implementation, ensuring that when cached order recommendations are available, they populate into a clean state rather than mixing with stale data from the previous security.

