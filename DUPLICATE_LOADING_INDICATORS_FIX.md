# Duplicate Loading Indicators Fix

## Problem
When clicking on the Transactions tab, two busy indicators (loading spinners) were appearing simultaneously.

## Root Cause

There were **two separate loading indicators** in the view hierarchy:

### 1. Global Loading Overlay (`LoadingStateModifier`)
- **Location**: Applied at `PositionDetailView` level (line 633)
- **Appearance**: Semi-transparent black overlay with white spinner
- **Trigger**: Shows when `loadingState.isLoading` is true
- **Purpose**: Indicates when ANY data group is loading (details, priceHistory, transactions, taxLots, etc.)
- **Code**: `LoadingState.swift` lines 76-82

```swift
if loadingState.isLoading {
    Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
    ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .white))
        .scaleEffect(1.5)
}
```

### 2. Local Transaction Loading Indicator
- **Location**: Inside `TransactionHistorySection` (line 155)
- **Appearance**: Blue spinner in content area
- **Trigger**: Originally showed when `isLoading` OR `isProcessing` was true
- **Purpose**: 
  - `isLoading`: Indicates API transaction data fetch
  - `isProcessing`: Indicates local transaction sorting/processing

```swift
// BEFORE (WRONG):
if isLoading || isProcessing {
    ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
        .scaleEffect(2.0, anchor: .center)
}
```

## Why Two Indicators Appeared

When clicking the Transactions tab while data was still loading:

1. `isLoadingTransactions` = true (API fetch in progress)
2. This triggered `loadingState.setLoading(true)` → **Global overlay appears**
3. `TransactionHistorySection` received `isLoading = true`
4. Local loading indicator also appeared → **Second spinner appears**
5. Result: **Two loading indicators on screen!**

## The Fix

**Modified `TransactionHistorySection.swift` (line 157)**:

Only show the local loading indicator for **local processing** (`isProcessing`), not for API loading (`isLoading`).

```swift
// AFTER (CORRECT):
// Only show local loading for processing (sorting), not for API loading
// API loading is already handled by the global loading overlay
if isProcessing {
    ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
        .scaleEffect(2.0, anchor: .center)
}
```

### Rationale

- **API Loading** (`isLoading`): The global overlay already indicates this clearly with a full-screen semi-transparent overlay
- **Local Processing** (`isProcessing`): This happens AFTER data is loaded, so the global overlay is gone. The local indicator is appropriate here to show sorting is in progress

## Before vs After

### Before (Two Indicators)
```
User clicks Transactions tab while loading
  ↓
isLoadingTransactions = true
  ↓
Global overlay: Shows ✅
Local indicator: Shows ✅
  ↓
Result: TWO spinners visible ❌
```

### After (One Indicator)
```
User clicks Transactions tab while loading
  ↓
isLoadingTransactions = true
  ↓
Global overlay: Shows ✅
Local indicator: Hidden (only shows for isProcessing) ✅
  ↓
Result: ONE spinner visible ✅
```

## Testing

1. **Test API Loading**:
   - Navigate to a position
   - Click Transactions tab while data is loading
   - **Expected**: Only global overlay loading indicator (no duplicate)

2. **Test Local Processing**:
   - Navigate to a position with transactions
   - Wait for data to fully load (global overlay disappears)
   - Click a column header to sort
   - **Expected**: Local loading indicator shows briefly during sorting

3. **Test No Loading**:
   - Navigate to a position with cached transaction data
   - Click Transactions tab
   - **Expected**: Transactions display immediately, no loading indicators

## Files Modified

- `ccSchwabManager/Views/HoldingsView/PositionDetailView/PositionDetailContent/TransactionsTab/TransactionHistory/TransactionHistorySection.swift`
  - Line 157: Changed condition from `if isLoading || isProcessing` to `if isProcessing`
  - Line 163: Updated condition to only check `!isLoading` instead of both

## Related Code

- **Global Loading State**: `ccSchwabManager/Models/LoadingState.swift`
- **Position Loading Logic**: `ccSchwabManager/Views/HoldingsView/PositionDetailView/PositionDetailView.swift` (line 102, 633)
- **Transaction Tab**: `ccSchwabManager/Views/HoldingsView/PositionDetailView/PositionDetailContent/TransactionsTab/TransactionsTab.swift`

## Future Considerations

This pattern should be applied to other tabs if they also have local loading indicators:
- Price History tab
- Sales Calc tab
- OCO tab
- Sequence tab

Each should only show local indicators for local processing, not for API data fetching (which is already handled by the global overlay).

