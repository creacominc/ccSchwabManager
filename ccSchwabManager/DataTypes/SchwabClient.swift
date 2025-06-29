import Foundation
import AuthenticationServices
import Compression
import os.log

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
    public let maxQuarterDelta : Int = 12 // 3 years
    private let requestTimeout : TimeInterval = 30
    static let shared = SchwabClient()
    @Published var showIncompleteDataWarning = false
    private var m_secrets : Secrets
    private var m_quarterDelta : Int = 0
    private var m_selectedAccountName : String = "All"
    private var m_accounts : [AccountContent] = []
    private var m_refreshAccessToken_running : Bool = false
    private var m_refreshTokenTask: Task<Void, Never>? = nil  // Add task reference for cancellation
    private var m_latestDateForSymbol : [String:Date] = [:]
    private let m_latestDateForSymbolLock = NSLock()  // Add mutex for m_latestDateForSymbol
    private var m_symbolsWithOrders: [String: [ActiveOrderStatus]] = [:]
    private var m_symbolsWithContracts : [String: [Position]] = [:]
    private var m_lastFilteredTransactionSymbol : String? = nil
    private var m_lastFilteredTaxLotSymbol : String? = nil
    private var m_transactionList : [Transaction] = []
    private let m_transactionListLock = NSLock()  // Add mutex for m_transactionList
    private var m_lastFilteredTransactions : [Transaction] = []
    private var m_lastFilteredTransaxtionsSourceCount : Int = 0
    private let m_filteredTransactionsLock = NSLock()  // Add mutex for filtered transactions
    private var m_lastFilteredTransactionSharesAvailableToTrade : Double? = nil
    private var m_lastfilteredTransactionsYears : Int = 0
    private var m_lastFilteredPositionRecords : [SalesCalcPositionsRecord] = []
    private var m_orderList : [Order] = []
    private let m_lastFilteredPriceHistoryLock = NSLock()
    private var m_lastFilteredPriceHistory: CandleList?
    private var m_lastFilteredPriceHistorySymbol: String = ""
    private let m_quarterDeltaLock = NSLock()  // Add mutex for m_quarterDelta
    
    // Create a logger for this class
    private let logger = Logger(subsystem: "com.creacom.ccSchwabManager", category: "SchwabClient")
    
    // Add a lock for loadingDelegate synchronization
    private let loadingDelegateLock = NSLock()
    
    // Add a computed property to track loading delegate changes
    var loadingDelegate: LoadingStateDelegate? {
        get { 
            loadingDelegateLock.lock()
            defer { loadingDelegateLock.unlock() }
            return _loadingDelegate 
        }
        set { 
            loadingDelegateLock.lock()
            defer { loadingDelegateLock.unlock() }
            _loadingDelegate = newValue
        }
    }
    private weak var _loadingDelegate: LoadingStateDelegate?

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

    private func getShareCount(symbol: String) -> Double {
        print("=== getShareCount \(symbol) ===")
        var shareCount: Double = 0.0
        
        // Find the position for this symbol
        for account in m_accounts {
            if let positions = account.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        shareCount = ((position.longQuantity ?? 0.0) + (position.shortQuantity ?? 0.0))
                        print("Found position with \(shareCount) shares")
                        return shareCount
                    }
                }
            }
        }
        print("No position found for \(symbol)")
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
        //print("🔍 getAccessToken - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        
        let url = URL( string: "\(accessTokenWeb)" )!
        //print( "accessTokenUrl: \(url)" )
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
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Void, ErrorCodes> = .failure(.notAuthenticated)
        
        URLSession.shared.dataTask(with: accessTokenRequest)
        { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    //print("🔍 getAccessToken - Setting loading to FALSE")
                    self?.loadingDelegate?.setLoading(false)
                }
                semaphore.signal()
            }
            
            guard let data = data, ( (error == nil) && ( response != nil ) )
            else
            {
                print( "Error: \( error?.localizedDescription ?? "Unknown error" )" )
                result = .failure(ErrorCodes.notAuthenticated)
                return
            }
            
            let httpResponse : HTTPURLResponse = response as! HTTPURLResponse
            if( httpResponse.statusCode == 200 )
            {
                if let tokenDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                {
                    self?.m_secrets.accessToken = ( tokenDict["access_token"] as? String ?? "" )
                    self?.m_secrets.refreshToken = ( tokenDict["refresh_token"] as? String ?? "" )
                    if( !KeychainManager.saveSecrets(secrets: &self!.m_secrets) )
                    {
                        print( "Failed to save secrets with access and refresh tokens." )
                        result = .failure(ErrorCodes.failedToSaveSecrets)
                        return
                    }
                    result = .success( Void() )
                }
                else
                {
                    print( "Failed to parse token response" )
                    result = .failure(ErrorCodes.notAuthenticated)
                }
            }
            else
            {
                print( "Failed to fetch account numbers.   error: \(httpResponse.statusCode). \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))" )
                result = .failure(ErrorCodes.notAuthenticated)
            }
        }.resume()
        
        // Wait for completion with timeout to prevent deadlock
        let timeoutResult = semaphore.wait(timeout: .now() + 30.0) // 30 second timeout
        if timeoutResult == .timedOut {
            print("getAccessToken timed out")
            result = .failure(ErrorCodes.notAuthenticated)
        }
        
        // Call completion with the result
        completion(result)
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

        // if the accessToken or refreshToken are empty, call getAccessToken instead
        if ( self.m_secrets.accessToken == "" ) || ( self.m_secrets.refreshToken == "" ) {
            print("Access token or refresh token is empty, getting initial access token...")
            self.getAccessToken{ result in
                switch result {
                case .success:
                    print(" refreshAccessToken - Successfully got access token")
                case .failure(let error):
                    print(" refreshAccessToken - Failed to get access token: \(error.localizedDescription)")
                    // resetting code
                    self.m_secrets.code = ""
                }
            }
            // Return early since getAccessToken is now synchronous and handles the token acquisition
            return
        }
        
        //print("🔍 refreshAccessToken - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //print("🔍 refreshAccessToken - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }

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
        var refreshCompleted = false
        
        URLSession.shared.dataTask(with: refreshTokenRequest) { [weak self] data, response, error in
            defer { 
                if !refreshCompleted {
                    refreshCompleted = true
                    semaphore.signal()
                }
            }
            
            guard let self = self else {
                print("SchwabClient deallocated during token refresh")
                return
            }
            
            do {
                if let error = error {
                    print("Network error during token refresh: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received during token refresh")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
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
                    } else {
                        print("Token refresh failed with status code: \(httpResponse.statusCode)")
                        if let serviceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                            serviceError.printErrors(prefix: "refreshAccessToken ")
                        }
                    }
                }
            }
        }.resume()
        
        // Wait for completion with timeout to prevent deadlock
        let timeoutResult = semaphore.wait(timeout: .now() + 30.0) // 30 second timeout
        if timeoutResult == .timedOut {
            print("Token refresh timed out")
        }
    }
    
    private func startRefreshAccessTokenThread() {
        guard !m_refreshAccessToken_running else {
            print("Refresh token thread already running")
            return
        }
        
        m_refreshAccessToken_running = true
        
        // Cancel any existing task
        m_refreshTokenTask?.cancel()
        
        // Create new task with proper cancellation support
        m_refreshTokenTask = Task { [weak self] in
            let interval: TimeInterval = 15 * 60  // 15 minute interval
            
            while !Task.isCancelled {
                // Perform token refresh
                self?.refreshAccessToken()
                
                // Wait for next interval or cancellation
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    // Task was cancelled
                    break
                }
            }
            
            // Clean up when task ends
            await MainActor.run { [weak self] in
                self?.m_refreshAccessToken_running = false
            }
        }
    }
    
    // Add cleanup method
    func cleanup() {
        m_refreshTokenTask?.cancel()
        m_refreshTokenTask = nil
        m_refreshAccessToken_running = false
    }
    
    // Add method to clear stuck loading states
    func clearLoadingState() {
        AppLogger.shared.warning("🧹 SchwabClient.clearLoadingState - Clearing any stuck loading state")
        loadingDelegate?.setLoading(false)
        loadingDelegate = nil
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
        //print("🔍 fetchAccountNumbers - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //print("🔍 fetchAccountNumbers - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }
        
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
            //            print( "data:  \(String(data: data, encoding: .utf8) ?? "Missing data" )" )
            
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
    func fetchAccounts( retry : Bool = false ) async
    {
        print("=== fetchAccounts: selected: \(self.m_selectedAccountName) ===")
        //print("🔍 fetchAccounts - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //print("🔍 fetchAccounts - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }
        
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
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                return
            }
            
            if httpResponse.statusCode != 200 {
                // decode data as a ServiceError
                print( "fetchAccounts: decoding json as ServiceError" )
                let serviceError = try JSONDecoder().decode(ServiceError.self, from: data)
                serviceError.printErrors(prefix: "fetchAccounts ")
                // if the status is 401 and retry is true, call fetchAccounts again after refreshing the access token
                if httpResponse.statusCode == 401 && retry {
                    print( "=== retrying fetchAccounts after refreshing access token ===" )
                    refreshAccessToken()
                    await fetchAccounts(retry: false)
                }
                return
            }
            
            let decoder = JSONDecoder()
            print( "=== decoding accounts ===" )
            m_accounts  = try decoder.decode([AccountContent].self, from: data)
            print( "  decoded \(m_accounts.count) accounts" )
            // search the positions in the accounts to build a map of symbolsWithContracts
            // Build map of symbols with option contracts
            m_symbolsWithContracts.removeAll()
            
            for account in m_accounts {
                if let positions = account.securitiesAccount?.positions {
                    for position in positions {
                        if let instrument = position.instrument,
                           let assetType = instrument.assetType,
                           assetType == .OPTION,
                           let underlyingSymbol = instrument.underlyingSymbol {
                            
                            // Add underlying symbol to the map if not already present
                            if m_symbolsWithContracts[underlyingSymbol] == nil {
                                m_symbolsWithContracts[underlyingSymbol] = []
                                print("Added underlying symbol to contracts map: \(underlyingSymbol)")
                            }
                            
                            // Add the position to the list for this underlying
                            if let symbol = instrument.symbol {
                                // Check if this position is already in the list by comparing symbols
                                let positionExists = m_symbolsWithContracts[underlyingSymbol]!.contains { existingPosition in
                                    existingPosition.instrument?.symbol == symbol
                                }
                                
                                if !positionExists {
                                    m_symbolsWithContracts[underlyingSymbol]!.append(position)
                                    print("  Added option contract: \(symbol) - \(instrument.description ?? "No description")")
                                }
                            }
                        }
                    }
                }
            }
            print("Built contracts map with \(m_symbolsWithContracts.count) underlying symbols")
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
        print("=== fetchPriceHistory \(symbol) ===")

        // Check cache first without holding lock
        if( (symbol == m_lastFilteredPriceHistorySymbol) && (!(m_lastFilteredPriceHistory?.empty ?? true)) )
        {
            print( "  fetchPriceHistory - returning cached." )
            return m_lastFilteredPriceHistory
        }

        //print("🔍 fetchPriceHistory - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //print("🔍 fetchPriceHistory - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }
        
        // Hold lock for the entire operation to prevent race conditions
        m_lastFilteredPriceHistoryLock.lock()
        defer {
            m_lastFilteredPriceHistoryLock.unlock()
        }
        
        // Double-check cache after acquiring lock
        if( (symbol == m_lastFilteredPriceHistorySymbol) && (!(m_lastFilteredPriceHistory?.empty ?? true)) )
        {
            print( "  fetchPriceHistory - returning cached (after lock)." )
            return m_lastFilteredPriceHistory
        }
        
        m_lastFilteredPriceHistorySymbol = symbol
        m_lastFilteredPriceHistory?.candles.removeAll(keepingCapacity: true)

        let millisecondsSinceEpoch : Int64 = Int64(Date().timeIntervalSince1970 * 1000)
        // print date
        print( "      endDate = \(Date( timeIntervalSince1970: Double(millisecondsSinceEpoch)/1000.0 ) )")

        var priceHistoryUrl = "\(priceHistoryWeb)"
        priceHistoryUrl += "?symbol=\(symbol)"
        priceHistoryUrl += "&periodType=year"
        priceHistoryUrl += "&period=1"
        priceHistoryUrl += "&frequencyType=daily"
//        priceHistoryUrl += "&endDate=\(millisecondsSinceEpoch)"
        //print( "     priceHistoryUrl: \(priceHistoryUrl)" )
        
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
            m_lastFilteredPriceHistory = try decoder.decode(CandleList.self, from: data)
            print("fetchPriceHistory - Fetched \(m_lastFilteredPriceHistory?.candles.count ?? 0) candles for \(symbol)")
//            // print first and last dates in ISO8601 format
//            print( "  date range:  \(Date(timeIntervalSince1970: Double(m_lastFilteredPriceHistory?.candles.first!.datetime ?? Int64(0.0))/1000.0)) - \(Date(timeIntervalSince1970: Double(m_lastFilteredPriceHistory?.candles.last!.datetime ?? Int64(0.0))/1000.0))" )
//            // print the last 5 dates and closing prices
//            for i in stride(from: (m_lastFilteredPriceHistory?.candles.count ?? 0) - 1, to: (m_lastFilteredPriceHistory?.candles.count ?? 0) - 6, by: -1) {
//                let candle: Candle = m_lastFilteredPriceHistory?.candles[i] ?? Candle()
//                print( "  \(Date(timeIntervalSince1970: Double(candle.datetime ?? Int64(0.0))/1000.0)):  \(candle.close ?? 0.0)" )
//            }


            return m_lastFilteredPriceHistory
        } catch {
            print("fetchPriceHistory - Error: \(error.localizedDescription)")
            print("   detail:  \(error)")
            return nil
        }
    }
    
    /**
     * fetchQuote - get quote data including fundamental information for a symbol
     */
    func fetchQuote(symbol: String) -> QuoteData? {
        print("=== fetchQuote \(symbol) ===")
        
        let quoteUrl = "\(marketdataAPI)/\(symbol)/quotes"
        print("     quoteUrl: \(quoteUrl)")
        
        guard let url = URL(string: quoteUrl) else {
            print("fetchQuote. Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")
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
            print("fetchQuote - Error: \(error.localizedDescription)")
            return nil
        }
        
        guard let data = responseData else {
            print("fetchQuote. No data received")
            return nil
        }
        
        if httpResponse?.statusCode != 200 {
            print("fetchQuote - Failed to fetch quote. code = \(httpResponse?.statusCode ?? -1)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let quoteResponse = try decoder.decode(QuoteResponse.self, from: data)
            
            // Get the quote data for the requested symbol
            guard let quoteData = quoteResponse.quotes[symbol] else {
                print("fetchQuote - No quote data found for symbol \(symbol)")
                return nil
            }
            
            print("fetchQuote - Successfully fetched quote for \(symbol)")
            
            // Log detailed fundamental information
            if let fundamental = quoteData.fundamental {
                print("fetchQuote - Fundamental data for \(symbol):")
                print("  divYield: \(fundamental.divYield ?? 0)")
                print("  divAmount: \(fundamental.divAmount ?? 0)")
                print("  divFreq: \(fundamental.divFreq ?? 0)")
                print("  eps: \(fundamental.eps ?? 0)")
                print("  peRatio: \(fundamental.peRatio ?? 0)")
                
                if let divYield = fundamental.divYield {
                    print("fetchQuote - Raw dividend yield for \(symbol): \(divYield)%")
                    print("fetchQuote - Dividend yield is already a percentage value")
                }
            } else {
                print("fetchQuote - No fundamental data available for \(symbol)")
            }
            
            return quoteData
        } catch {
            print("fetchQuote - Error: \(error.localizedDescription)")
            print("   detail: \(error)")
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
        
        // Get a local copy of the candles array to prevent race conditions
        let candles = priceHistory.candles
        let candlesCount = candles.count
        
        // Need at least 2 candles to compute ATR
        guard candlesCount > 1 else {
            print("computeATR: Need at least 2 candles, got \(candlesCount)")
            return 0.0
        }
        
        var close : Double  = priceHistory.previousClose ?? 0.0
        var atr : Double  = 0.0
        
        /*
         * Compute the ATR as the average of the True Range.
         * The True Range is the maximum of absolute values of the High - Low, High - previous Close, and Low - previous Close
         */
        let length : Int  =  min( candlesCount, 21 )
        let startIndex : Int = candlesCount - length
        
        // Additional safety check
        guard startIndex >= 0 && startIndex < candlesCount else {
            print("computeATR: Invalid startIndex \(startIndex) for candlesCount \(candlesCount)")
            return 0.0
        }
        
        for indx in 0..<length
        {
            let position = startIndex + indx
            
            // Bounds check for current position - recheck candlesCount in case array was modified
            guard position >= 0 && position < candles.count else {
                print("computeATR: Position \(position) out of bounds for candlesCount \(candles.count)")
                continue
            }
            
            let candle : Candle  = candles[position]
            
            // Safe access to previous close
            let prevClose : Double
            if position == 0 {
                prevClose = priceHistory.previousClose ?? 0.0
            } else {
                let prevPosition = position - 1
                guard prevPosition >= 0 && prevPosition < candles.count else {
                    print("computeATR: Previous position \(prevPosition) out of bounds for candlesCount \(candles.count)")
                    continue
                }
                prevClose = candles[prevPosition].close ?? 0.0
            }
            
            let high : Double  = candle.high ?? 0.0
            let low  : Double  = candle.low ?? 0.0
            let tr : Double = max( abs( high - low ), abs( high - prevClose ), abs( low - prevClose ) )
            close = candle.close ?? 0.0
            atr = ( (atr * Double(indx)) + tr ) / Double(indx+1)
        }
        
        // return the ATR as a percent.
        return (atr * 1.08  / close * 100.0)
    }
    

    /**
     * fetchTransactionHistorySync - synchronous fetch of transaction history
     * Note: This method should be avoided in favor of async versions
     */
    public func fetchTransactionHistorySync() {
        print("=== fetchTransactionHistorySync  ===")
        
        // Check if we're already at the limit
        let currentQuarterDelta = m_quarterDeltaLock.withLock {
            let current = m_quarterDelta
            if maxQuarterDelta <= current {
                return current
            }
            
            // if this is year0, remove any and all entries
            if current == 0 {
                m_transactionListLock.withLock {
                    m_transactionList.removeAll(keepingCapacity: true)
                }
            }
            
            // Increment quarter delta
            m_quarterDelta += 1
            return m_quarterDelta
        }
        
        if maxQuarterDelta <= currentQuarterDelta {
            print(" --- fetchTransactionHistory -  maxQuarterDelta reached")
            return
        }

        // Create a task to run the async operation
        let task = Task {
            await self.fetchTransactionHistory()
        }
        
        // Wait for completion with timeout
        let group = DispatchGroup()
        group.enter()
        
        Task {
            await task.value
            group.leave()
        }
        
        let result = group.wait(timeout: .now() + 60.0) // 60 second timeout
        if result == .timedOut {
            print("fetchTransactionHistorySync timed out")
            task.cancel()
        }
        
        print(" --- fetchTransactionHistorySync done ---")
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
        // Get quarter delta safely for logging
        let quarterDeltaForLogging = m_quarterDeltaLock.withLock {
            return m_quarterDelta
        }
        print("=== fetchTransactionHistory -  quarterDelta: \(quarterDeltaForLogging) ===")
        //print("🔍 fetchTransactionHistory - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //print("🔍 fetchTransactionHistory - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }
        
        // Check and increment quarter delta atomically
        let currentQuarterDelta = m_quarterDeltaLock.withLock {
            let current = m_quarterDelta
            if maxQuarterDelta <= current {
                return current
            }
            
            // if this is year0, remove any and all entries
            if current == 0 {
                m_transactionListLock.withLock {
                    m_transactionList.removeAll(keepingCapacity: true)
                }
            }
            
            // Increment quarter delta
            m_quarterDelta += 1
            return m_quarterDelta
        }
        
        if maxQuarterDelta <= currentQuarterDelta {
            print(" --- fetchTransactionHistory -  maxQuarterDelta reached")
            return
        }
        
        let newQuarterDelta = currentQuarterDelta

        let initialSize: Int = m_transactionList.count
        let endDate = getDateNQuartersAgoStr(quarterDelta: newQuarterDelta - 1)
        let startDate = getDateNQuartersAgoStr(quarterDelta: newQuarterDelta)

        print("  -- processing quarter delta: \(newQuarterDelta)")

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
            var newTransactions: [Transaction] = []
            for await transactions in group {
                if let transactions = transactions {
                    newTransactions.append(contentsOf: transactions)
                }
            }
            m_transactionListLock.withLock {
                m_transactionList.append(contentsOf: newTransactions)
            }
        }

        print("Fetched \(m_transactionList.count - initialSize) transactions")
        /** @TODO:  check for efficiency here.  I think we can avoid sorting and calling setLatestTradeDate for most threads. */
        m_transactionListLock.withLock {
            m_transactionList.sort { $0.tradeDate ?? "0000" > $1.tradeDate ?? "0000" }
        }
        self.setLatestTradeDates()
    }


    /**
     * getTransactionsFor - return the m_transactionList.
     */
    public func getTransactionsFor( symbol: String? = nil ) -> [Transaction]
    {
        // Get quarter delta safely for logging
        let quarterDeltaForLogging = m_quarterDeltaLock.withLock {
            return m_quarterDelta
        }
        print( "==== getTransactionsFor \(symbol ?? "nil")  quarters: \(quarterDeltaForLogging) ====" )
        print("Current transaction list size: \(m_transactionList.count)")
        
        if( nil == symbol ) {
            print( "  !!!!! No symbol provided" )
            m_transactionListLock.lock()
            defer { m_transactionListLock.unlock() }
            return m_transactionList
        }

        m_filteredTransactionsLock.lock()
        defer { m_filteredTransactionsLock.unlock() }

        m_transactionListLock.lock()
        defer { m_transactionListLock.unlock() }

        // to avoid filtering again or creating additional copies, save the lastFilteredSymbol and the lastFilteredTransactions
        // also track the count of the source list.  if it changes, we need to update.
        if ( (m_lastFilteredTransactionSymbol != symbol)
             || ( m_lastFilteredTransaxtionsSourceCount != m_transactionList.count ) ) {
            
            m_lastFilteredTransactionSymbol = symbol
            m_lastFilteredTransaxtionsSourceCount = m_transactionList.count
            m_lastFilteredTransactions.removeAll(keepingCapacity: true)
            m_lastFilteredTransactionSharesAvailableToTrade = 0.0
            print( "  !!!!! cleared filtered transactions" )
            // get the filtered transactions for the security and fetch more until we have some or the retries are exhausted.
            m_lastFilteredTransactions =  m_transactionList.filter { transaction in
                // Check if the symbol is nil or if any transferItem in the transaction matches the symbol
                let matches = transaction.transferItems.contains { $0.instrument?.symbol == symbol }
                return matches // return from closure, not from the method
            }
            print("Found \(m_lastFilteredTransactions.count) matching transactions.  \(quarterDeltaForLogging) of \(self.maxQuarterDelta)")

            // Fetch more records if needed, but with proper termination conditions
            var fetchAttempts = 0
            let maxFetchAttempts = 3  // Limit the number of fetch attempts
            
            while( (self.maxQuarterDelta > quarterDeltaForLogging) && 
                   (self.m_lastFilteredTransactions.count == 0) && 
                   (fetchAttempts < maxFetchAttempts) ) {
                print( "   !!! still no records, fetching again (attempt \(fetchAttempts + 1)/\(maxFetchAttempts))" )
                fetchAttempts += 1
                
                // Use async version instead of sync to avoid blocking
                Task {
                    await self.fetchTransactionHistory()
                }
                
                // Wait a bit for the async operation to complete
                Thread.sleep(forTimeInterval: 1.0)
                
                // Re-filter after potential new data
                m_lastFilteredTransactions =  m_transactionList.filter { transaction in
                    // Check if the symbol is nil or if any transferItem in the transaction matches the symbol
                    let matches = symbol == nil || transaction.transferItems.contains { $0.instrument?.symbol == symbol }
                    return matches
                }
                print("Found \(m_lastFilteredTransactions.count) matching transactions after fetch")
            }
            
            if fetchAttempts >= maxFetchAttempts && m_lastFilteredTransactions.count == 0 {
                print("Reached maximum fetch attempts without finding transactions for symbol: \(symbol ?? "nil")")
            }
        }
        else {
            print( "  !!!! getTransactionsFor  same symbol \(symbol ?? "nil") and count as last time - returning cached" )
        }
        // return the transactionlist where the symbol matches what is provided
        print( " --- getTransactionsFor returning \(m_lastFilteredTransactions.count) transactions -- " )
        return m_lastFilteredTransactions
    } // getTransactionsFor
    



    private func setLatestTradeDates()
    {
        print( "--- setLatestTradeDates ---" )
        m_latestDateForSymbolLock.lock()
        defer { m_latestDateForSymbolLock.unlock() }
        
        m_latestDateForSymbol.removeAll(keepingCapacity: true)
        
        // Lock access to m_transactionList to prevent race conditions
        m_transactionListLock.lock()
        defer { m_transactionListLock.unlock() }
        
        // create a map of symbols to the most recent trade date
        for transaction in m_transactionList {
            for transferItem in transaction.transferItems {
                if let symbol = transferItem.instrument?.symbol {
                    // convert tradeDate string to a Date
                    var dateDte : Date = Date()
                    do {
                        dateDte = try Date( transaction.tradeDate ?? "1970-01-01 00:00:00", strategy: .iso8601.year().month().day()
                            .time(includingFractionalSeconds: false)
                        )
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
        m_latestDateForSymbolLock.lock()
        defer { m_latestDateForSymbolLock.unlock() }
        
        return m_latestDateForSymbol[symbol]?.dateOnly() ?? "0000"
    }

    /**
     * get number of shares available for trade.  call this after getTransactionsFor
     */
    public func getSharesAvailableForTrade( for symbol: String ) -> Double
    {
        return m_lastFilteredTransactionSharesAvailableToTrade ?? 0.0
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
        //print("🔍 fetchOrderHistory - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //print("🔍 fetchOrderHistory - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }
        
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

        m_symbolsWithOrders.removeAll(keepingCapacity: true)

        // get date one year ago
        let dateOneYearAgoStr : String = getDateNYearsAgoStr( yearDelta: 1 )
        
        // Fetch orders from all accounts in parallel
        await withTaskGroup(of: [Order]?.self) { group in
            // loop over the OrderStatus types to request the orders for each status
            for status: OrderStatus in OrderStatus.allCases {
                // for accountNumberHash in self.m_secrets.acountNumberHash {
                    group.addTask {
                        // print("  === fetchOrderHistory. accountNumberHash: \(accountNumberHash),  status: \(status.rawValue) ===" )

                        var orderHistoryUrl = "\(ordersWeb)"
                        orderHistoryUrl += "?fromEnteredTime=\(dateOneYearAgoStr)"
                        orderHistoryUrl += "&toEnteredTime=\(todayStr)"
                        orderHistoryUrl += "&status=\(status.rawValue)"

                        guard let url = URL( string: orderHistoryUrl ) else {
                            print("fetchOrderHistory. Invalid URL")
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
                                if httpResponse.statusCode == 401 && retry {
                                    print("=== retrying fetchOrderHistory after refreshing access token ===")
                                    self.refreshAccessToken()
                                    // Note: We can't recursively call async function from within task group
                                    // The retry will be handled by the caller
                                    return nil
                                }
                                
                                if let serviceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                                    // print data as string
                                    print( "  ---- data: \(String(data: data, encoding: .utf8) ?? "N/A")" )
                                    serviceError.printErrors(prefix: "fetchOrderHistory ")
                                }
                                return nil
                            }
                            
                            let decoder = JSONDecoder()
                            return try decoder.decode([Order].self, from: data)
                        } catch {
                            print("fetchOrderHistory Error: \(error.localizedDescription)")
                            print("   detail:  \(error)")
                            return nil
                        }
                    } // addTask
                // } // account number hash
            } // for all orderStatus values

            // Collect results from all tasks
            for await orders in group {
                if let orders = orders {
                    m_orderList.append(contentsOf: orders)
                }
            } // append orders
        } // await
        
        print("Fetched \(m_orderList.count) orders for all accounts")
        
        // update the m_symbolsWithOrders dictionary with each symbol in the orderList with orders that are in awaiting states
        for order in m_orderList {
            if let activeStatus = ActiveOrderStatus(from: order.status ?? .unknown) {
                if( ( order.orderStrategyType == .SINGLE )
                    || ( order.orderStrategyType == .TRIGGER ) ) {
                    for leg in order.orderLegCollection ?? [] {
                        if let symbol = leg.instrument?.symbol {
                            if m_symbolsWithOrders[symbol] == nil {
                                m_symbolsWithOrders[symbol] = []
                            }
                            if !m_symbolsWithOrders[symbol]!.contains(activeStatus) {
                                m_symbolsWithOrders[symbol]!.append(activeStatus)
                            }
                        }
                    }
                }
                if ( order.orderStrategyType == .OCO ) {
                    for childOrder in order.childOrderStrategies ?? [] {
                        if let childActiveStatus = ActiveOrderStatus(from: childOrder.status ?? .unknown) {
                            for leg in childOrder.orderLegCollection ?? [] {
                                if let symbol = leg.instrument?.symbol {
                                    if m_symbolsWithOrders[symbol] == nil {
                                        m_symbolsWithOrders[symbol] = []
                                    }
                                    if !m_symbolsWithOrders[symbol]!.contains(childActiveStatus) {
                                        m_symbolsWithOrders[symbol]!.append(childActiveStatus)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else if ( order.status != OrderStatus.canceled &&
                      order.status != OrderStatus.filled &&
                      order.status != OrderStatus.expired &&
                      order.status != OrderStatus.replaced &&
                      order.status != OrderStatus.rejected ){
                print( "... orders NOT in awaiting states \(order.status ?? OrderStatus.unknown)" )
            }
        }
        
        // Sort the order statuses by priority for each symbol
        for symbol in m_symbolsWithOrders.keys {
            m_symbolsWithOrders[symbol]?.sort { $0.priority < $1.priority }
        }
        
        print("\(m_symbolsWithOrders.count) symbols have orders in awaiting states")
    }

    public func hasOrders( symbol: String? = nil ) -> Bool
    {
        guard let symbol = symbol else { return false }
        return m_symbolsWithOrders[symbol]?.isEmpty == false
    }
    
    /**
     * getOrderStatuses - return the active order statuses for a given symbol
     */
    public func getOrderStatuses( symbol: String? = nil ) -> [ActiveOrderStatus]
    {
        guard let symbol = symbol else { return [] }
        return m_symbolsWithOrders[symbol] ?? []
    }
    
    /**
     * getPrimaryOrderStatus - return the highest priority order status for a given symbol
     */
    public func getPrimaryOrderStatus( symbol: String? = nil ) -> ActiveOrderStatus?
    {
        guard let symbol = symbol else { return nil }
        return m_symbolsWithOrders[symbol]?.first
    }
    
    /**
     * computeTaxLots - compute a list of tax lots as [SalesCalcPositionsRecord]
     *
     * We cannot get the tax lots from Schwab so we will need to compute it based on the transactions.
     */
    public func computeTaxLots(symbol: String) -> [SalesCalcPositionsRecord] {
        // display the busy indicator
        //print("🔍 computeTaxLots - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //print("🔍 computeTaxLots - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }

        print("=== computeTaxLots \(symbol) ===")

        // Return cached results if available
        if symbol == m_lastFilteredTaxLotSymbol {
            print("=== computeTaxLots \(symbol) - returning \(m_lastFilteredPositionRecords.count) cached ===")
            return m_lastFilteredPositionRecords
        }
        m_lastFilteredTaxLotSymbol = symbol

        print( " --- computeTaxLots() - seeking zero ---" )

        var fetchAttempts = 0
        let maxFetchAttempts = 5  // Limit fetch attempts to prevent infinite loops
        
        // Process transactions until we find zero shares or reach max quarters
        while fetchAttempts < maxFetchAttempts {
            fetchAttempts += 1
            print("--- computeTaxLots iteration \(fetchAttempts)/\(maxFetchAttempts) ---")

            // Clear previous results
            m_lastFilteredPositionRecords.removeAll(keepingCapacity: true)

            // Get current share count
            var currentShareCount : Double = getShareCount(symbol: symbol)
            // Get quarter delta safely for logging
            let quarterDeltaForLogging = m_quarterDeltaLock.withLock {
                return m_quarterDelta
            }
            print("-- \(symbol) -- computeTaxLots() currentShareCount: \(currentShareCount) quarterDelta: \(quarterDeltaForLogging) --")

            // get last price for this security
            let lastPrice = fetchPriceHistory(symbol: symbol)?.candles.last?.close ?? 0.0

            // Process all trade transactions - only process again if the number of transactions changes
            print( " -- computeTaxLots() - calling getTransactionsFor(symbol: \(symbol))" )
            for transaction in self.getTransactionsFor(symbol: symbol) where transaction.type == .trade {
                for transferItem in transaction.transferItems {
                    // find transferItems where the shares, value, and cost are not 0
                    guard let numberOfShares = transferItem.amount,
                          let marketValue = transferItem.cost,
                          let costPerShare = transferItem.price,
                          numberOfShares != 0.0,
                          marketValue != 0.0,
                          costPerShare != 0.0 else {
                        continue
                    }

                    let gainLossDollar = (lastPrice - costPerShare) * numberOfShares
                    let gainLossPct = ((lastPrice - costPerShare) / costPerShare) * 100.0
                    
                    // Parse trade date
                    guard let tradeDate : String = try? Date(transaction.tradeDate ?? "1970-01-01T00:00:00+0000",
                                                  strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false)).dateString() else {
                        continue
                    }
                    
                    // Update share count
                    currentShareCount = ( (currentShareCount - numberOfShares) * 100000 ).rounded()/100000
                    //print( "  -- date: \(tradeDate), currentShareCount: \(currentShareCount),    shares: \(numberOfShares), costPerShare: \(costPerShare) --" )
                    
                    // Add position record
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

                } // for transferItem

                // break if we find zero
                if isNearZero( currentShareCount ) {
                    print( " -- Found zero -- " )
                    break
                }
                else if ( 0 > currentShareCount ) {
                    print( " -- Negative share count --" )
                    break
                }

            } // for transaction
            
            // Break if we've found zero shares or reached max quarters
            if ( isNearZero(currentShareCount) ) {
                print( " -- found near zero --  currentShareCount = \(currentShareCount)" )
                break
            }
            else if ( 0 > currentShareCount ) {
                showIncompleteDataWarning = true
                print( " -- Negative share count --" )
                break
            }
            else if  ( self.maxQuarterDelta <= quarterDeltaForLogging )  {
                showIncompleteDataWarning = true
                print( " -- Reached max quarter delta --" )
                break
            }
            else if fetchAttempts >= maxFetchAttempts {
                showIncompleteDataWarning = true
                print( " -- Reached max fetch attempts --" )
                break
            }
            else
            {
                print( " -- Fetching more records (attempt \(fetchAttempts)) --" )
                // Fetch more records if needed, but use async version
                Task {
                    await self.fetchTransactionHistory()
                }
                
                // Wait a bit for the async operation to complete
                Thread.sleep(forTimeInterval: 1.0)
            }
            
        }
        
        if fetchAttempts >= maxFetchAttempts {
            print("Warning: computeTaxLots reached maximum fetch attempts for symbol: \(symbol)")
        }
        
        // Sort records by date (oldest first) and cost (highest first for same date)
        m_lastFilteredPositionRecords.sort { ($0.openDate < $1.openDate) || ($0.openDate == $1.openDate && $0.costPerShare > $1.costPerShare) }
        
        // Match sells with buys using highest price up to that point
        var remainingRecords: [SalesCalcPositionsRecord] = []
        var buyQueue: [SalesCalcPositionsRecord] = []
        //print( " -- removing sold shares -- " )
        for record in m_lastFilteredPositionRecords {
            // collect buy records until you find a sell record.
            if record.quantity > 0 {
                // print( "    ++++   adding buy to queue: \t\(record.openDate), \tquantity: \(record.quantity), \tcostPerShare: \(record.costPerShare)" )
                // Add buy record to queue
                buyQueue.append(record)
            } else {
                //print( "    ----   processing sell.  queue size: \(buyQueue.count),  sell: \t\(record.openDate), \tquantity: \(record.quantity), \tcostPerShare: \(record.costPerShare)" )
                // sort the buy queue by high price
                buyQueue.sort { ($0.costPerShare > $1.costPerShare) }

                // Process sell record
                var remainingSellQuantity = abs(record.quantity)
                //var matchedBuys: [SalesCalcPositionsRecord] = []
                
                // Match sell with buys
                while remainingSellQuantity > 0 && !buyQueue.isEmpty {
                    var buyRecord = buyQueue.removeFirst()
                    let buyQuantity = buyRecord.quantity

                    //print( "        remainingSellQuantity: \(remainingSellQuantity),  buyQuantity: \(buyQuantity),  queue size: \(buyQueue.count)" )
                    //print( "        !         buyRecord: \t\(buyRecord.openDate), \t\(buyRecord.quantity), \t\(buyRecord.costPerShare)")
                    if buyQuantity <= remainingSellQuantity {
                        // Buy record fully matches sell
                        remainingSellQuantity -= buyQuantity
                        //matchedBuys.append(buyRecord)
                    } else {
                        // Buy record partially matches sell - put it at the head of the queue if it is at least $0.01
                        if( 0.01 <= round( buyRecord.quantity * 100.0 ) / 100.0 )
                        {
                            let matchedQuantity = remainingSellQuantity
                            buyRecord.quantity -= matchedQuantity
                            buyRecord.marketValue = buyRecord.quantity * buyRecord.price
                            buyRecord.costBasis = buyRecord.quantity * buyRecord.costPerShare
                            buyQueue.insert(buyRecord, at: 0)
                            remainingSellQuantity = 0
                        }
                    }
                }
                
                // If we couldn't match all shares, keep the remaining sell if the buy queue is not empty
                if ( (remainingSellQuantity > 0) && (!buyQueue.isEmpty) ) {
                    var modifiedRecord = record
                    modifiedRecord.quantity = -remainingSellQuantity
                    modifiedRecord.marketValue = remainingSellQuantity * record.price
                    modifiedRecord.costBasis = remainingSellQuantity * record.costPerShare
                    remainingRecords.append(modifiedRecord)
                }
            }
        }

        // Add any remaining buy records
        remainingRecords.append(contentsOf: buyQueue)

        // Sort final records by date
        remainingRecords.sort { $0.openDate < $1.openDate }

        // set the number of shares available to trade based on the number with a trade date more than 30 days ago.
        m_lastFilteredTransactionSharesAvailableToTrade = 0
        for record in remainingRecords {
            if( 30 < daysSinceDateString(dateString: record.openDate) ?? 0 ) {
                m_lastFilteredTransactionSharesAvailableToTrade = record.quantity + (m_lastFilteredTransactionSharesAvailableToTrade ?? 0.0)
            }
        }
        // for debugging, print the number of shares available to trade and the symbol
        print("********** ! shares available to trade: \(m_lastFilteredTransactionSharesAvailableToTrade ?? 0.0) for symbol: \(symbol)")
        // if this symbol has contracts in the m_symbolsWithContracts map, subtract 100 * the number of contracts from the shares availabe to trade.
        if let contracts = m_symbolsWithContracts[symbol] {
            for contract in contracts {
                let totalQuantity = (contract.longQuantity ?? 0.0) + (contract.shortQuantity ?? 0.0)
                m_lastFilteredTransactionSharesAvailableToTrade = (m_lastFilteredTransactionSharesAvailableToTrade ?? 0.0) - (totalQuantity * 100.0)
                // for debugging, print the change in shares available to trade, the symbol, and the result
                print("! change in shares available to trade: \(totalQuantity * 100.0) for symbol: \(symbol)")
                print("! result: \(m_lastFilteredTransactionSharesAvailableToTrade ?? 0.0)")
            }
        }
        

        m_lastFilteredPositionRecords = remainingRecords
        print("! returning \(m_lastFilteredPositionRecords.count) records")
        return m_lastFilteredPositionRecords
    } // computeTaxLots
    
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

    private func isNearZero(_ value: Double) -> Bool {
        return abs(value) < 0.0001
    }

    /**
     * fetchTransactionHistoryReduced - get transactions for a smaller time range for faster loading
     * This is used for initial display when we don't need the full 3 years of history
     */
    public func fetchTransactionHistoryReduced(quarters: Int = 4) async {
        print("=== fetchTransactionHistoryReduced - quarters: \(quarters) ===")
        //print("🔍 fetchTransactionHistoryReduced - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //print("🔍 fetchTransactionHistoryReduced - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }
        
        // Reset quarter delta for reduced fetch
        m_quarterDeltaLock.withLock {
            m_quarterDelta = 0
            m_transactionListLock.withLock {
                m_transactionList.removeAll(keepingCapacity: true)
            }
        }
        
        let initialSize: Int = m_transactionList.count
        
        // Fetch only the specified number of quarters
        await withTaskGroup(of: Void.self) { group in
            for quarter in 1...quarters {
                group.addTask {
                    let endDate = getDateNQuartersAgoStr(quarterDelta: quarter - 1)
                    let startDate = getDateNQuartersAgoStr(quarterDelta: quarter)
                    
                    print("  -- processing quarter: \(quarter)")
                    
                    // Fetch for all accounts in parallel
                    await withTaskGroup(of: [Transaction]?.self) { accountGroup in
                        for accountNumberHash in self.m_secrets.acountNumberHash {
                            accountGroup.addTask {
                                var transactionHistoryUrl = "\(accountWeb)/\(accountNumberHash.hashValue ?? "N/A")/transactions"
                                transactionHistoryUrl += "?startDate=\(startDate)"
                                transactionHistoryUrl += "&endDate=\(endDate)"
                                transactionHistoryUrl += "&types=TRADE"

                                guard let url = URL(string: transactionHistoryUrl) else {
                                    print("fetchTransactionHistoryReduced. Invalid URL")
                                    return nil
                                }

                                var request = URLRequest(url: url)
                                request.httpMethod = "GET"
                                request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
                                request.setValue("application/json", forHTTPHeaderField: "accept")
                                request.timeoutInterval = self.requestTimeout

                                do {
                                    let (data, response) = try await URLSession.shared.data(for: request)
                                    
                                    guard let httpResponse = response as? HTTPURLResponse else {
                                        print("Invalid response type")
                                        return nil
                                    }
                                    
                                    if httpResponse.statusCode != 200 {
                                        print("response code: \(httpResponse.statusCode)")
                                        // print data as a string
                                        print( "response data: \(String(data: data, encoding: .utf8) ?? "N/A")" )
                                        if let serviceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                                            serviceError.printErrors(prefix: "  fetchTransactionHistoryReduced ")
                                        }
                                        return nil
                                    }

                                    let decoder = JSONDecoder()
                                    return try decoder.decode([Transaction].self, from: data)
                                } catch {
                                    print("fetchTransactionHistoryReduced Error: \(error.localizedDescription)")
                                    return nil
                                }
                            }
                        }
                        
                        // Collect results from all accounts
                        var newTransactions: [Transaction] = []
                        for await transactions in accountGroup {
                            if let transactions = transactions {
                                newTransactions.append(contentsOf: transactions)
                            }
                        }
                        
                        // Add to main transaction list
                        self.m_transactionListLock.withLock {
                            self.m_transactionList.append(contentsOf: newTransactions)
                        }
                    }
                }
            }
            
            // Wait for all quarters to complete
            await group.waitForAll()
        }
        
        // Update quarter delta to reflect what we've fetched
        m_quarterDeltaLock.withLock {
            m_quarterDelta = quarters
        }
        
        print("Fetched \(m_transactionList.count - initialSize) transactions in \(quarters) quarters")
        
        // Sort and process transactions
        m_transactionListLock.withLock {
            m_transactionList.sort { $0.tradeDate ?? "0000" > $1.tradeDate ?? "0000" }
        }
        self.setLatestTradeDates()
    }

    /**
     * getContractsForSymbol - return the option contracts for a given underlying symbol
     */
    public func getContractsForSymbol(_ symbol: String) -> [Position]? {
        let contracts = m_symbolsWithContracts[symbol]
        print("🔍 getContractsForSymbol: Symbol '\(symbol)' has \(contracts?.count ?? 0) contracts")
        if let contracts = contracts {
            for contract in contracts {
                print("  📋 Contract: \(contract.instrument?.symbol ?? "nil") - \(contract.instrument?.description ?? "nil")")
                // also print the maturityDate and expirationDate
                // print("         instrument:  \(contract.instrument?.dump() ?? "nil")")
            }
        }
        return contracts
    }
} // SchwabClient
