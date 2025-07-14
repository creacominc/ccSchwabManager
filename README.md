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




(updating just to test the CI/CD)
