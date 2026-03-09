# iPhone Performance Optimizations

## Overview
This document outlines performance optimizations specifically designed for iPhone and other mobile devices with limited memory, CPU, and network bandwidth.

## Current Performance Issues on iPhone

1. **Memory Constraints**: iPhone has 4-8GB RAM vs Mac's 16GB+
2. **Network Bandwidth**: Mobile networks are slower and less reliable
3. **Battery Life**: Aggressive prefetching drains battery
4. **CPU Power**: Less powerful processors need lighter workloads

## Recommended Optimizations

### 1. **Reduce Cache Size for iPhone** ⚡ HIGH IMPACT
**Current**: 10 securities cached in memory  
**Proposed**: 5 securities on iPhone, 10 on Mac

**Implementation**:
```swift
#if os(iOS)
private let maxCacheSize = 5
#else
private let maxCacheSize = 10
#endif
```

**Benefits**:
- Reduces memory footprint by ~50% on iPhone
- Still maintains good cache hit rate for recent securities
- Minimal impact on user experience

---

### 2. **Conditional Upfront Data Loading** ⚡ HIGH IMPACT
**Current**: Loads all data groups upfront (details, price history, transactions, tax lots, order recommendations)  
**Proposed**: On iPhone, load only critical groups upfront, defer others until tab is selected

**Implementation**:
```swift
#if os(iOS)
// iPhone: Load only critical groups upfront
let criticalGroups: [SecurityDataGroup] = [.details, .priceHistory]
let groupsToLoad = forceRefresh ? SecurityDataGroup.allCases : criticalGroups
#else
// Mac: Load everything upfront (current behavior)
let groupsToLoad = forceRefresh ? SecurityDataCacheManager.shared.allCases : SecurityDataGroup.allCases
#endif
```

**Benefits**:
- Reduces initial load time by 40-60%
- Saves network bandwidth
- Improves battery life
- Data still loads quickly when user clicks tabs (already cached or fast to fetch)

---

### 3. **Reduce Prefetch Aggressiveness** ⚡ MEDIUM IMPACT
**Current**: Prefetches 2 securities in each direction (N-2, N-1, N+1, N+2)  
**Proposed**: On iPhone, prefetch only 1 security in each direction (N-1, N+1)

**Implementation**:
```swift
#if os(iOS)
let prefetchRange = 1  // Only immediate adjacents
#else
let prefetchRange = 2  // Current behavior
#endif
```

**Benefits**:
- Reduces background network activity by 50%
- Saves battery life
- Still provides instant navigation for immediate next/previous
- Less memory usage

---

### 4. **Limit Price History Candles** ⚡ MEDIUM IMPACT
**Current**: Loads all available candles (could be 1000+)  
**Proposed**: Limit to last 200 candles on iPhone, unlimited on Mac

**Implementation**:
```swift
#if os(iOS)
let maxCandles = 200
#else
let maxCandles = Int.max
#endif

// After fetching price history
if let history = fetchedPriceHistory {
    let limitedHistory = CandleList(
        candles: Array(history.candles.suffix(maxCandles)),
        symbol: history.symbol,
        // ... other fields
    )
}
```

**Benefits**:
- Reduces memory usage per security
- Faster chart rendering
- Most recent 200 candles covers ~1 year of daily data (sufficient for most users)

---

### 5. **Add Disk Caching** ⚡ HIGH IMPACT
**Current**: Cache is memory-only, lost on app restart  
**Proposed**: Persist cache to disk, restore on app launch

**Implementation**:
- Use `UserDefaults` or `FileManager` to persist `SecurityDataSnapshot`
- Cache expiration: 1 hour for quotes, 24 hours for historical data
- Restore cache on app launch
- Background cleanup of expired entries

**Benefits**:
- Instant data display on app restart
- Reduces network calls significantly
- Better offline experience
- Minimal storage impact (~1-5MB per security)

---

### 6. **Paginate Transaction History** ⚡ MEDIUM IMPACT
**Current**: Loads all transactions at once  
**Proposed**: Load 50 transactions at a time, infinite scroll

**Implementation**:
```swift
@State private var displayedTransactions: [Transaction] = []
@State private var transactionPageSize = 50
@State private var hasMoreTransactions = true

private func loadMoreTransactions() {
    guard hasMoreTransactions else { return }
    let startIndex = displayedTransactions.count
    let endIndex = min(startIndex + transactionPageSize, allTransactions.count)
    displayedTransactions.append(contentsOf: allTransactions[startIndex..<endIndex])
    hasMoreTransactions = endIndex < allTransactions.count
}
```

**Benefits**:
- Faster initial render
- Lower memory usage for securities with many transactions
- Smooth scrolling experience

---

### 7. **Debounce Network Requests** ⚡ LOW IMPACT
**Current**: Some requests may fire rapidly  
**Proposed**: Add 100-200ms debounce for non-critical requests

**Benefits**:
- Reduces unnecessary API calls
- Better for battery life
- Already implemented for filter changes, could extend

---

### 8. **Optimize Image Loading** ⚡ LOW IMPACT (if applicable)
**Current**: N/A (no images found)  
**Proposed**: If images are added later, use lazy loading and caching

---

## Implementation Priority

### Phase 1 (Quick Wins - High Impact)
1. ✅ Reduce cache size for iPhone
2. ✅ Conditional upfront data loading
3. ✅ Reduce prefetch aggressiveness

### Phase 2 (Medium Effort - High Impact)
4. ✅ Add disk caching
5. ✅ Limit price history candles

### Phase 3 (More Effort - Medium Impact)
6. ✅ Paginate transaction history

## Expected Performance Improvements

### Memory Usage
- **Before**: ~50-100MB for 10 cached securities
- **After**: ~25-50MB for 5 cached securities
- **Improvement**: 50% reduction

### Initial Load Time
- **Before**: 2-5 seconds (all groups)
- **After**: 1-2 seconds (critical groups only)
- **Improvement**: 50-60% faster

### Network Usage
- **Before**: ~10-15 API calls per security (all groups + prefetch)
- **After**: ~5-8 API calls per security (critical groups + reduced prefetch)
- **Improvement**: 40-50% reduction

### Battery Life
- **Before**: Aggressive prefetching drains battery
- **After**: Reduced background activity
- **Improvement**: 20-30% better battery life

## Testing Recommendations

1. Test on physical iPhone devices (not just simulator)
2. Monitor memory usage with Instruments
3. Test on slow network conditions (3G simulation)
4. Measure battery drain during extended use
5. Verify cache hit rates remain acceptable

## Backward Compatibility

All optimizations use `#if os(iOS)` conditional compilation, so Mac behavior remains unchanged. This ensures:
- No performance regression on Mac
- iPhone gets optimized experience
- Single codebase maintained
