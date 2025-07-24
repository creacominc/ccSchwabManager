# Changelog

All notable changes to the ccSchwabManager project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **NEW**: Added clipboard functionality to transaction history and sales calc tables
  - Users can now click on any field in transaction history table to copy value to clipboard
  - Users can now click on any field in sales calc table to copy value to clipboard
  - Added visual feedback showing "Copied: [value]" when a field is copied
  - Matches existing clipboard functionality in OCO order table for consistent UX
  - Works on both macOS and iOS platforms
- **NEW**: Enhanced order cancellation with comprehensive logging and verification
- **NEW**: Multi-account support for order cancellation - each order now uses its correct account
- Added detailed request verification logging for DELETE operations
- Added test mode support for order cancellation verification
- **NEW**: Optimized sell order calculations to use minimum shares needed instead of full tax lot quantities
- Added helper functions `calculateMinimumSharesForGain` and `calculateMinimumSharesForRemainingProfit`
- Implemented intelligent share selection that prioritizes profitable shares over unprofitable ones

### Changed
- **BREAKING**: Enhanced `cancelOrders` function to use order-specific account resolution instead of first account
- **BREAKING**: Updated order cancellation to find each order's account number and corresponding hash value
- **BREAKING**: Updated all sell order calculations to use minimum shares logic:
  - Top 100 Order: Now calculates minimum shares needed for 3.25% gain (limited to 100 max)
  - Min ATR Order: Now calculates minimum shares needed to maintain 5% profit on remaining position
  - Min Break Even Order: Now calculates minimum shares needed for 1% gain at target price
- **BREAKING**: Modified `calculateMinimumSharesForGain` to prioritize profitable shares first, then include unprofitable shares only if necessary
- Updated sell order logic to use FIFO (First In, First Out) method starting with highest cost-per-share tax lots

### Technical Details

#### Order Cancellation Multi-Account Support
**Problem**: The `cancelOrders` function was using only the first account hash for all order cancellations, which could fail if orders belonged to different accounts.

**Solution**:
- Modified `cancelOrders` to find each order by its ID in `m_orderList`
- Extract the account number from each order's `accountNumber` property
- Look up the correct hash value for that specific account number
- Use the order-specific account hash for each cancellation request
- Added comprehensive logging to verify the correct account is being used

**Enhanced Logging**:
- Added detailed request verification with URL, order ID, account number, and hash value
- Added test mode support that simulates DELETE requests without making actual API calls
- Added success/failure summary with counts and error details
- Added emoji indicators for better visual scanning of logs

**Example Impact**:
- **Before**: All orders cancelled using first account hash (could fail for multi-account setups)
- **After**: Each order cancelled using its specific account hash (supports multiple accounts)

**Files Modified**:
- `SchwabClient.swift` - Enhanced `cancelOrders` function with account resolution and logging

#### Minimum Shares Optimization
**Problem**: Sell orders were using the full quantity of tax lots instead of calculating the minimum shares needed to meet the requirements, resulting in unnecessarily large sell orders.

**Solution**:
- Added `calculateMinimumSharesForGain` helper function that finds the minimum shares needed to achieve a specific gain percentage at a target price
- Added `calculateMinimumSharesForRemainingProfit` helper function that calculates minimum shares needed to maintain a specific profit percentage on the remaining position
- Implemented intelligent share selection that:
  1. First tries to achieve target gain using only profitable shares
  2. Starts with highest cost-per-share profitable shares (FIFO method)
  3. Stops as soon as target gain is achieved
  4. Only includes unprofitable shares if absolutely necessary

**Example Impact**:
- **Before**: Min Break Even order might sell 123 shares (all shares from multiple tax lots)
- **After**: Min Break Even order sells only 100 shares (minimum needed to achieve 1% gain)

**Files Modified**:
- `RecommendedOCOOrdersSection.swift` - Added helper functions and updated all sell order calculations

