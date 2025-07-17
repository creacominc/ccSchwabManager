# ccSchwabManager

A macOS application for managing Charles Schwab trading accounts and positions.

## Features

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

## Description
@Swift @SwiftUI @Swift Testing @Apple Design Tips @Xcode @GitHub Actions

I want to create an application that can run on both IOS and MacOS called ccSchwabMzanger.  This app will be used to view current holdings in multiple accounts at Schwab and suggest a buy and a sell order for each security as it is selected from a list.

You may use the existing classes as a guide or as they are.

The app should first load a Secrets object from the keychain using the readSecrets moethod in the KeychainManager.  This object, when stored in the keychain, is in JSON format and may contain the appId, appSecret, redirectUrl, code, session, accessToken, refreshToken, and a list of accountNumberHash objects.   Any of these values may be nil.  

If the secrets object is not found in the keychain or it does not have the appId or appSecret or redirectUrl, a dialog should prompt the user for the appId, appSecret, and redirectUrl.  Once those are entered, the secrets object should be stored in the keychain and the user should be presented with a button which will launch authentication through a link object which goes to the Schwab api login web page.  The authorization URL can be retrieved from  getAuthorizationUrl.   

There should be a text field in which the user can paste the results of the authentication.  When they do, the app should extract the ‘code’ from the pasted URL and save it in the secrets object as seen in handleAuthorization.

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

Unfortunately, I do not see a way to get tax lots from Schwab so I attempt to compute them from the transaction history.  To do this we first attempt to find a point in time when we had zero shares by taking the current share count, adding the number of shares sold and subtracting the number of shares bought with each prior transaction until we run out of data or find a number close to zero.  Splits do not impact the finding of zero because the number of shares received in a stock split are added.  Once we find zero, we move forward through the transactions adding buys and, when we have a sale of N shares, we remove the N highest cost-per-share shares.  This only works if the account is set up to sell from the highest cost and will not work well for FIFO or any other tax strategy. It will behave particulary badly if the strategy changes during the holding period for a position.

Once the price history, transaction history, and tax lots are known, the tax lots are split adjusted by looking for share receive-and-distribute with a zero cost-per-share.  Once found, the number of shares held at that time is calculated and used to determine the split multiple which is then applied to all the prior share counts and cost-per-share values.

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

  Sell orders are entered for one or more of three reasons:
  - Minimum ATR-based standing sells are meant to protect against loss and provide at least 5% gain by selling a number of shares if the price falls by a certain multiple of the ATR.  The goal is to provide a large enough gap so that the sale does not happen too quickly allowing the stock may fall but rise again before hitting the limit.  For these orders the :
        - Adjusted ATR:  if then ATR < 1; then AATR = 1; else if ATR > 7; then AATR = 7; else AATR = ATR;
        - Submit condition: The ask price below the last price minus 1.5 * AATR.  ie. ASK <= (last_price / (1 + (1.5 * AATR/100)))
        - Target Price:  1.5 * AATR below the submit price.  ASK <= (submit / (1+(1.5*AATR/100)))
        - Exit Price: 1% below the Target.  ASK <= (target  / 1.01)
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
    The target prie is another 1.5*AATR below that.  ASK <= entry / (1 + (1.5*AATR/100))
    The exit price should be another 1% below the target.   ASK <= target / 1.01


    - Minimum break-even standing sells are meant to trim some shares, removing just enough to get rid of the shares that are not currently profitable and enough of the profitable shares so that altogether we see a 1% gain.  It is the same as the Minimum ATR except that the gain target is 1%.
    To achive this, we can first ensure that the position is at least 1% profitable.  If it is not, selling all the shares would still not meet the conditions.
    The Adjusted ATR is computed as 1.5 * 0.25 or 0.1667.
    The entry price is below the current (last) price by 1.5 * AATR  %.  ASK <= last / (1 + (1.5*AATR/100))
    The target prie is another 1.5*AATR below that.  ASK <= entry / (1 + (1.5*AATR/100))
    The exit price should be another 1% below the target.   ASK <= target / 1.01    

    - Top 100 sells are meant to provide the target price needed to profit from the sale of the top 100 shares.  This information may be used to set the minimum price for the sale of a call option.  The price may be above the last price. This sell order should show if there are at least 100 shares available.  If the target price is higher than the 95% of the last price, the sell should be shown in red.  Rather than computing the minimum shares, this sell order should be for the top 100.
    To achive this, we first need to compute the cost-per-share for the top 100 shares.  
    The target prie is 1% above the target.  target = cost-per-share * 1.01
    The Adjusted ATR is computed as 1.5 * 0.25 or 0.1667.
    The entry price is one AATR above the (last) price.   last / (1 + (AATR/100))
    The exit price should be  1% above the target.   target / 1.01


