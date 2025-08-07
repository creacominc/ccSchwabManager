# Changelog

All notable changes to the ccSchwabManager project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed
- **REMOVED**: Debug tab and related debugging functionality
  - Removed DebugLogView.swift file completely
  - Removed debug tab from main ContentView tab interface
  - Removed debugPrintOrderState() method from SchwabClient
  - Removed getSymbolsWithOrders() debug helper method from SchwabClient
  - Cleaned up commented debug calls in HoldingsView
  - Simplified user interface to focus on core functionality with just Holdings and Credentials tabs
  - Application now has a cleaner, more focused interface without debugging clutter

### Added
- **NEW**: Buy Sequence Orders for strategic position building
  - Implemented nested order structure where each order includes the next as a child
  - Added dynamic trailing stop calculation based on distance to minimum strike price:
    - Standard 5% trailing stop when minimum strike is ≤25% above current price
    - Conservative trailing stop (1/4 of percent difference less 4%) when minimum strike is >25% above current price
  - Added smart order filtering to only create orders with entry prices above current market price
  - Implemented maximum cost control ($1400 per order) and share limits (25 shares per order)
  - Added 6% price intervals between orders for systematic position building
  - Integrated minimum strike price from existing contracts as the highest target price
  - Added "Select All" button for easy order selection
  - Implemented proper nested order submission with TRIGGER and SINGLE order types
  - Added comprehensive logging and JSON preview for order verification
  - Enhanced UI with confirmation dialog showing order details and complete JSON
  - Fixed order sequence to ensure lowest-priced order is the outermost trigger
  - Removed debug messages from confirmation dialog for clean user experience
- **NEW**: Enhanced sell order logic with multiple order types and proper cost basis calculations
  - Added four different sell order types: Minimum Break-Even, +0.5ATR, +1.0ATR, and +1.5ATR
  - Implemented smart tax lot integration that iterates through available tax lots for optimal share allocation
  - Added accurate cost basis calculation using weighted average across multiple tax lots
  - Enhanced system to continue through tax lots until all four recommendations are met or until it runs out of tax lots
  - Fixed cost basis calculation to properly include shares from higher-cost tax lots (e.g., 4 shares from first tax lot + 8 shares from second tax lot)
  - Added helper function `calculateCostBasisForShares` to properly calculate weighted average cost basis across multiple tax lots
  - Updated additional sell order logic to use proper cost basis calculation instead of single tax lot cost
- **NEW**: Dynamic section sizing for Orders tab with intelligent space allocation
  - Implemented adaptive layout where Current Orders section shrinks to minimum height when empty
  - Added minimum height guarantee (80 points) for Current Orders to accommodate header and cancel button
  - Used GeometryReader and preference keys to measure content and allocate space dynamically
  - Enhanced user experience by reducing scrolling in Recommended Orders section when Current Orders doesn't need much space
  - Added preference keys (`CurrentOrdersHeightKey` and `RecommendedOrdersHeightKey`) to track section heights
  - Implemented responsive design that adapts automatically as content changes
- **NEW**: Performance optimizations for recommended orders interface
  - Implemented order calculation caching to prevent unnecessary recomputation when selecting checkboxes
  - Added state management to cache calculated orders and only update when underlying data changes
  - Enhanced UI responsiveness by eliminating expensive recalculations during checkbox interactions
  - Added smart data change detection using data hash comparison to trigger updates only when necessary
  - Orders are now only recalculated when symbol, quote data, or tax lot data actually changes
  - Improved user experience by making order selection fast and responsive
- **NEW**: Real-time price synchronization across all displays
  - Position summary "Last" price and tax lot table "Price" column now use identical real-time quote data
  - Eliminated price discrepancies between position summary and tax lot displays
  - Updated tax lot calculation to use real-time quote data instead of cached price history
  - Modified SalesCalcTableView to display current price from quote data instead of cached tax lot price
  - Added consistent price source hierarchy: quote data → extended quote → regular market price → price history fallback
  - Enhanced getCurrentPrice() function to prioritize real-time quote data over historical data
  - Updated computeTaxLots() to accept and use real-time current price parameter
  - Modified SalesCalcView to pass real-time price to table display components
- **NEW**: Enhanced buy order logic for positions below target gain
  - Implemented smart target price calculation that sets target to 33% above current price when position is below target gain
  - Added intelligent entry pricing that sets buy orders to enter at 1 ATR% below target price
  - Implemented precise trailing stop calculation based on target price vs current price
  - Added price rounding to the penny (2 decimal places) for all prices and percentages
  - Enhanced order creation to intelligently create single orders vs OCO orders based on selection count
  - Fixed trailing stop calculation to use current price instead of entry price for accurate percentages
  - Added comprehensive test coverage for new buy order logic including FCX example calculations
  - Updated order creation to include missing session and duration fields in JSON serialization
  - Fixed compiler warnings by removing unused variables
