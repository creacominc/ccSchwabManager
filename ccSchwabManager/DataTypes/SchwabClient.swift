import Foundation
import AuthenticationServices
import Compression

// connection
private let schwabWeb           : String = "https://api.schwabapi.com"

// OAUTH API
private let oauthWeb            : String = "\(schwabWeb)/v1/oauth"
private let authorizationWeb    : String = "\(oauthWeb)/authorize"
private let accessTokenWeb      : String = "\(oauthWeb)/token"

// traderAPI
private let traderAPI           : String = "\(schwabWeb)/trader/v1"
private let accountWeb          : String = "\(traderAPI)/accounts"
private let accountNumbersWeb   : String = "\(accountWeb)/accountNumbers"
private let ordersWeb           : String = "\(traderAPI)/orders"

// marketAPI
private let marketdataAPI       : String = "\(schwabWeb)/marketdata/v1"
private let priceHistoryWeb     : String = "\(marketdataAPI)/pricehistory"



/**
   SchwabClient - interaction with Schwab web site.
    Members:
        - secrets : a Secrets object with the configuration for this connection.
    Methods:
        - getAuthorizationUrl : Executes the completion with the URL for logging into and authenticating the connection.
        - getAccessToken : given the URL returned by the authentication process, extract the code and get the access token.
 */
class SchwabClient
{
    static let shared = SchwabClient()
    private var m_secrets : Secrets
    private var m_selectedAccountName : String = "All"
    private var m_accounts : [AccountContent] = []
    private var m_refreshAccessToken_running : Bool = false
    private var m_transactionList : [Transaction] = []
    private var m_latestDateForSymbol : [String:Date] = [:]
    private var m_lastFilteredSymbol : String? = nil
    private var m_lastFilteredTransactions : [Transaction] = []
    private var m_orderList : [Order] = []
    private var m_todayStr : String
    private var m_dateOneYearAgoStr : String
    /**
     * dump the contents of this object for debugging.
     */
    func dump() -> String
    {
        var retVal : String = "\n\t   vvvvvvvvvvvvvvv"
        retVal += "\n\t  secrets: \(self.m_secrets.dump())"
        retVal += "\n\t  selectedAccountName: \(self.m_selectedAccountName)"
        for account in self.m_secrets.getAccountNumbers()
        {
            retVal += "\n\t     account: \(account)"
        }
        retVal += "\n\t   ^^^^^^^^^^^^^^^"
        return retVal
    }
    
    private init()
    {
        self.m_secrets = Secrets()
        // get current date/time in YYYY-MM-DDThh:mm:ss.000Z format
        m_todayStr = Date().formatted(.iso8601
            .year()
            .month()
            .day()
            .timeZone(separator: .omitted)
            .time(includingFractionalSeconds: true)
            .timeSeparator(.colon)
        ) // "2022-06-10T12:34:56.789Z"
        
        // get date one year ago
        var components = DateComponents()
        components.year = -1
        // format a string with the date one year ago.
        m_dateOneYearAgoStr = Calendar.current.date(byAdding: components, to: Date())!.formatted(.iso8601
            .year()
            .month()
            .day()
            .timeZone(separator: .omitted)
            .time(includingFractionalSeconds: true)
            .timeSeparator(.colon)
        )
    }
    
    func configure(with secrets: inout Secrets) {
        print( "=== configure - starting refresh thread. ===" )
        self.m_secrets = secrets
        self.refreshAccessToken()
        self.startRefreshAccessTokenThread()
    }
    
    public func hasAccounts() -> Bool
    {
        return self.m_accounts.count > 0
    }
    
    public func getAccounts() -> [AccountContent]
    {
        print( "=== getAccounts: accounts: \(self.m_accounts.count) ===" )
        return self.m_accounts
    }
    
    public func hasSymbols() -> Bool
    {
        print( "=== hasSymbols: accounts: \(self.m_accounts.count) ===" )
        var symbolCount : Int = 0
        for account in self.m_accounts
        {
            symbolCount += account.securitiesAccount?.positions.count ?? 0
        }
        print( "=== hasSymbols symbols: \(symbolCount) ===" )
        return (symbolCount > 0)
    }
    
    public func getSecrets() -> Secrets
    {
        return self.m_secrets
    }
    