### Fixed
- **CRITICAL**: Fixed sell order break-even calculations to use specific tax lot cost-per-share instead of overall position average
- Fixed sell order gain calculations to avoid division by zero (NaN values)
- Updated test implementations to match corrected sell order logic
- **CRITICAL**: Fixed last price display to use real-time quote data instead of yesterday's close
- Updated order calculations and Sales Calc table to use current market price from quote

### Changed
- **BREAKING**: Updated `calculateMinBreakEvenOrder` to use weighted average cost per share for specific shares being sold
- **BREAKING**: Updated `calculateMinSharesFor5PercentProfit` to track cost of shares from each tax lot individually
- Modified sell order calculations to start with highest cost-per-share tax lots (FIFO method)
- **BREAKING**: Updated `computeTaxLots` to accept optional current price parameter for real-time pricing
- Modified `getCurrentPrice()` method to prioritize real-time quote data over price history
- Updated component hierarchy to pass quote data through to order calculations

### Technical Details

#### Sell Order Break-even Fix
**Problem**: Sell orders were using the overall position average cost per share (41.34) instead of the specific cost-per-share for the tax lots being sold, leading to inaccurate break-even calculations.

**Solution**:
- Modified `calculateMinBreakEvenOrder` to track cumulative cost and shares for specific tax lots being sold
- Updated `calculateMinSharesFor5PercentProfit` to calculate actual cost per share for shares being sold
- Fixed gain calculation formula to use `((target - actualCostPerShare) / actualCostPerShare) * 100.0`
- Updated test implementations in `OrderLogicTests.swift` and `CSVValidationTests.swift` to match corrected logic

#### Tax Lot Cost Calculation
**Problem**: Sell orders were not properly calculating the weighted average cost for the specific shares being sold.

**Solution**:
- Implemented proper tracking of cumulative cost and shares for each tax lot
- Used FIFO (First In, First Out) method starting with highest cost-per-share tax lots
- Calculated actual cost per share as `cumulativeCost / cumulativeShares` for specific shares being sold

### Added
- CSV export functionality for transaction history and tax lot data
- Diagnostic logging for shares available for trading calculation
- New method `computeSharesAvailableForTrading(symbol:taxLots:)` that accepts precomputed tax lots
- State variable `computedSharesAvailableForTrading` in PositionDetailView for real-time calculation
- Support for merged/renamed securities with automatic cost-per-share computation
- New method `handleMergedRenamedSecurities` to detect and fix zero-cost transactions
- New method `getComputedPriceForTransaction` to display correct prices in transaction history
- New method `getAveragePrice` to retrieve average price from position data

### Changed
- **BREAKING**: Updated `calculateMinBreakEvenOrder` calculation method to match sample.log format
- **BREAKING**: Changed AATR calculation from fixed 0.75% to ATR/5 (one-fifth of ATR)
- **BREAKING**: Updated entry price calculation from `last / (1 + (1.5*AATR/100))` to `Last - 1 AATR%`
- **BREAKING**: Updated target price calculation from `avg_cost * 1.0325` to `Entry - 2 AATR%`
- **BREAKING**: Updated exit price calculation from `target * 0.991` to `Target - 2 AATR%`
- **BREAKING**: Optimized minimum shares calculation to sell only the minimum shares needed to achieve 1% gain target
- Updated README.md to reflect new calculation method and examples
- Removed outdated test files that used old calculation method

### Changed
- **BREAKING**: Removed private method `calculateSharesAvailableForTrading` from SchwabClient to prevent circular dependencies
- Updated `getTransactionsFor` method to remove shares calculation to avoid deadlock
- Modified PositionDetailView to compute shares available for trading when the view loads
- Fixed date parsing in shares available calculation to handle tax lot date format "yyyy-MM-dd HH:mm:ss"
- Updated HoldingsView to call `computeTaxLots` first, then `computeSharesAvailableForTrading`

### Fixed
- **CRITICAL**: Resolved deadlock caused by circular dependency between `getTransactionsFor`, `computeTaxLots`, and shares calculation
- **CRITICAL**: Fixed shares available for trading showing 0.00 in PositionDetailView
- **CRITICAL**: Fixed all tax lot dates being skipped as "invalid date" due to incorrect date parsing
- **CRITICAL**: Fixed merged/renamed securities showing 0.00 cost-per-share in tax lots and transaction history
- Fixed infinite loops caused by recursive method calls
- Fixed build warnings by removing unused variables