- **NEW**: Share validation for sell orders to ensure proper order sizing
  - Added validation to ensure sell orders never have less than 1 share
  - Added validation to ensure sell orders don't exceed available shares (except Top-100 orders)
  - Enhanced logging to show validation results with clear success/failure messages
  - Top-100 orders remain exempt from available shares validation as requested
  - Improved order reliability by preventing invalid share quantities

### Changed
- **ENHANCED**: Break-even calculation logic for profitable positions
  - When the highest cost-per-share tax lot is already profitable, the system now uses enhanced logic:
    - Target price is set to the average of cost-per-share and last price (instead of traditional break-even)
    - Shares to sell are set to 50% of the highest tax lot (providing better position management)
    - Entry price is set at 3/4 of the difference above cost-per-share (providing greater trailing stop room)
    - Cancel price is set at 1/4 above cost-per-share (25% above cost basis)
    - Trailing stop is calculated as 1/4 of the difference as percentage (dynamic based on profit potential)
  - Original break-even logic is maintained for non-profitable highest cost lots
  - This provides better risk management and larger trailing stops when the most expensive shares are already profitable
- **SIMPLIFIED**: OCO order descriptions to remove problematic timing information
  - Removed submit and cancel times from all order descriptions to eliminate timing-related issues
  - Sell orders no longer include "GTC SUBMIT AT {time}" in descriptions
  - Buy orders no longer include "Submit {date}" in descriptions
  - OCO orders are now cleaner and focus on core order parameters without timing constraints
  - This resolves issues with order submission timing and improves order clarity

### Fixed
- **FIXED**: Sales Calc table layout and sizing issues
  - Restored proper table sizing to maximize available space usage
  - Fixed height constraint to use 88% of available height while leaving space for "Copied:" message
  - Restored GeometryReader to ensure table properly fills available space
  - Table now displays at full size like other tables in the application
  - "Copied:" message remains visible at bottom when copy operations occur
- **FIXED**: iOS copy-to-clipboard functionality in SalesCalcTableView
  - Fixed state management issue where copyToClipboard functions weren't properly updating the copiedValue state
  - Moved copyToClipboard functions to TableContent struct with proper @Binding for state updates
  - Ensures copy-to-clipboard works consistently on both iOS and macOS platforms
  - Users can now click on any field in the sales calc table to copy values to clipboard
- **FIXED**: Min ATR sell order logic inconsistency
  - Updated Min ATR order to use consistent calculation methodology with other sell orders
  - Replaced fixed target calculation (3.25% above cost) with dynamic logic based on trailing stop
  - Now uses same trailing stop calculation as other orders (`atrValue / 5.0`)
  - Calculates target price using `entry / (1.0 + trailingStop / 100.0)` like additional orders
  - Uses same entry price calculation as Min Break Even (`currentPrice * (1.0 - adjustedATR / 100.0)`)
  - Maintains same exit price calculation as other sell orders
  - Fixes inconsistency where Min ATR had lower trailing stop but higher target than +1.5ATR orders
  - Ensures all sell orders follow consistent logic pattern for predictable behavior

### Added
- **NEW**: Added copy-to-clipboard functionality to HoldingsTable for consistent UX across all tables
  - Users can now click on any field in the main holdings table to copy value to clipboard
  - Added visual feedback showing "Copied: [value]" when a field is copied
  - Works on both macOS and iOS platforms
  - Matches existing clipboard functionality in other tables for consistent user experience
- **NEW**: Enhanced table row focus and visual feedback system
  - Added alternating row colors (zebra striping) for better readability
  - Improved hover effects and visual feedback for better user experience
  - Enhanced accessibility with better contrast and focus indicators
  - Added hover effects on macOS for immediate visual feedback when hovering over rows
  - Added selected row highlighting with accent color background
  - Implemented platform-specific hover functionality (macOS only) for cross-platform compatibility
  - Enhanced visual hierarchy with subtle background color variations
  - Applied consistent row focus behavior across all table views:
    - HoldingsTable: Main positions table with symbol, quantity, price, market value, P&L columns
    - SalesCalcTableView: Sales calculation results table
    - TransactionHistoryComponents: Transaction history table
- **NEW**: Enhanced Top-100 sell order logic for better contract pricing support
  - Top-100 orders now show for any position with over 100 shares (regardless of available shares)
  - Orders display accurate cost-per-share for the 100 most expensive shares
  - Added profitability indicators in order descriptions ("Top 100" vs "Top 100 - UNPROFITABLE")
  - Added visual distinction with purple background for unprofitable Top-100 orders
  - Enhanced logging to show target vs cost per share and entry vs current price comparisons
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
- Created new method `computeSharesAvailableForTrading(symbol:taxLots:)`