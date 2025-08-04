# ccSchwabManager

A cross-platform SwiftUI application for managing Charles Schwab trading accounts and positions. Supports both macOS and iOS platforms.

## Platform Support

- **macOS 15.2+**: Full desktop experience with native file system access
- **iOS 18.2+**: Mobile interface optimized for iPhone and iPad
- **visionOS 2.2+**: Compatible with Apple Vision Pro

## Quick Build

```bash
# Build for macOS
make build

# Build for iOS Simulator  
make build-ios

# Build for iOS Device
make build-ios-device
```

For detailed build instructions and iOS compilation fixes, see [`IOS_BUILD_FIXES.md`](IOS_BUILD_FIXES.md).

## Features

### Enhanced Buy Order Logic

The application now includes sophisticated buy order logic for positions that are below target gain:

- **Smart Target Price Calculation**: When a position is below the target gain (33% for most positions), the system calculates a target price that is 33% above the current price
- **Intelligent Entry Pricing**: Buy orders are set to enter at 1 ATR% below the target price, ensuring we don't buy until the position is sufficiently profitable
- **Precise Trailing Stops**: Trailing stop percentages are calculated based on the target price vs current price, ensuring accurate stop placement
- **Price Rounding**: All prices and percentages are rounded to the penny (2 decimal places) for precise order execution
- **Single vs OCO Orders**: The system intelligently creates single orders when only one order is selected, and OCO orders when multiple orders are selected

#### Buy Order Example
For a position with:
- Current price: $40.14
- Average cost: $43.77 (8% under)
- ATR: 4.76%
- Target gain: 33% (5 × ATR)

The system will:
- Set target price to $53.51 (33% above current price)
- Set entry price to $50.97 (1 ATR% below target)
- Set trailing stop to 33.31% (target vs current price)
- Round all values to the penny for precise execution

### CSV Export Functionality

The application now supports exporting transaction history and tax lot data to CSV files:

- **Transaction History Export**: Click the export button (📤) in the Date column header of the transaction history table to export all transactions for a specific symbol
- **Tax Lots Export**: Click the export button (📤) in the Open Date column header of the sales calc table to export all tax lot data for a specific symbol

#### Export File Naming Convention

Files are automatically named using the following format:
- `Transactions_<Symbol>_<Date>.csv` for transaction history exports
- `TaxLots_<Symbol>_<Date>.csv` for tax lot exports

Where:
- `<Symbol>` is the stock/security symbol (e.g., AAPL, MSFT)
- `<Date>` is the export date in YYYYMMDD format (e.g., 20250713)

#### Default Export Location

Files are saved to the user's Downloads folder by default, with a file dialog allowing users to choose a different location if desired.

#### CSV Format

**Transaction History CSV includes:**
- Date (formatted as YYYY-MM-DD HH:MM:SS)
- Type (Buy/Sell)
- Quantity
- Price
- Net Amount

**Tax Lots CSV includes:**
- Open Date
- Quantity
- Price
- Cost/Share
- Market Value
- Cost Basis
- Gain/Loss $
- Gain/Loss %

## Project Structure

- `Sources/`: Contains the source code of the project.
- `Tests/`: Contains the unit tests for the project.

## Prerequisites

