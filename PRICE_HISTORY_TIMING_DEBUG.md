# Price History Chart Timing Issue - Debugging Guide

## Problem
The price history chart shows "No candles in price history data" even after data is loaded asynchronously.

## Changes Made

### 1. Simplified View Rendering (PriceHistorySection.swift)
- Removed complex internal state tracking
- Added `.task(id:)` modifier to react to data changes
- Added comprehensive debug logging to track view state

### 2. Added Debug Logging (PositionDetailView.swift)
- Log when price history is applied with candle count
- Log when loading state changes
- Track before/after candle counts

### 3. Simplified Chart Rendering (PriceHistoryChart.swift)
- Removed internal state that could cause sync issues
- Chart now directly uses the `candles` parameter

## Root Cause Analysis

The message "No candles in price history data" appears when:
- `priceHistory` is NOT nil
- BUT `priceHistory.candles` is empty array
- AND `isLoading` is false

This suggests one of:
1. The API is returning a CandleList with 0 candles
2. The data is being set to an empty CandleList during loading
3. The loading state is being cleared before data arrives

## Diagnostic Steps

### Check Console Logs
Run the app and navigate to a position's Price History tab. Look for these log messages:

```
📊 PositionDetailView: Applied price history - X candles for SYMBOL (was: Y candles)
📊 PositionDetailView: isLoadingPriceHistory changed from true to false
📊 PriceHistorySection: Showing loading spinner
📊 PriceHistorySection: Rendering chart with X candles for SYMBOL
📊 PriceHistorySection: Price history has empty candles for SYMBOL - isLoading: false
📊 PriceHistorySection: No price history available - isLoading: false
📊 PriceHistorySection.task: Data ID changed - X candles for SYMBOL
```

Also look for fetchPriceHistory logs:
```
=== fetchPriceHistory SYMBOL ===
fetchPriceHistory - Fetched X total candles, Y valid candles for SYMBOL
```

### Expected Flow
1. **Initial State**: No data, loading = true
   - Log: "📊 PriceHistorySection: Showing loading spinner"

2. **Data Fetch**: fetchPriceHistory called
   - Log: "=== fetchPriceHistory SYMBOL ==="
   - Log: "fetchPriceHistory - Fetched X total candles, Y valid candles for SYMBOL"

3. **Data Applied**: applySnapshot called with loaded data
   - Log: "📊 PositionDetailView: Applied price history - X candles for SYMBOL (was: 0 candles)"
   - Log: "📊 PositionDetailView: isLoadingPriceHistory changed from true to false"

4. **View Update**: Chart should render
   - Log: "📊 PriceHistorySection: Rendering chart with X candles for SYMBOL"
   - Log: "📊 PriceHistorySection.task: Data ID changed - X candles for SYMBOL"

### If You See Empty Candles
If you see: "📊 PriceHistorySection: Price history has empty candles for SYMBOL - isLoading: false"

Check:
1. Did fetchPriceHistory log "Fetched 0 total candles"?
   - If YES: API returned no data (check symbol validity, market hours, API issues)
   - If NO: Data was lost or cleared somewhere

2. Check the "Applied price history" log - does it show 0 candles or more?
   - If 0: The snapshot has empty data
   - If more: The view isn't updating (SwiftUI issue)

3. Is isLoading stuck at true?
   - Check if you see "isLoadingPriceHistory changed from true to false"

## Known Issue: CandleList is a Class
`CandleList` is a class (reference type), not a struct. This means:
- SwiftUI might not detect property changes
- However, we assign new CandleList objects, not modify existing ones
- The `.id()` modifiers force recreation when data changes

## Testing
To test if the fix works:
1. Build and run the app
2. Navigate to a position
3. Click on "Price History" tab
4. Observe:
   - Should see loading spinner briefly
   - Then chart should appear with data
5. Navigate to another position
6. Price History tab should clear and reload with new data

## If Issue Persists
Share the console logs (especially lines with 📊) to diagnose further.

