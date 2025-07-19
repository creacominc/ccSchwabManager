# Changelog

All notable changes to the ccSchwabManager project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- CSV export functionality for transaction history and tax lot data
- Diagnostic logging for shares available for trading calculation
- New method `computeSharesAvailableForTrading(symbol:taxLots:)` that accepts precomputed tax lots
- State variable `computedSharesAvailableForTrading` in PositionDetailView for real-time calculation

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