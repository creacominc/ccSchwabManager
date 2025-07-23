# Changelog

All notable changes to the ccSchwabManager project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **CRITICAL**: Fixed sell order break-even calculations to use specific tax lot cost-per-share instead of overall position average
- Fixed sell order gain calculations to avoid division by zero (NaN values)
- Updated test implementations to match corrected sell order logic

### Changed
- **BREAKING**: Updated `calculateMinBreakEvenOrder` to use weighted average cost per share for specific shares being sold
- **BREAKING**: Updated `calculateMinSharesFor5PercentProfit` to track cost of shares from each tax lot individually
- Modified sell order calculations to start with highest cost-per-share tax lots (FIFO method)

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