    public func setSecrets( secrets: inout Secrets )
    {
        //print( "client setting secrets to: \(secrets.dump())")
        m_secrets = secrets
    }
    
    public func getSelectedAccountName() -> String
    {
        return self.m_selectedAccountName
    }
    
    public func setSelectedAccountName( name: String )
    {
        print( "setSelectedAccountName to \(name)" )
        self.m_selectedAccountName = name
    }
    
    /**
     * getAuthorizationUrl : Executes the completion with the URL for logging into and authenticating the connection.
     *
     */
    func getAuthorizationUrl(completion: @escaping (Result<URL, ErrorCodes>) -> Void)
    {
        print( "=== getAuthorizationUrl ===" )
        // provide the URL for authentication.
        let AUTHORIZE_URL : String  = "\(authorizationWeb)?client_id=\( self.m_secrets.appId )&redirect_uri=\( self.m_secrets.redirectUrl )"
        guard let url = URL( string: AUTHORIZE_URL ) else {
            completion(.failure(.invalidResponse))
            return
        }
        completion( .success( url ) )
        return
    }
    
    public func extractCodeFromURL( from url: String, completion: @escaping (Result<Void, ErrorCodes>) -> Void )
    {
        print( "=== extractCodeFromURL from \(url) ===" )
        // extract the code and session from the URL
        let urlComponents = URLComponents(string: url )!
        let queryItems = urlComponents.queryItems
        self.m_secrets.code = String( queryItems?.first(where: { $0.name == "code" })?.value ?? "" )
        self.m_secrets.session = String( queryItems?.first(where: { $0.name == "session" })?.value ?? "" )
        //print( "secrets with session: \(self.m_secrets.dump())" )
        if( KeychainManager.saveSecrets(secrets: &self.m_secrets) )
        {
            print( "extractCodeFromURL upated secrets with code and session. " )
            completion( .success( Void() ) )
        }
        else
        {
            print( "Failed to save secrets." )
            completion(.failure(ErrorCodes.failedToSaveSecrets))
        }
    }
    
