# Price History Chart Blank Issue - ROOT CAUSE AND FIX

## Problem Summary
The price history chart was showing "No candles in price history data" even though data was successfully loaded from the API.

## Root Cause

### The Issue
`CandleList` is defined as a **class** (reference type) in Swift, not a struct (value type).

When `SchwabClient.fetchPriceHistory()` returns a `CandleList`, it returns a **reference** to the cached object stored in `m_lastFilteredPriceHistory`. Multiple callers share the same object.

### The Sequence That Caused the Bug

1. **User views position TATT**:
   - `fetchPriceHistory("TATT")` is called
   - API returns 251 candles
   - Stored in `m_lastFilteredPriceHistory` (reference)
   - View receives and displays this reference: `priceHistory = m_lastFilteredPriceHistory`

2. **Prefetching kicks in for AVAV** (background operation):
   - `fetchPriceHistory("AVAV")` is called
   - Line 1026 executes: `m_lastFilteredPriceHistory?.candles.removeAll(keepingCapacity: true)`
   - This **mutates** the candles array to empty

3. **View's data is now corrupted**:
   - The view's `priceHistory` variable points to the **same object**
   - When AVAV cleared the candles array, it cleared TATT's data too!
   - View now shows 0 candles for TATT

### Evidence from Logs
```
[06:48:40] fetchPriceHistory - Fetched 251 total candles for TATT
[06:48:40] Applied price history - 251 candles for TATT
[06:48:44] ✅ Basic prefetch complete for AVAV
[06:48:46] Price history has empty candles for TATT - 0 candles
```

The data was corrupted between when TATT loaded (06:48:40) and when AVAV was prefetched (06:48:44).

## The Fix

Modified `SchwabClient.fetchPriceHistory()` to return a **defensive copy** instead of the cached reference.

### Changes Made

**File**: `ccSchwabManager/DataTypes/SchwabClient.swift`

**Three locations where CandleList is returned now create a copy:**

1. **Early cache return** (line ~980):
```swift
// OLD: return m_lastFilteredPriceHistory
// NEW: Return a copy
return CandleList(
    candles: cached.candles,
    empty: cached.empty,
    previousClose: cached.previousClose,
    previousCloseDate: cached.previousCloseDate,
    previousCloseDateISO8601: cached.previousCloseDateISO8601,
    symbol: cached.symbol
)
```

2. **Cache return after lock** (line ~1012):
```swift
// Same copy logic
```

3. **Return after successful fetch** (line ~1111):
```swift
// Return a copy to prevent mutation issues when this is called again for a different symbol
return CandleList(
    candles: candleList.candles,
    ...
)
```

### Why This Works

- Each caller now gets their **own independent copy** of the CandleList
- When `fetchPriceHistory()` is called again and clears the internal cache, it doesn't affect previously returned copies
- Views can hold their data without worrying about external mutations

## Alternative Solutions Considered

### 1. Make CandleList a struct (not chosen)
**Pros**: Swift structs are copy-on-write, would prevent this entire class of bugs
**Cons**: 
- Large refactoring across the codebase
- CandleList conforms to `Codable` and `Identifiable`, might have issues
- Breaks API contract if other code relies on reference semantics

### 2. Don't mutate the cached object (not chosen)
**Pros**: Would fix the immediate issue
**Cons**:
- Line 1026 (`m_lastFilteredPriceHistory?.candles.removeAll()`) is there for a reason
- Might cause memory issues if old data isn't cleared

### 3. Defensive copying (chosen) ✅
**Pros**:
- Minimal code change
- Fixes the root cause
- Maintains existing API contract
- No memory leaks
**Cons**:
- Small performance overhead (copying arrays)
- But: This is acceptable for price history data which isn't massive

## Testing

1. Run the app
2. Navigate to any position
3. Click "Price History" tab
4. Chart should display with data (not blank)
5. Navigate to another position  
6. Previous position's chart should remain intact
7. Background prefetching should not corrupt visible data

## Performance Impact

- **Negligible**: Copying ~250 candles is fast
- Only happens on cache hits/misses, not on every render
- Trade-off: Small memory/CPU cost for correctness

## Related Files Modified

- `ccSchwabManager/DataTypes/SchwabClient.swift` - Added defensive copying
- `ccSchwabManager/Views/HoldingsView/PositionDetailView/PositionDetailView.swift` - Added debug logging
- `ccSchwabManager/Views/HoldingsView/PositionDetailView/PositionDetailContent/PriceHistoryTab/PriceHistorySection.swift` - Added debug logging
- `PRICE_HISTORY_TIMING_DEBUG.md` - Debugging guide (can be removed)

## Lessons Learned

1. **Reference types can cause subtle bugs** when shared between components
2. **Defensive copying** is a valid pattern for protecting against external mutations
3. **Comprehensive logging** was essential to diagnose this issue
4. **Background operations** (like prefetching) can have surprising side effects on foreground data