- [Swift](https://swift.org/getting-started/) (Ensure you have the latest version installed)
- [Xcode](https://developer.apple.com/xcode/) (Recommended for Mac users)
- [Schwab Developer Account](https://developer.schwab.com) (Needed for the AppId and AppKey for your account)
- An investment account at [Schwab](https://www.schwab.com/client-home).

## Building the Project

1. Clone the repository:
    ```sh
    git clone https://github.com/creacominc/ccSchwabManager.git
    cd ccSchwabManager
    ```

2. Open the project in Xcode (if using Xcode):
    ```sh
    open ccSchwabManager.xcodeproj
    ```

3. Build the project:
    - In Xcode: Click on the Build button (or press `Cmd+B`).
    - From the command line:
        ```sh
        swift build
        ```

## Running the Tests

1. Open the project in Xcode (if using Xcode):
    ```sh
    open ccSchwabManager.xcodeproj
    ```

2. Run the tests:
    - In Xcode: Click on the Test button (or press `Cmd+U`).
    - From the command line:
        ```sh
        swift test
        ```

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request for review.

## License

This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0) license. See the [LICENSE](LICENSE) file for more details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes and improvements made to the project.

## Description
@Swift @SwiftUI @Swift Testing @Apple Design Tips @Xcode @GitHub Actions

I want to create an application that can run on both IOS and MacOS called ccSchwabMzanger.  This app will be used to view current holdings in multiple accounts at Schwab and suggest a buy and a sell order for each security as it is selected from a list.

You may use the existing classes as a guide or as they are.

The app should first load a Secrets object from the keychain using the readSecrets moethod in the KeychainManager.  This object, when stored in the keychain, is in JSON format and may contain the appId, appSecret, redirectUrl, code, session, accessToken, refreshToken, and a list of accountNumberHash objects.   Any of these values may be nil.  

If the secrets object is not found in the keychain or it does not have the appId or appSecret or redirectUrl, a dialog should prompt the user for the appId, appSecret, and redirectUrl.  Once those are entered, the secrets object should be stored in the keychain and the user should be presented with a button which will launch authentication through a link object which goes to the Schwab api login web page.  The authorization URL can be retrieved from  getAuthorizationUrl.   

There should be a text field in which the user can paste the results of the authentication.  When they do, the app should extract the 'code' from the pasted URL and save it in the secrets object as seen in handleAuthorization.

With the code saved in the secrets object and to the keychain, the app should fetch the account numbers as seen in fetchAccountNumbers then the account listings should be fetched as seen in fetchAccounts.  

The fetchAccounts method provides a list of symbols in the accounts which should be presented to the user in a table with the following fields taken from the Account, Position, and Instrument classes if they are available:  accountNumber, averagePrice, longQuantity, agedQuantity, marketValue, longOpenProfitLoss, assetType, symbol, description, closingPrice.

The table should be able to be filtered sorted on any of these columns.

There should be a way for the user to reset the secrets object partially (clearing all but the appId, appSecret, and callbackUrl) or fully.

In structuring the app, please use ccSchwabManager/ccSchwabManagerApp.swift as the main, ccSchwabManager/Views for all views including ccSchwabManager/Views/ContentView.swift, ccSchwabManager/DataTypes for all JSON data objects, ccSchwabManager/DataTypes/Enums for enums, ccSchwabManager/DataTypes/MarketData for MarketData request objects, ccSchwabManager/DataTypes/TraderAPI for account request objects, and ccSchwabManager/Utilities/Secrets for the secrets data type.

Unit test should use Swift Testing and be placed in the ccSchwabManagerTests folder with the other unit tests.  

Some sample data appears in json files in the tests folders.


## Workflows

This app has a few workflows.  Not all are completed yet but I will document the outline and what has been done so far.

### Account Workflow

Before anything else can be done, we need the account(s) and positions held.  

If the user has authorized the app, we will have the authorization key and refresh key and we will be able to update the refresh key and fetch the account numbers through the web api.
If that update or the account fetch fails, we need to get the user to authorize the app to access thier Schwab account(s).  This is done by prsenting a view with a button that launches a web browser for the Schwab authorization.  When they authorize, they are shown a page which indicates a failure.  This is because we do not yet have the app acting as a web server so that we can provide a valid redirect-url to get the access information directly into the app.  For now, the user needs to copy the URL provided from the web browser, paste it into the provided line in the view, and press the submit button.  This extracts a Code from the URL and uses this to get the access and refresh tokens and starts a thread to keep refreshing the access token.    

### Research Workflow

This workflow involves collecting the position summary, price history, transaction history, and the tax lots.

Unfortunately, I do not see a way to get tax lots from Schwab so I attempt to compute them from the transaction history.  To this we first attempt to find a point in time when we had zero shares by taking the current share count, adding the number of shares sold and subtracting the number of shares bought with each prior transaction until we run out of data or find a number close to zero.  Splits do not impact the finding of zero because the number of shares received in a stock split are added.  Once we find zero, we move forward through the transactions adding buys and, when we have a sale of N shares, we remove the N highest cost-per-share shares.  This only works if the account is set up to sell from the highest cost and will not work well for FIFO or any other tax strategy. It will behave particulary badly if the strategy changes during the holding period for a position.

Once the price history, transaction history, and tax lots are known, the tax lots are split adjusted by looking for share receive-and-distribute with a zero cost-per-share.  Once found, the number of shares held at that time is calculated and used to determine the split multiple which is then applied to all the prior share counts and cost-per-share values.  

Mergers and Renamed securities.  If the oldest transaction found looks like a split (being a receive-and-deliver type), it is likely a rename or a merger of ticker.  In this case, the cost will show as 0.00 and needs to be adjusted.  Since it is the oldest transaction, if it matches the currentShareCount, we can compute and assign the cost-per-share based on the currentShareCount and the difference between the costs for the later tax lots and the overall cost.  If the oldest transaction (the last one we are processing in computeTaxLots) is of type RECEIVE_AND_DELIVER, the cost-per-share should be updated from 0.00 as follows:
        received_cost_per_share = ((AveragePrice * Quantity) - Sum_of_later_tax_lots_costs) / currentShareCount


Tax lot information is used in the calculation of the number of shares avialable to sell.

### Order Workflow

To avoid needing to monitor the market and to avoid missing opportunities, the decisions for buying or selling are made ahead of time and submitted as 'trailing stop limit orders' with conditions so that they execute unsupervised.  Orders can have an entry and/or cancellation date/time as well as market conditions such as Bid Above and/or Ask Below.

A trailing stop limit order is computed to cause a sale at a certain target price and is made up of a few components:
- adjusted ATR (the AATR is the ATR limited - if needed - to the range of 1 to 7.  that is, if it is less than 1, it should be 1.  if it is more than 7 it should be 7.)
- the number of shares (Quantity)
- limit offset (% above or below the limit at which the order is entered, usually +/- 0.05%)
- stop offset (% above or below the last price at which the buy or sell should be submitted, usually 1 AATR)
- time in force (usually GTC or Good Til Cancelled)
- stop type (ask for sells, bid for buys)
- submit at (usually the next trading day at 09:40)
- cancel at (optional - used when the trade is related to a contract and matches the contract maturity)
- submit condition (market condition to be met for submition - could be ask below, bid above, or a study)
- cancel condition (same as submit condition but cancels the order)


#### Sell Order Workflow

  For all orders other than the top 100, the entry must be below the last price, the target must be below the entry, and the exit must be below the target.  

  Except for the Top-100 sell order, all sell orders are limited to the number of shares available to trade.  This is defined as the shares held for over 30 days less the number of shares in contracts.  For example, if we have two tax lots, one with 5 shares bought 29 days ago and one with 7 shares bought 32 days ago, only the 7 are available for trading (selling).  

  For the Top-100 sales, this rule should be used only to dictate how the sell order appears.  Top-100 sell orders should appear for any position for which we have 100 or more shares but should clearly indicate if this sell is not possible due to insufficient shares available.  The reason for this is that we can use this sell order as a guide for selling covered calls for which we need to know the cost-per-share of the top 100 shares.  


  Sell orders are entered for one or more of three reasons:
  - Minimum ATR-based standing sells are meant to protect against loss and provide at least 5% gain by selling a number of shares if the price falls by a certain multiple of the ATR.  The goal is to provide a large enough gap so that the sale does not happen too quickly allowing the stock may fall but rise again before hitting the limit.  For these orders the :
        - Adjusted ATR:  if then ATR < 1; then AATR = 1; else if ATR > 7; then AATR = 7; else AATR = ATR;
        - Submit condition: The ask price below the last price minus 1.5 * AATR.  ie. ASK <= (last_price / (1 + (1.5 * AATR/100)))
        - Target Price:  3.25% above the breakeven (avg cost per share) to account for wash sale cost adjustments.  target = avg_cost_per_share * 1.0325
        - Exit Price: 0.9% below the Target.  ASK <= (target * 0.991)
        - Quantity: the minimum number of shares it would take - when selling from the highest cost-per-share to lowest - to see at least a 5% return.  The minimum quantity would be 1 share.  The maximum would be the number of shares available to sell.  Shares will be presented as whole numbers and caculations that result in a fraction will be rounded up to the next whole value.  For a tax lot that results in more than a 5% gain, only the number of shares needed to achieve that 5% gain should be considered.  
        - Limit Offset: 0.05%
        - Stop Offset: 
        - Time in force: good until cancelled 
        - Stop type: ASK
        - Submit at: the next trading day at 09:40
        - Cancel at: not used
        - Cancel condition: not used
    To achive this, we can first ensure that the position is at least 6% and at least (3.5 * ATR) profitable.  If it is not, selling all the shares would still not meet the conditions.
    The Adjusted ATR is computed as 1.5 * the ATR for the position.
    The entry price is below the current (last) price by 1.5 * AATR  %.  ASK <= last / (1 + (1.5*AATR/100))
    The target price is 2.25% above the breakeven (avg cost per share).  target = avg_cost_per_share * 1.0225
    The exit price should be 0.9% below the target.   ASK <= target * 0.991


    - Minimum break-even standing sells are meant to trim some shares, removing just enough to get rid of the shares that are not currently profitable and enough of the profitable shares so that altogether we see a 1% gain.  It is the same as the Minimum ATR except that the gain target is 1%.
    To achive this, we can first ensure that the position is at least 1% profitable.  If it is not, selling all the shares would still not meet the conditions.
    The Adjusted ATR is ATR/5 (one-fifth of the ATR).
    The entry price is below the current (last) price by 1 AATR%.  Entry = Last - 1 AATR%
    The target price is below the entry price by 2 AATR%.  Target = Entry - 2 AATR%
    The exit price should be below the target price by 2 AATR%.  Cancel = Target - 2 AATR%

    - Top 100 sells are meant to provide the target price needed to profit from the sale of the top 100 shares.  This information may be used to set the minimum price for the sale of a call option.  The price may be above the last price. This sell order should show if there are at least 100 shares available.  If the target price is higher than the 95% of the last price, the sell should be shown in red.  Rather than computing the minimum shares, this sell order should be for the top 100.
    To achive this, we first need to compute the cost-per-share for the top 100 shares.  
    The target price is 3.25% above the breakeven (cost-per-share) to account for wash sale cost adjustments.  target = cost-per-share * 1.0325
    The Adjusted ATR is computed as 1.5 * 0.25 or 0.375.
    The entry price is one AATR above the target price.   target * (1 + (AATR/100))
    The exit price should be  0.9% below the target.   target * 0.991

#### Sell Order Pricing Examples

**Top 100 Sell Order Example:**
- Current price: $29.42
- Cost per share for top 100 shares: $41.96
- Target price: $41.96 × 1.0325 = $43.32 (3.25% above breakeven, accounting for wash sale adjustments)
- Adjusted ATR: 1.5 × 0.25% = 0.375%
- Entry price: $43.32 × (1 + 0.375/100) = $43.48 (Target + ATR above target)
- Exit price: $43.32 × 0.991 = $42.93 (0.9% below target)

**Min ATR Sell Order Example:**
- Current price: $29.42
- Average cost per share: $24.66
- Target price: $24.66 × 1.0325 = $25.46 (3.25% above breakeven, accounting for wash sale adjustments)
- Adjusted ATR: 1.5 × ATR% (varies by stock)
- Entry price: $25.46 × (1 + ATR/100) (Target + ATR above target)
- Exit price: $25.46 × 0.991 = $25.23 (0.9% below target)

**Min BE Sell Order Example:**
- Current price: $19.75
- ATR: 3.4%
- Adjusted ATR: 3.4% ÷ 5 = 0.68%
- Entry price: $19.75 × (1 - 0.68/100) = $19.62 (Last - 1 AATR%)
- Target price: $19.62 × (1 - 2×0.68/100) = $19.35 (Entry - 2 AATR%)
- Exit price: $19.35 × (1 - 2×0.68/100) = $19.09 (Target - 2 AATR%)

#### Buy Order Workflow

  The goal of the buy order workflow is to increase our holdings of positions that are profitable.  All positions should have standing buy orders if they are not performing so badly that we just want to sell them.  Orders should be structured so that they are submitted on or after a certain date and time and above (or in some cases below) a certain price.  The increase in holdings should be done slowly so that we never invest more than $500 a week in a security or the price of 1 share if it the cost-per-share exceeds $500.  The number of shares bought and the target buy price should be such that we can maintain at least a certain target percent gain.  
  
  The target percent gain depends on the ATR of the security.  The ATR indicates the volatility and how quickly the price could rise or fall.  The target precent gain should be the greater of 15% or 5 * ATR%.  If a security has a 2% ATR, the traget would be 15%.  If it has a 3% ATR, the target would be 21%.  For the first example, we would want to always have at least 15% gain on our current holdings. For the second, 21%.  If the current P/L% is less than the target gain, we should compute the price at which it would meet the target gain and use that (plus 1*ATR) for the order entry price.
  
  The order submission date/time is when the order should be submitted.  It should be at 09:40 local time at least 7 days since the last buy.  If the last buy was more than 7 days ago, the order can be submitted without a submit time/date which will cause it to start right away.  If the current local time is outside of trading hours, the order should be entered on the next trading day at least 10 minutes after market open (09:40).  
  
  The order entry price is the price at which a trailing stop limit order should be entered.  After the submission date/time, the order will wait for order condition which will be that the BID is at or above 1*ATR% over the price that represents the target percent gain.  If the cost-per-share is at $100 and the stock has a 1% ATR, the target gain would be 15% or $115.  One more ATR% would be $116.15.  The order entry condition would be that the BID >= $116.15.  
  
  The Trailing Stop for the order will be the ATR% of the security.
  
  The target buy price will be the order entry price plus the trailing stop (1 ATR%). To continue the above example, if the entry was at $116.15 and the ATR was 1%, the order would be to buy <N> shares submit at <date> 09:40 when BID >= $116.15  Trailing Stop = 1%.  Target buy price $117.31.
  
  The number of shares to buy will be:
  - the number of shares at the target buy price that would bring the P/L% down to the target percent gain.  
  - if the cost of that number of shares exceeds $500, the number of shares will be limited to the number of shares that can be bought for $500.
  - if the share price is over $500, the number of shares will be set to 1.
  
  The buy orders should be structured like the sell orders in the same table and with the same set of check boxes handled by the same submit button.  It should be clear that they are buy orders through the use of a different colour either of the text or the background and possibly by providing a small separator between the sell and buy orders.
  
  The description should be structured similar to the sell orders also.  Similar to:   Buy <shares> <Ticker> Submit <Date>-<Time> BID >= <entry price> TS = <ATR%> Target = <target buy price> 
  
  
