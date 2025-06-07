import Foundation
import AuthenticationServices
import Compression

// Import the LoadingStateDelegate protocol
@_exported import struct Foundation.URL
@_exported import class Foundation.URLSession
@_exported import class Foundation.JSONDecoder
@_exported import class Foundation.NSError
@_exported import var Foundation.NSLocalizedDescriptionKey

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
    private let maxQuarterDelta : Int = 8
    private let requestTimeout : TimeInterval = 30
    static let shared = SchwabClient()
    var loadingDelegate: LoadingStateDelegate?
    private var m_secrets : Secrets
    private var m_quarterDelta : Int = 0
    private var m_selectedAccountName : String = "All"
    private var m_accounts : [AccountContent] = []
    private var m_refreshAccessToken_running : Bool = false
    private var m_latestDateForSymbol : [String:Date] = [:]
    private var m_symbolsWithOrders: Set<String> = []
    private var m_lastFilteredTransactionSymbol : String? = nil
    private var m_lastFilteredTaxLotSymbol : String? = nil
    private var m_transactionList : [Transaction] = []
    private var m_lastFilteredTransactions : [Transaction] = []
    private var m_lastfilteredTransactionsYears : Int = 0
    private var m_lastFilteredPositionRecords : [SalesCalcPositionsRecord] = []
    private var m_orderList : [Order] = []

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
    }

    func getDateNQuartersAgoStr( quarterDelta : Int ) -> String
    {
        // get date one year ago
        var components = DateComponents()
        components.month = -quarterDelta * 3
        // format a string with the date one year ago.
        return Calendar.current.date(byAdding: components, to: Date())!.formatted(.iso8601
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

    public func getShareCount( symbol: String ) -> Double
    {
        print( "=== getShareCount symbol: \(symbol) ===" )
        var shareCount : Double = 0.0
        /** @TODO:  review.  I am sure this can be more efficient.  */
        for account in self.m_accounts
        {
            if let positions = account.securitiesAccount?.positions
            {
                for position in positions
                {
                    if position.instrument?.symbol == symbol
                    {
                        shareCount = position.settledLongQuantity ?? 0.0
                        return shareCount
                    }
                }
            }
        }
        return shareCount
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
        // set a 10 second timeout on this request
        accessTokenRequest.timeoutInterval = self.requestTimeout
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
        // set a 10 second timeout on this request
        refreshTokenRequest.timeoutInterval = self.requestTimeout
        refreshTokenRequest.httpMethod = "POST"
        
        // Headers
        let authStringUnencoded = "\(self.m_secrets.appId):\(self.m_secrets.appSecret)"
        let authStringEncoded = authStringUnencoded.data(using: .utf8)!.base64EncodedString()
        refreshTokenRequest.setValue("Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization")
        refreshTokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Body
        refreshTokenRequest.httpBody = "grant_type=refresh_token&refresh_token=\(self.m_secrets.refreshToken)".data(using: .utf8)!
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: refreshTokenRequest) { [weak self] data, response, error in
            defer { semaphore.signal() }
            do {
                if let data = data {
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, error == nil {
                        // Parse the response
                        if let tokenDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            self?.m_secrets.accessToken = (tokenDict["access_token"] as? String ?? "")
                            self?.m_secrets.refreshToken = (tokenDict["refresh_token"] as? String ?? "")
                            
                            if KeychainManager.saveSecrets(secrets: &self!.m_secrets) {
                                print("Successfully refreshed and saved access token.")
                            } else {
                                print("Failed to save refreshed tokens.")
                            }
                        } else {
                            print("Failed to parse token response.")
                        }
                    } else {
                        let serviceError = try JSONDecoder().decode(ServiceError.self, from: data)
                        serviceError.printErrors(prefix: "refreshAccessToken ")
                    }
                }
                return
            } catch {
                print("Error processing response: \(error)")
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
        // set a 10 second timeout on this request
        request.timeoutInterval = self.requestTimeout

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
            print("fetchAccountNumbers Error: \(error.localizedDescription)")
            print("   detail:  \(error)")
        }
    }
    
    /**
     * fetchAccounts - get the account numbers and balances.
     */
    func fetchAccounts( retry : Bool = false )
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
        // set a 10 second timeout on this request
        request.timeoutInterval = self.requestTimeout

        do
        {
            let semaphore = DispatchSemaphore(value: 0)
            var responseData: Data?
            var responseError: Error?
            var httpResponse: HTTPURLResponse?
            URLSession.shared.dataTask(with: request) { data, response, error in
                responseData = data
                responseError = error
                httpResponse = response as? HTTPURLResponse
                semaphore.signal()
            }.resume()
            semaphore.wait()
            
            if let error = responseError {
                print("fetchPriceHistory - Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = responseData else {
                print("fetchPriceHistory. No data received")
                return
            }
            
            if( httpResponse?.statusCode != 200 )
            {
                // decode data as a ServiceError
                print( "fetchAccounts: decoding json as ServiceError" )
                let serviceError = try JSONDecoder().decode(ServiceError.self, from: data)
                serviceError.printErrors(prefix: "fetchAccounts ")
                // if the status is 401 and retry is true, call fetchAccounts again after refreshing the access token
                if( httpResponse?.statusCode == 401 && retry )
                {
                    print( "=== retrying fetchAccounts after refreshing access token ===" )
                    refreshAccessToken()
                    fetchAccounts( retry : false )
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
            print("fetchAccounts Error: \(error.localizedDescription)")
            print("   detail:  \(error)")
            return
        }
    }
    
    
    /**
     * fettchPriceHistory  get the history of prices for all securities
     */
    func fetchPriceHistory( symbol : String )  -> CandleList?
    {
        print("=== fetchPriceHistory  ===")
        loadingDelegate?.setLoading(true)
        defer {
            loadingDelegate?.setLoading(false)
        }
        
        var priceHistoryUrl = "\(priceHistoryWeb)"
        priceHistoryUrl += "?symbol=\(symbol)"
        priceHistoryUrl += "&periodType=year"
        priceHistoryUrl += "&period=1"
        priceHistoryUrl += "&frequencyType=daily"
        
        guard let url = URL( string: priceHistoryUrl ) else {
            print("fetchPriceHistory. Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        // set a 10 second timeout on this request
        request.timeoutInterval = self.requestTimeout

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?
        var httpResponse: HTTPURLResponse?
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            responseData = data
            responseError = error
            httpResponse = response as? HTTPURLResponse
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        
        if let error = responseError {
            print("fetchPriceHistory - Error: \(error.localizedDescription)")
            return nil
        }
        
        guard let data = responseData else {
            print("fetchPriceHistory. No data received")
            return nil
        }
        
        if httpResponse?.statusCode != 200 {
            print("fetchPriceHistory - Failed to fetch price history.  code = \(httpResponse?.statusCode ?? -1)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let candleList: CandleList = try decoder.decode(CandleList.self, from: data)
            print("fetchPriceHistory - Fetched \(candleList.candles.count) candles for \(symbol)")
            return candleList
        } catch {
            print("fetchPriceHistory - Error: \(error.localizedDescription)")
            print("   detail:  \(error)")
            return nil
        }
    }
    
    /**
     * compute ATR for given symbol
     */
    public func computeATR( symbol : String ) async -> Double
    {
        print("=== computeATR  ===")
        guard let priceHistory : CandleList =  self.fetchPriceHistory( symbol: symbol ) else {
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
        return (atr * 1.08  / close * 100.0)
    }
    

    /**
     * fetchTransactionHistorySync - synchronous fetch of transaction history
     */
    public func fetchTransactionHistorySync()
    {
        print("=== fetchTransactionHistorySync  ===")
        // Create a semaphore to wait for the async operation
        let semaphore = DispatchSemaphore(value: 0)
        // Create a task to run the async operation
        Task {
            await self.fetchTransactionHistory()
            print( " --- fetchTransactionHistory done, signalling semaphore ---" )
            semaphore.signal()
        }
        // Wait for the async operation to complete
        print( " --- fetchTransactionHistorySync waiting for semaphore ---" )
        semaphore.wait()
        print( " --- fetchTransactionHistorySync done ---" )
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
     */
    public func fetchTransactionHistory() async {
        print("=== fetchTransactionHistory -  quarterDelta: \(m_quarterDelta) ===")
        loadingDelegate?.setLoading(true)
        defer {
            loadingDelegate?.setLoading(false)
        }
        // if we have already fetched maxMonthDelta, return
        if( maxQuarterDelta <= m_quarterDelta )
        {
            print( " --- fetchTransactionHistory -  maxMonthDelta reached" )
            return
        }
        // if this is year0, remove any and all entries
        if ( 0 == m_quarterDelta )
        {
            m_transactionList.removeAll(keepingCapacity: true)
        }
        let initialSize : Int = m_transactionList.count
        let endDate = getDateNQuartersAgoStr(quarterDelta: m_quarterDelta)
        let startDate = getDateNQuartersAgoStr(quarterDelta: m_quarterDelta + 1)
        
        // Create a task group to handle multiple account requests concurrently
        await withTaskGroup(of: [Transaction]?.self) { group in
            // Add a task for each account
            for accountNumberHash in self.m_secrets.acountNumberHash {
                group.addTask {
                    var transactionHistoryUrl = "\(accountWeb)/\(accountNumberHash.hashValue ?? "N/A")/transactions"
                    transactionHistoryUrl += "?startDate=\(startDate)"
                    transactionHistoryUrl += "&endDate=\(endDate)"
                    transactionHistoryUrl += "&types=TRADE"

                    guard let url = URL(string: transactionHistoryUrl) else {
                        print("fetchTransactionHistory. Invalid URL")
                        return nil
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "accept")
                    // set a 10 second timeout on this request
                    request.timeoutInterval = self.requestTimeout

                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        
                        guard let httpResponse = response as? HTTPURLResponse else {
                            print("Invalid response type")
                            return nil
                        }
                        
                        if httpResponse.statusCode != 200 {
                            print("response code: \(httpResponse.statusCode)  data: \(String(data: data, encoding: .utf8) ?? "N/A")")
                            if let serviceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                                serviceError.printErrors(prefix: "  fetchTransactionHistory ")
                            }
                            return nil
                        }

                        let decoder = JSONDecoder()
                        return try decoder.decode([Transaction].self, from: data)
                    } catch {
                        print("fetchTransactionHistory Error: \(error.localizedDescription)")
                        print("   detail:  \(error)")
                        return nil
                    }
                }
            }

            // Collect results from all tasks
            for await transactions in group {
                if let transactions = transactions {
                    m_transactionList.append(contentsOf: transactions)
                }
            }
        }

        print("Fetched \(m_transactionList.count - initialSize) transactions")
        m_transactionList.sort { $0.tradeDate ?? "0000" > $1.tradeDate ?? "0000" }
        self.setLatestTradeDates()
        // increment m_monthDelta to 3 at most
        if( maxQuarterDelta > m_quarterDelta ) {
            m_quarterDelta += 1
        }
    }


    /**
     * getTransactionsFor - return the m_transactionList.
     */
    public func getTransactionsFor( symbol: String? = nil ) -> [Transaction]
    {
        print( "==== getTransactionsFor \(symbol ?? "nil") ====" )
        if( nil == symbol ) {
            return m_transactionList
        }
        // to avoid filtering again or creating additional copies, save the lastFilteredSymbol and the lastFilteredTransactions
        if m_lastFilteredTransactionSymbol != symbol {
            m_lastFilteredTransactionSymbol = symbol
            m_lastFilteredTransactions.removeAll(keepingCapacity: true)
            // get the filtered transactions for the security and fetch more until we have some or the retries are exhausted.
            while( (self.maxQuarterDelta > self.m_quarterDelta) && (self.m_lastFilteredTransactions.count == 0) ) {
                m_lastFilteredTransactions =  m_transactionList.filter { transaction in
                    // Check if the symbol is nil or if any transferItem in the transaction matches the symbol
                    return symbol == nil || transaction.transferItems.contains { $0.instrument?.symbol == symbol }
                }
                // if we do not have filtered transactions yet, get more transactions
                if( self.m_lastFilteredTransactions.count == 0 ) {
                    self.fetchTransactionHistorySync()
                }
            }
        }
        // return the transactionlist where the symbol matches what is provided
        return m_lastFilteredTransactions
    }
    
    private func setLatestTradeDates()
    {
        print( "--- setLatestTradeDates ---" )
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
        print( " ! setLatestTradeDates - set dates for \(m_latestDateForSymbol.count) symbols !" )
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
    public func fetchOrderHistory( retry : Bool = false ) 
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
        )
        
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
        
        guard let url = URL( string: orderHistoryUrl ) else {
            print("fetchOrderHistory. Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        // set a 10 second timeout on this request
        request.timeoutInterval = self.requestTimeout

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?
        var httpResponse: HTTPURLResponse?
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            responseData = data
            responseError = error
            httpResponse = response as? HTTPURLResponse
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        
        if let error = responseError {
            print("fetchOrderHistory Error: \(error.localizedDescription)")
            return
        }
        
        guard let data = responseData else {
            print("fetchOrderHistory. No data received")
            return
        }
        
        if httpResponse?.statusCode != 200 {
            if httpResponse?.statusCode == 401 && retry {
                print("=== retrying fetchOrderHistory after refreshing access token ===")
                refreshAccessToken()
                fetchOrderHistory(retry: false)
                return
            }
            
            if let serviceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                serviceError.printErrors(prefix: "fetchOrderHistory ")
            }
            return
        }
        
        do {
            let decoder = JSONDecoder()
            m_orderList.append(contentsOf: try decoder.decode([Order].self, from: data))
        } catch {
            print("fetchOrderHistory Error: \(error.localizedDescription)")
            print("   detail:  \(error)")
            return
        }
        
        print("Fetched \(m_orderList.count) orders for all accounts")
        
        // update the m_symbolHasOrders dictionary with each symbol in the orderList with orders that are in awaiting states
        m_symbolsWithOrders.removeAll(keepingCapacity: true)
        for order in m_orderList {
            if( order.status == OrderStatus.awaitingParentOrder ||
                order.status == OrderStatus.awaitingCondition ||
                order.status == OrderStatus.awaitingStopCondition ||
                order.status == OrderStatus.awaitingManualReview ||
                order.status == OrderStatus.pendingActivation ||
                order.status == OrderStatus.accepted ||
                order.status == OrderStatus.working ||
                order.status == OrderStatus.new ||
                order.status == OrderStatus.awaitingReleaseTime
            ) {
                for leg in order.orderLegCollection ?? [] {
                    if( leg.instrument?.symbol != nil ) {
                        m_symbolsWithOrders.insert( leg.instrument?.symbol ?? "" )
                    }
                    else {
                        print( "\(leg.instrument?.symbol ?? "no symbol") has orders NOT in awaiting states \(order.status ?? OrderStatus.unknown)" )
                    }
                }
            }
        }
        print("\(m_symbolsWithOrders.count) symbols have orders in awaiting states")
    }

    public func hasOrders( symbol: String? = nil ) -> Bool
    {
        return m_symbolsWithOrders.contains( symbol ?? "" )
    }
    
    
    /**
     * computeTaxLots - compute a list of tax lots as [SalesCalcPositionsRecord]
     *
     * We cannot get the tax lots from Schwab so we will need to compute it based on the transactions.
     */
    public func computeTaxLots(symbol: String) -> [SalesCalcPositionsRecord] {
        loadingDelegate?.setLoading(true)
        defer {
            loadingDelegate?.setLoading(false)
        }
        
        print("=== computeTaxLots \(symbol) ===")
        if symbol == m_lastFilteredTaxLotSymbol {
            print("=== computeTaxLots \(symbol) - returning cached ===")
            return m_lastFilteredPositionRecords
        }
        m_lastFilteredTaxLotSymbol = symbol

        /**
         * Find all the tax lots by saving all the transactions from the end toward the begininning until we find a zero share count.
         * After finding the zero share count, walk forward through the filtered position recoreds until we find a sale and remove
         * the sale record and the most expensive shares bought up to that point.
         *
         * If we do not find zero, we need to call teh fetTransactionHistory to get more records for this security.
         */
        fetchingLoop: while( maxQuarterDelta > self.m_quarterDelta ) {
            /** @TODO:  Improve the efficiency here... we do not need to start again after each fetch, but the set of transactions may differ.  */
            m_lastFilteredPositionRecords.removeAll( keepingCapacity: true )
            var currentShareCount : Double = getShareCount(symbol: symbol)
            print( " -- \(symbol) -- computeTaxLots() -- ")
            print( " -- \(symbol)  currentShareCount: \(currentShareCount) --" )
            
            /**
             * iterate over the collection to populate the positions records until we find a zero share count
             *  by subtracting buys from and adding sells to the currentShareCount
             */
            transactionLoop: for transaction in m_lastFilteredTransactions {
                if ( transaction.type == .trade )
                {
                    // for each transfer item
                    transferLoop: for transferItem in transaction.transferItems {
                        let numberOfShares : Double = transferItem.amount ?? 0.0
                        let marketValue : Double = transferItem.cost ?? 0.0
                        let costPerShare : Double = transferItem.price ?? 0.0
                        if( ( numberOfShares != 0.0 )
                            && ( marketValue != 0.0 )
                            && ( costPerShare != 0.0 ) ) {
                            let lastPrice : Double = transferItem.instrument?.closingPrice ?? 0.0
                            let gainLossDollar : Double = (lastPrice - costPerShare) * numberOfShares
                            let gainLossPct : Double = ((lastPrice - costPerShare) / costPerShare) * 100.0
                            var tradeDate : String = ""
                            do {
                                tradeDate = try Date( transaction.tradeDate ?? "1970-01-01", strategy: .iso8601.year().month().day() ).dateOnly()
                            }
                            catch {
                                print( " -- \(symbol)  Error parsing tradeDate: \(error) --" )
                            }
                            currentShareCount -=  numberOfShares

                            // add to position records
                            m_lastFilteredPositionRecords.append(
                                SalesCalcPositionsRecord(
                                    openDate: tradeDate,
                                    gainLossPct: gainLossPct,
                                    gainLossDollar: gainLossDollar,
                                    quantity: numberOfShares,
                                    price: lastPrice,
                                    costPerShare: costPerShare,
                                    marketValue: lastPrice * numberOfShares,
                                    costBasis: costPerShare * numberOfShares
                                )
                            )

                            // stop when the currentShareCount is zero or less
                            if currentShareCount <= 0.0 {
                                print( " === found 0 or less.  currentShareCount = \(currentShareCount)")
                                break fetchingLoop
                            }
                        } // if amount, cost, and price are non-nil and non-zero.
                    } // transferLoop
                } // if trade
            } // transactionLoop
            print( " !!!!!!  Zero not found.  \(currentShareCount).  Quarters: \(self.m_quarterDelta)")
            // fetch more records if we do not have a record.
            self.fetchTransactionHistorySync()
            print( " !!!     sync fetch completed." )
        } // fetchingLoop
        print( " ! returning \(m_lastFilteredPositionRecords.count) records" )
        return m_lastFilteredPositionRecords
    }
    
    // Add loading state handling to other network methods
    func fetchData<T: Decodable>(from url: URL) async throws -> T {
        loadingDelegate?.setLoading(true)
        defer {
            loadingDelegate?.setLoading(false)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func fetchDataWithTask<T: Decodable>(from url: URL, completion: @escaping (Result<T, Error>) -> Void) {
        loadingDelegate?.setLoading(true)
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self?.loadingDelegate?.setLoading(false)
                }
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
} // SchwabClient