    /**
     * getAccessToken : given the URL returned by the authentication process, extract the code and get the access token.
     *
     */
    func getAccessToken( completion: @escaping (Result<Void, ErrorCodes>) -> Void )
    {
        // Access Token Request
        print( "=== getAccessToken ===" )
        let url = URL( string: "\(accessTokenWeb)" )!
        print( "accessTokenUrl: \(url)" )
        var accessTokenRequest = URLRequest( url: url )
        accessTokenRequest.httpMethod = "POST"
        // headers
        let authStringUnencoded = String("\( self.m_secrets.appId ):\( self.m_secrets.appSecret )")
        let authStringEncoded = authStringUnencoded.data(using: .utf8)!.base64EncodedString()
        
        accessTokenRequest.setValue( "Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization" )
        accessTokenRequest.setValue( "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type" )
        // body
        accessTokenRequest.httpBody = String("grant_type=authorization_code&code=\( self.m_secrets.code )&redirect_uri=\( self.m_secrets.redirectUrl )").data(using: .utf8)!
        print( "Posting access token request:  \(accessTokenRequest)" )
        
        URLSession.shared.dataTask(with: accessTokenRequest)
        { data, response, error in
            guard let data = data, ( (error == nil) && ( response != nil ) )
            else
            {
                print( "Error: \( error?.localizedDescription ?? "Unknown error" )" )
                completion(.failure(ErrorCodes.notAuthenticated))
                return
            }
            
            let httpResponse : HTTPURLResponse = response as! HTTPURLResponse
            if( httpResponse.statusCode == 200 )
            {
                if let tokenDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                {
                    self.m_secrets.accessToken = ( tokenDict["access_token"] as? String ?? "" )
                    self.m_secrets.refreshToken = ( tokenDict["refresh_token"] as? String ?? "" )
                    if( !KeychainManager.saveSecrets(secrets: &self.m_secrets) )
                    {
                        print( "Failed to save secrets with access and refresh tokens." )
                        completion(.failure(ErrorCodes.failedToSaveSecrets))
                        return
                    }
                    completion( .success( Void() ) )
                }
                else
                {
                    print( "Failed to parse token response" )
                    completion(.failure(ErrorCodes.notAuthenticated))
                }
            }
            else
            {
                print( "Failed to fetch account numbers.   error: \(httpResponse.statusCode). \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))" )
                completion(.failure(ErrorCodes.notAuthenticated))
            }
        }.resume()
    }
    
    
    /**
     *  refreshAccessToken - create a thread to get the refresh token every 10 minutes.
     *
     *  A Trader API access token is valid for 30 minutes. A Trader API refresh token is valid for 7 days.
     *
     *  Step 2 was:
     *     curl -X POST https://api.schwabapi.com/v1/oauth/token \
     *     -H 'Authorization: Basic {BASE64_ENCODED_Client_ID:Client_Secret} \
     *     -H 'Content-Type: application/x-www-form-urlencoded' \
     *     -d 'grant_type=authorization_code&code={AUTHORIZATION_CODE_VALUE}&redirect_uri=https://example_url.com/callback_example'
     *
     *   Step 3:
     *       curl -X POST https://api.schwabapi.com/v1/oauth/token \
     *     -H 'Authorization: Basic {BASE64_ENCODED_Client_ID:Client_Secret} \
     *     -H 'Content-Type: application/x-www-form-urlencoded' \
     *     -d 'grant_type=refresh_token&refresh_token={REFRESH_TOKEN_GENERATED_FROM_PRIOR_STEP}
     *
     *  Example - Refresh Token Response
     *   {
     *      "expires_in": 1800, //Number of seconds access_token is valid for
     *      "token_type": "Bearer",
     *      "scope": "api",
     *      "refresh_token": "{REFRESH_TOKEN_HERE}", //Valid for 7 days
     *      "access_token": "{NEW_ACCESS_TOKEN_HERE}",//Valid for 30 minutes
     *      "id_token": "{JWT_HERE}"
     *    }
     *
     *
     */
    private func refreshAccessToken() {
        print("=== refreshAccessToken: Refreshing access token...")
        // Access Token Refresh Request
        guard let url = URL(string: "\(accessTokenWeb)") else {
            print("Invalid URL for refreshing access token")
            return
        }
        
        var refreshTokenRequest = URLRequest(url: url)
        refreshTokenRequest.httpMethod = "POST"
        
        // Headers
        let authStringUnencoded = "\(self.m_secrets.appId):\(self.m_secrets.appSecret)"
        let authStringEncoded = authStringUnencoded.data(using: .utf8)!.base64EncodedString()
        refreshTokenRequest.setValue("Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization")
        refreshTokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Body
        refreshTokenRequest.httpBody = "grant_type=refresh_token&refresh_token=\(self.m_secrets.refreshToken)".data(using: .utf8)!
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: refreshTokenRequest) { data, response, error in
            defer { semaphore.signal() }
            
            guard let data = data, error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to refresh access token. Error: \(error?.localizedDescription ?? "Unknown error")")
                //                print( "Error: \(error?.localizedDescription ?? "Unknown error" )" )
                //                print( "data: \(String(data: data ?? Data(), encoding: .utf8) ?? "No data")" )
                //                print( "response: \(String(describing: response))" )
                return
            }
            
            // Parse the response
            if let tokenDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                self.m_secrets.accessToken = (tokenDict["access_token"] as? String ?? "")
                self.m_secrets.refreshToken = (tokenDict["refresh_token"] as? String ?? "")
                