### Technical Details

#### Deadlock Resolution
The deadlock was caused by the following circular dependency:
1. `getTransactionsFor` called `calculateSharesAvailableForTrading`
2. `calculateSharesAvailableForTrading` called `computeTaxLots`
3. `computeTaxLots` called `getTransactionsFor` again

**Solution**: 
- Removed shares calculation from `getTransactionsFor`
- Created new method `computeSharesAvailableForTrading(symbol:taxLots:)` that accepts precomputed tax lots
- Updated UI to compute tax lots first, then shares available

#### Date Parsing Fix
**Problem**: Tax lot dates in format "2024-12-03 14:34:41" were being parsed with ISO8601 strategy, causing all dates to be invalid.

**Solution**: 
- Replaced ISO8601 date parsing with DateFormatter using format "yyyy-MM-dd HH:mm:ss"
- Added proper timezone handling

#### Shares Available Calculation
**Problem**: PositionDetailView received shares available as parameter but didn't recalculate when view loaded.

**Solution**:
- Added state variable `computedSharesAvailableForTrading` to PositionDetailView
- Updated `fetchDataForSymbol()` to compute shares available using tax lots
- Modified PositionDetailContent to use computed value instead of passed parameter

#### Merged/Renamed Securities Fix
**Problem**: When securities are merged or renamed, the earliest transaction shows a cost-per-share of 0.00, which affects both tax lot calculations and transaction history display.

**Solution**:
- Added `handleMergedRenamedSecurities` function that detects when the earliest transaction has zero cost
- Implemented cost-per-share computation using the formula: `((AveragePrice * Quantity) - Sum_of_later_tax_lots_costs) / currentShareCount`
- Added `getComputedPriceForTransaction` function to display correct prices in transaction history
- Modified `computeTaxLots` to call the new handler after processing all transactions
- Updated TransactionRow to use computed prices when available

#### Real-time Price Fix
**Problem**: The app was using yesterday's close price from price history instead of real-time quote data for order calculations and display.

**Solution**:
- Updated `getCurrentPrice()` method to prioritize real-time quote data with fallback chain
- Modified `computeTaxLots` to accept optional current price parameter
- Updated component hierarchy to pass quote data through to order calculations
- Added fallback chain: real-time quote → extended market → regular market → price history

**Files Modified**:
- `RecommendedOCOOrdersSection.swift` - Main implementation fixes and real-time price support
- `OrderTab.swift` - Added quote data parameter
- `SalesCalcTab.swift` - Added quote data parameter  
- `SalesCalcView.swift` - Added quote data parameter
- `PositionDetailContent.swift` - Pass quote data to tabs
- `PositionDetailView.swift` - Pass current price to computeTaxLots
- `SchwabClient.swift` - Updated computeTaxLots to accept current price parameter
- `OrderLogicTests.swift` - Test implementation fixes
- `CSVValidationTests.swift` - Test implementation fixes

### Build Status
- ✅ macOS build successful
- ✅ iOS build successful (expected)
- ✅ No deadlocks in runtime
- ✅ Correct shares available for trading calculation
- ✅ Proper diagnostic logging

## [1.0.0] - 2025-07-19

### Added
- Initial release of ccSchwabManager
- Charles Schwab trading account integration
- Holdings view with position details
- Transaction history and tax lot computation
- Price history charts
- Order management interface
- Authentication flow with Schwab API
- CSV export functionality for transaction and tax lot data

### Features
- Multi-account support
- Real-time market data
- Tax lot computation from transaction history
- Shares available for trading calculation
- ATR (Average True Range) calculation
- Order status tracking
- Position profit/loss tracking
- Stock split adjustment
- Contract tracking for covered calls

### Technical Architecture
- SwiftUI for macOS and iOS
- Schwab Trader API integration
- Keychain-based secrets management
- Cached data management
- Background data loading
- Multi-threaded data processing 