                if KeychainManager.saveSecrets(secrets: &self.m_secrets) {
                    print("Successfully refreshed and saved access token.")
                } else {
                    print("Failed to save refreshed tokens.")
                }
            } else {
                print("Failed to parse token response.")
            }
        }.resume()
    }
    
    private func startRefreshAccessTokenThread() {
        if (!m_refreshAccessToken_running) {
            m_refreshAccessToken_running = true
            let interval: TimeInterval = 15 * 60  // 15 minute interval
            DispatchQueue.global(qos: .background).async {
                while true {
                    self.refreshAccessToken()  // Call the updated method for a single refresh
                    Thread.sleep(forTimeInterval: interval)
                }
            }
        }
    }
    
    /**
     * fetch account numbers and hashes from schwab
     *
     *
     *[
     {
     "accountNumber": "...767",
     "hashValue": "980170564C529B2EF04942AA...."
     }
     ]
     *
     */
    func fetchAccountNumbers() async
    {
        print(" === fetchAccountNumbers ===  \(accountNumbersWeb)")
        guard let url = URL(string: accountNumbersWeb) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do
        {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as! HTTPURLResponse
            if( httpResponse.statusCode != 200 )
            {
                print( "Failed to fetch account numbers.  Status: \(httpResponse.statusCode).  Error: \(httpResponse.description)" )
                return
            }
            // print( "response: \(response)" )
            print( "data:  \(String(data: data, encoding: .utf8) ?? "Missing data" )" )
            
            let decoder = JSONDecoder()
            let accountNumberHashes = try decoder.decode([AccountNumberHash].self, from: data)
            print("accountNumberHashes: \(accountNumberHashes.count)")
            
            if !accountNumberHashes.isEmpty
            {
                await MainActor.run
                {
                    self.m_secrets.acountNumberHash = accountNumberHashes
                    if KeychainManager.saveSecrets(secrets: &self.m_secrets)
                    {
                        print("Save \(self.m_secrets.acountNumberHash.count)  account numbers")
                    }
                    else
                    {
                        print("Error saving account numbers")
                    }
                }
            } else {
                print("No account numbers returned")
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /**
     * fetchAccounts - get the account numbers and balances.
     */
    func fetchAccounts( retry : Bool = false ) async
    {
        print("=== fetchAccounts: selected: \(self.m_selectedAccountName) ===")
        var accountUrl = accountWeb
        if self.m_selectedAccountName != "All"
        {
            print( "fetching for account: \(self.m_selectedAccountName)" )
            accountUrl += "/\(self.m_selectedAccountName)"
        }
        accountUrl += "?fields=positions"
        
        guard let url = URL(string: accountUrl) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        
        do
        {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            if( httpResponse?.statusCode != 200 )
            {
                print("Failed to fetch accounts.  Status: \(httpResponse?.statusCode ?? -1),  response: \(String(describing: httpResponse))")
                // if the status is 401 and retry is true, call fetchAccounts again after refreshing the access token
                if( httpResponse?.statusCode == 401 && retry )
                {
                    print( "=== retrying fetchAccounts after refreshing access token ===" )
                    refreshAccessToken()
                    await fetchAccounts( retry : false )
                }
                else
                {
                    // decode data as a ServiceError
                    let decoder = JSONDecoder()
                    let serviceError : ServiceError = try decoder.decode(ServiceError.self, from: data)
                    print( "Failed to get accouts: \(serviceError.message ?? "no message")" )
                }
                return
            }
            
            let decoder = JSONDecoder()
            print( "=== decoding accounts ===" )
            m_accounts  = try decoder.decode([AccountContent].self, from: data)
            print( "  decoded \(m_accounts.count) accounts" )
            return
        }
        catch
        {
            print("Error: \(error.localizedDescription)")
            return
        }
    }
    
    
    /**
     * fettchPriceHistory  get the history of prices for all securities
     */
    func fetchPriceHistory( symbol : String ) async -> CandleList?
    {
        print("=== fetchPriceHistory  ===")
        
        var priceHistoryUrl = "\(priceHistoryWeb)"
        priceHistoryUrl += "?symbol=\(symbol)"
        
        /**
         * The chart period being requested.
         * Available values : day, month, year, ytd
         */
        priceHistoryUrl += "&periodType=year"
        
        /**
         *  The number of chart period types.
         *
         *  If the periodType is
         *  • day - valid values are 1, 2, 3, 4, 5, 10
         *  • month - valid values are 1, 2, 3, 6
         *  • year - valid values are 1, 2, 3, 5, 10, 15, 20
         *  • ytd - valid values are 1
         *
         *  If the period is not specified and the periodType is
         *  • day - default period is 10.
         *  • month - default period is 1.
         *  • year - default period is 1.
         *  • ytd - default period is 1.
         */
        priceHistoryUrl += "&period=1"
        
        
        /**
         *  The time frequencyType
         *
         *  If the periodType is
         *  • day - valid value is minute
         *  • month - valid values are daily, weekly
         *  • year - valid values are daily, weekly, monthly
         *  • ytd - valid values are daily, weekly
         *
         *  If frequencyType is not specified, default value depends on the periodType
         *  • day - defaulted to minute.
         *  • month - defaulted to weekly.
         *  • year - defaulted to monthly.
         *  • ytd - defaulted to weekly.
         *
         *  Available values : minute, daily, weekly, monthly
         */
        priceHistoryUrl += "&frequencyType=daily"
        
        /**
         *  The time frequency duration
         *
         *  If the frequencyType is
         *  • minute - valid values are 1, 5, 10, 15, 30
         *  • daily - valid value is 1
         *  • weekly - valid value is 1
         *  • monthly - valid value is 1
         *
         *  If frequency is not specified, default value is 1
         */
        //priceHistoryUrl += "&frequency=1"
        
        /**
         *  Need previous close price/date
         */
        //priceHistoryUrl += "&needPreviousClose=true"
        
        guard let url = URL( string: priceHistoryUrl ) else {
            print("fetchPriceHistory. Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        do {
            let ( data, response ) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            if( (nil == httpResponse) || (httpResponse?.statusCode != 200) )
            {
                print("fetchPriceHistory. Failed to fetch price history.  code = \(httpResponse?.statusCode ?? -1).  \(response)")
                return nil
            }
            
            let decoder = JSONDecoder()
            let candleList : CandleList  = try decoder.decode( CandleList.self, from: data )
            print( "Fetched \(candleList.candles.count) candles for \(symbol)" )
            // return the candleList assuming they arrived sorted.
            return candleList
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /**
     * compute ATR for given symbol
     */
    public func computeATR( symbol : String ) async -> Double
    {
        print("=== computeATR  ===")
        guard let priceHistory : CandleList  =  await self.fetchPriceHistory( symbol: symbol ) else {
            print("computeATR Failed to fetch price history.")
            return 0.0
        }
        var close : Double  = priceHistory.previousClose ?? 0.0
        var atr : Double  = 0.0
        /*
         * Compute the ATR as the average of the True Range.
         * The True Range is the maximum of absolute values of the High - Low, High - previous Close, and Low - previous Close
         */
        if priceHistory.candles.count > 1
        {
            let length : Int  =  min( priceHistory.candles.count, 21 )
            let startIndex : Int = priceHistory.candles.count - length
            //            print( "length \(length),  startIndex \(startIndex),  previousClose \(priceHistory.previousClose),  date \(priceHistory.previousCloseDate)" )
            for indx in 0..<length
            {
                let position = startIndex + indx
                let candle : Candle  = priceHistory.candles[position]
                let prevClose : Double  = if (0 == position) {priceHistory.previousClose ?? 0.0} else {priceHistory.candles[position-1].close ?? 0.0}
                let high : Double  = candle.high ?? 0.0
                let low  : Double  = candle.low ?? 0.0
                let tr : Double = max( abs( high - low ), abs( high - prevClose ), abs( low - prevClose ) )
                close = priceHistory.candles[position].close ?? 0.0
                atr = ( (atr * Double(indx)) + tr ) / Double(indx+1)
            }
        }
        // return the ATR as a percent.
        // return (atr * 0.78  / close * 100.0)
        return (atr * 0.89  / close * 100.0)
    }
    
    
    /**
     * fetchTransactionHistory - get the transactions for the last year for this holding.
     *
     * GET /accounts/{accountNumber}/transactions
     * Get all transactions information for a specific account.
     *      All transactions for a specific account. Maximum number of transactions in response is 3000. Maximum date range is 1 year.
     *
     * Parameters     Name    Description
     * accountNumber *     string     The encrypted ID of the account
     * startDate *     string     Specifies that no transactions entered before this time should be returned. Valid ISO-8601 formats are :
     *                    yyyy-MM-dd'T'HH:mm:ss.SSSZ . Example start date is '2024-03-28T21:10:42.000Z'. The 'endDate' must also be set.
     * endDate *     string     Specifies that no transactions entered after this time should be returned.Valid ISO-8601 formats are :
     *                    yyyy-MM-dd'T'HH:mm:ss.SSSZ. Example start date is '2024-05-10T21:10:42.000Z'. The 'startDate' must also be set.
     * symbol     string     It filters all the transaction activities based on the symbol specified. NOTE: If there is any special character in the symbol, please send th encoded value.
     * types *     string     Specifies that only transactions of this status should be returned.
     *
     *
     *
     *
     *
     *[
     {
     "activityId": 95512265692,
     "time": "2025-04-23T19:59:12+0000",
     "accountNumber": "88516767",
     "type": "TRADE",
     "status": "VALID",
     "subAccount": "CASH",
     "tradeDate": "2025-04-23T19:59:12+0000",
     "positionId": 2788793997,
     "orderId": 1003188442747,
     "netAmount": -164.85,
     "transferItems": [
     {
     "instrument": {
     "assetType": "EQUITY",
     "status": "ACTIVE",
     "symbol": "SFM",
     "instrumentId": 1806651,
     "closingPrice": 169.76,
     "type": "COMMON_STOCK"
     },
     "amount": 1,
     "cost": -164.85,
     "price": 164.85,
     "positionEffect": "OPENING"
     }
     ]
     }
     ]
     *
     *
     */
    public func fetchTransactionHistory( ) async
    {
        print("=== fetchTransactionHistory  ===")

        m_transactionList.removeAll(keepingCapacity: true)
        
        // fetch the transactions (optionally for the given symbol) from all accounts
        for accountNumberHash : AccountNumberHash in self.m_secrets.acountNumberHash {
            var transactionHistoryUrl = "\(accountWeb)/\(accountNumberHash.hashValue ?? "N/A")/transactions"
            transactionHistoryUrl += "?startDate=\(m_dateOneYearAgoStr)"
            transactionHistoryUrl += "&endDate=\(m_todayStr)"
            transactionHistoryUrl += "&types=TRADE"
            // print( "fetchTransactionHistory. URL = \(transactionHistoryUrl)" )
            guard let url = URL( string: transactionHistoryUrl ) else {
                print("fetchTransactionHistory. Invalid URL")
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            do {
                let ( data, response ) = try await URLSession.shared.data(for: request)
                let httpResponse = response as? HTTPURLResponse
                if( (nil == httpResponse) || (httpResponse?.statusCode != 200) )
                {
                    print("fetchTransactionHistory. Failed to fetch transaction history.  code = \(httpResponse?.statusCode ?? -1).  \(response)")
                    continue
                }
                // print the first 200 characters of the data response
                // print( " -------------- response --------------" )
                // print( (String(data: data, encoding: .utf8) ?? "No data").prefix(2400) )
                // print( " --------------          --------------" )
                
                let decoder = JSONDecoder()
                // append the decoded transactions to transactionList
                m_transactionList.append(contentsOf: try decoder.decode( [Transaction].self, from: data ) )
                continue
            } catch {
                print("Error: \(error.localizedDescription)")
                print("   detail:  \(error)")
                continue
            }
        } // end for each accountHash
        print( "Fetched \(m_transactionList.count) transactions for all symbols" )
        // sort by tradeDate
        m_transactionList.sort { $0.tradeDate ?? "0000" > $1.tradeDate ?? "0000" }
        //return transactionList.sorted { $0.tradeDate ?? "0000" > $1.tradeDate ?? "0000" }
        self.setLatestTradeDates()
    } // end of fetchTransactionHistory
    

    /**
     * getTransactions - return the m_transactionList.
     */
    public func getTransactionsFor( symbol: String? = nil ) -> [Transaction]
    {
        // to avoid filtering again or creating additional copies, save the lastFilteredSymbol and the lastFilteredTransactions
        if m_lastFilteredSymbol != symbol {
            m_lastFilteredSymbol = symbol
            m_lastFilteredTransactions =  m_transactionList.filter { transaction in
                // Check if the symbol is nil or if any transferItem in the transaction matches the symbol
                return symbol == nil || transaction.transferItems.contains { $0.instrument?.symbol == symbol }
            }
        }
        // return the transactionlist where the symbol matches what is provided
        return m_lastFilteredTransactions
        
    }

    private func setLatestTradeDates()
    {
        m_latestDateForSymbol.removeAll(keepingCapacity: true)
        // create a map of symbols to the most recent trade date
        for transaction in m_transactionList {
            for transferItem in transaction.transferItems {
                if let symbol = transferItem.instrument?.symbol {
                    // convert tradeDate string to a Date
                    var dateDte : Date = Date()
                    do {
                        dateDte = try Date( transaction.tradeDate ?? "1970-01-01", strategy: .iso8601.year().month().day() )
                        // print( "=== dateStr: \(dateStr), dateDte: \(dateDte) ==" )
                    }
                    catch {
                        print( "Error parsing date: \(error)" )
                        continue
                    }
                    // if the symbol is not in the dictionary, add it with the date.  otherwise compare the date and update only if newer
                    if m_latestDateForSymbol[symbol] == nil || dateDte > m_latestDateForSymbol[symbol]! {
                        m_latestDateForSymbol[symbol] = dateDte
                        // print( "Added or updated \(symbol) at \(dateDte) - latest date \(latestDateForSymbol[symbol] ?? Date())" )
                    }
                }
            }
        }
    }

    /**
     * getLatestTradeDate( for: String )  get the latest trade date for a given symbol.
     */
    public func getLatestTradeDate( for symbol: String ) -> String
    {
        return m_latestDateForSymbol[symbol]?.dateOnly() ?? "0000"
    }

    /**
     * fetchOrderHistory
     *
     * /orders
     *
     *Parameters
     Name    Description
     maxResults
     integer($int64)
     (query)
     The max number of orders to retrieve. Default is 3000.


     fromEnteredTime *
     string
     (query)
     Specifies that no orders entered before this time should be returned. Valid ISO-8601 formats are- yyyy-MM-dd'T'HH:mm:ss.SSSZ Date must be within 60 days from today's date. 'toEnteredTime' must also be set.


     toEnteredTime *
     string
     (query)
     Specifies that no orders entered after this time should be returned.Valid ISO-8601 formats are - yyyy-MM-dd'T'HH:mm:ss.SSSZ. 'fromEnteredTime' must also be set.


     status
     string
     (query)
     Specifies that only orders of this status should be returned.

     Available values : AWAITING_PARENT_ORDER, AWAITING_CONDITION, AWAITING_STOP_CONDITION, AWAITING_MANUAL_REVIEW, ACCEPTED, AWAITING_UR_OUT, PENDING_ACTIVATION, QUEUED, WORKING, REJECTED, PENDING_CANCEL, CANCELED, PENDING_REPLACE, REPLACED, FILLED, EXPIRED, NEW, AWAITING_RELEASE_TIME, PENDING_ACKNOWLEDGEMENT, PENDING_RECALL, UNKNOWN


    * alternate:  get orders for account:
     *    GET
     /accounts/{accountNumber}/orders
     Get all orders for a specific account.

     All orders for a specific account. Orders retrieved can be filtered based on input parameters below. Maximum date range is 1 year.

     Parameters
     Name    Description
     accountNumber *
     string
     (path)
     The encrypted ID of the account


     *
     *
     *
     * example response
     *[
     {
       "session": "NORMAL",
       "duration": "DAY",
       "orderType": "MARKET",
       "cancelTime": "2025-05-21T11:15:04.856Z",
       "complexOrderStrategyType": "NONE",
       "quantity": 0,
       "filledQuantity": 0,
       "remainingQuantity": 0,
       "requestedDestination": "INET",
       "destinationLinkName": "string",
       "releaseTime": "2025-05-21T11:15:04.856Z",
       "stopPrice": 0,
       "stopPriceLinkBasis": "MANUAL",
       "stopPriceLinkType": "VALUE",
       "stopPriceOffset": 0,
       "stopType": "STANDARD",
       "priceLinkBasis": "MANUAL",
       "priceLinkType": "VALUE",
       "price": 0,
       "taxLotMethod": "FIFO",
       "orderLegCollection": [
         {
           "orderLegType": "EQUITY",
           "legId": 0,
           "instrument": {
             "cusip": "string",
             "symbol": "string",
             "description": "string",
             "instrumentId": 0,
             "netChange": 0,
             "type": "SWEEP_VEHICLE"
           },
           "instruction": "BUY",
           "positionEffect": "OPENING",
           "quantity": 0,
           "quantityType": "ALL_SHARES",
           "divCapGains": "REINVEST",
           "toSymbol": "string"
         }
       ],
       "activationPrice": 0,
       "specialInstruction": "ALL_OR_NONE",
       "orderStrategyType": "SINGLE",
       "orderId": 0,
       "cancelable": false,
       "editable": false,
       "status": "AWAITING_PARENT_ORDER",
       "enteredTime": "2025-05-21T11:15:04.856Z",
       "closeTime": "2025-05-21T11:15:04.856Z",
       "tag": "string",
       "accountNumber": 0,
       "orderActivityCollection": [
         {
           "activityType": "EXECUTION",
           "executionType": "FILL",
           "quantity": 0,
           "orderRemainingQuantity": 0,
           "executionLegs": [
             {
               "legId": 0,
               "price": 0,
               "quantity": 0,
               "mismarkedQuantity": 0,
               "instrumentId": 0,
               "time": "2025-05-21T11:15:04.856Z"
             }
           ]
         }
       ],
       "replacingOrderCollection": [
         "string"
       ],
       "childOrderStrategies": [
         "string"
       ],
       "statusDescription": "string"
     }
   ]



     Orders


     GET
     /accounts/{accountNumber}/orders
     Get all orders for a specific account.


     POST
     /accounts/{accountNumber}/orders
     Place order for a specific account.


     GET
     /accounts/{accountNumber}/orders/{orderId}
     Get a specific order by its ID, for a specific account


     DELETE
     /accounts/{accountNumber}/orders/{orderId}
     Cancel an order for a specific account


     PUT
     /accounts/{accountNumber}/orders/{orderId}
     Replace order for a specific account


     GET
     /orders
     Get all orders for all accounts


     POST
     /accounts/{accountNumber}/previewOrder
     Preview order for a specific account. **Coming Soon**.



     */
    public func fetchOrderHistory( retry : Bool = false ) async
    {
        print("=== fetchOrderHistory  ===")

        m_orderList.removeAll(keepingCapacity: true)
        // get current date/time in YYYY-MM-DDThh:mm:ss.000Z format
        let todayStr : String = Date().formatted(.iso8601
            .year()
            .month()
            .day()
            .timeZone(separator: .omitted)
            .time(includingFractionalSeconds: true)
            .timeSeparator(.colon)
        ) // "2022-06-10T12:34:56.789Z"

        // get date one year ago
        var components = DateComponents()
        components.year = -1
        // format a string with the date one year ago.
        let dateOneYearAgoStr : String = Calendar.current.date(byAdding: components, to: Date())!.formatted(.iso8601
            .year()
            .month()
            .day()
            .timeZone(separator: .omitted)
            .time(includingFractionalSeconds: true)
            .timeSeparator(.colon)
        )
        
        // fetch the orders from all accounts
        var orderHistoryUrl = "\(ordersWeb)"
        orderHistoryUrl += "?fromEnteredTime=\(dateOneYearAgoStr)"
        orderHistoryUrl += "&toEnteredTime=\(todayStr)"
        /**
         * consider adding status: AWAITING_PARENT_ORDER, AWAITING_CONDITION, AWAITING_STOP_CONDITION, AWAITING_MANUAL_REVIEW, ACCEPTED, AWAITING_UR_OUT, PENDING_ACTIVATION, QUEUED, WORKING, REJECTED, PENDING_CANCEL, CANCELED, PENDING_REPLACE, REPLACED, FILLED, EXPIRED, NEW, AWAITING_RELEASE_TIME, PENDING_ACKNOWLEDGEMENT, PENDING_RECALL, UNKNOWN
         */

        // print( "fetchOrderHistory. URL = \(orderHistoryUrl)" )
        guard let url = URL( string: orderHistoryUrl ) else {
            print("fetchOrderHistory. Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        do {
            let ( data, response ) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            if( httpResponse?.statusCode != 200 )
            {
                print("Failed to orders.  Status: \(httpResponse?.statusCode ?? -1),  response: \(String(describing: httpResponse))")
                // if the status is 401 and retry is true, call fetchAccounts again after refreshing the access token
                if( httpResponse?.statusCode == 401 && retry )
                {
                    print( "=== retrying fetchOrderHistory after refreshing access token ===" )
                    refreshAccessToken()
                    await fetchOrderHistory( retry : false )
                }
                else
                {
                    // decode data as a ServiceError
                    let decoder = JSONDecoder()
                    let serviceError : ServiceError = try decoder.decode(ServiceError.self, from: data)
                    print( "Failed to get orders: \(serviceError.message ?? "no message")" )
                }
                return
            }
//            // print the first 200 characters of the data response
//            print( " -------------- response --------------" )
//            print( (String(data: data, encoding: .utf8) ?? "No data").prefix(2400) )
//            print( " --------------          --------------" )

            let decoder = JSONDecoder()
            // append the decoded transactions to transactionList
            m_orderList.append(contentsOf: try decoder.decode( [Order].self, from: data ) )
        } catch {
            print("Error: \(error.localizedDescription)")
            print("   detail:  \(error)")
        }
        print( "Fetched \(m_orderList.count) orders for all accounts" )
        return
    }
} // SchwabClient
