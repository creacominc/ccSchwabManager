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


// MARK: - Symbol Contract Summary Structure

struct SymbolContractSummary {
    let minimumDTE: Int?
    let contractCount: Int
    let totalQuantity: Double
    
    init(contracts: [Position]) {
        var minDTE: Int?
        var totalQty: Double = 0.0
        
        for position in contracts {
            // Calculate DTE for this contract
            if let dte = extractExpirationDate(from: position.instrument?.symbol, description: position.instrument?.description) {
                if minDTE == nil || dte < minDTE! {
                    minDTE = dte
                }
            }
            
            // Sum up quantities
            totalQty += (position.longQuantity ?? 0.0) + (position.shortQuantity ?? 0.0)
        }
        
        self.minimumDTE = minDTE
        self.contractCount = contracts.count
        self.totalQuantity = totalQty
    }

}

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
    public let maxQuarterDelta : Int = 20 // 5 years
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
    private var m_symbolsWithContracts : [String: SymbolContractSummary] = [:]
    private var m_lastFilteredTransactionSymbol : String? = nil
    private var m_lastFilteredTaxLotSymbol : String? = nil
    private var m_transactionList : [Transaction] = []
    private let m_transactionListLock = NSLock()  // Add mutex for m_transactionList
    private var m_lastFilteredTransactions : [Transaction] = []
    private var m_lastFilteredTransaxtionsSourceCount : Int = 0
    private let m_filteredTransactionsLock: NSLock = NSLock()  // Add mutex for filtered transactions
    private var m_lastFilteredTransactionSharesAvailableToTrade : Double? = nil
    private var m_lastfilteredTransactionsYears : Int = 0
    private var m_lastFilteredPositionRecords : [SalesCalcPositionsRecord] = []
    private var m_orderList : [Order] = []
    private let m_lastFilteredPriceHistoryLock: NSLock = NSLock()
    private var m_lastFilteredPriceHistory: CandleList?
    private var m_lastFilteredPriceHistorySymbol: String = ""
    private let m_quarterDeltaLock: NSLock = NSLock()  // Add mutex for m_quarterDelta
    private var m_lastFilteredATRSymbol : String = ""
    private var m_lastFilteredATR : Double = 0.0
    private var m_lastFilteredATRLock: NSLock = NSLock()  // mutex for ATR
    private var m_lastShareCountSymbol: String = ""
    private var m_lastShareCount: Double = 0.0
    private var m_lastShareCountLock: NSLock = NSLock()
    
    // Create a logger for this class
    private let logger = Logger(subsystem: "com.creacom.ccSchwabManager", category: "SchwabClient")
    
    // Add a lock for loadingDelegate synchronization
    private let loadingDelegateLock = NSLock()

    private let m_fetchTimeout: TimeInterval = 5.0  // 5 second timeout for each fetch attempt

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

        // lock last share count
        m_lastShareCountLock.lock()
        defer {
            m_lastShareCountLock.unlock()
        }
        
        if m_lastShareCountSymbol == symbol {
            return m_lastShareCount
        }

        var shareCount: Double = 0.0
        
        // Find the position for this symbol
        for account in m_accounts {
            if let positions = account.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        shareCount += ((position.longQuantity ?? 0.0) + (position.shortQuantity ?? 0.0))
                        // break out of the inner loop and continue with accounts.
                        break
                    }
                }
            }
        }
        // print( "  -- getShareCount: returning \(shareCount) shares for symbol \(symbol)" )
        return shareCount
    }

    private func getAveragePrice(symbol: String) -> Double {
        print("=== getAveragePrice \(symbol) ===")

        var averagePrice: Double = 0.0
        
        // Find the position for this symbol
        for account in m_accounts {
            if let positions = account.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        averagePrice = position.averagePrice ?? 0.0
                        print("  --- Found average price: $\(averagePrice)")
                        return averagePrice
                    }
                }
            }
        }
        
        print("  --- No position found for symbol \(symbol), returning 0.0")
        return averagePrice
    }

    /**
     * getComputedPriceForTransaction - get the computed price for a transaction
     * 
     * For merged/renamed securities, the original transaction may have a price of 0.00.
     * This function returns the computed cost-per-share from the tax lots if available,
     * otherwise returns the original price from the transaction.
     */
    public func getComputedPriceForTransaction(_ transaction: Transaction, symbol: String) -> Double {
        print("=== getComputedPriceForTransaction ===")
        
        // Get the original price from the transaction
        guard let transferItem = transaction.transferItems.first(where: { $0.instrument?.symbol == symbol }) else {
            print("  --- No transfer item found for symbol \(symbol)")
            return 0.0
        }
        
        let originalPrice = transferItem.price ?? 0.0
        print("  --- Original price: $\(originalPrice)")
        
        // If the original price is not zero, return it
        if originalPrice > 0.0 {
            print("  --- Returning original price: $\(originalPrice)")
            return originalPrice
        }
        
        // For zero-price transactions, check if we have computed tax lots
        let taxLots = computeTaxLots(symbol: symbol)
        guard !taxLots.isEmpty else {
            print("  --- No tax lots available")
            return originalPrice
        }
        
        // Parse the transaction date to match with tax lots
        guard let tradeDate = transaction.tradeDate,
              let date = ISO8601DateFormatter().date(from: tradeDate) else {
            print("  --- Could not parse transaction date")
            return originalPrice
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let transactionDateString = formatter.string(from: date)
        
        print("  --- Transaction date: \(transactionDateString)")
        
        // Find the matching tax lot by date and quantity
        let transferItemAmount = transferItem.amount ?? 0.0
        for taxLot in taxLots {
            print("  --- Checking tax lot: \(taxLot.openDate), quantity: \(taxLot.quantity)")
            
            // Check if this tax lot matches the transaction
            if taxLot.openDate == transactionDateString && abs(taxLot.quantity - transferItemAmount) < 0.01 {
                print("  --- Found matching tax lot with computed cost: $\(taxLot.costPerShare)")
                return taxLot.costPerShare
            }
        }
        
        print("  --- No matching tax lot found, returning original price: $\(originalPrice)")
        return originalPrice
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
        
        // Also clear any stuck refresh token operations
        m_refreshAccessToken_running = false
        
        // Cancel any ongoing network requests by invalidating the URLSession
        URLSession.shared.invalidateAndCancel()
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
                    // Add a small delay to prevent rapid retries
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await fetchAccounts(retry: false)
                } else {
                    // Log the error for debugging
                    print("fetchAccounts failed with status code: \(httpResponse.statusCode)")
                    if let errorData = String(data: data, encoding: .utf8) {
                        print("Error response: \(errorData)")
                    }
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
            
            // First, collect all option positions by underlying symbol
            var positionsByUnderlying: [String: [Position]] = [:]
            
            for account in m_accounts {
                if let positions = account.securitiesAccount?.positions {
                    for position in positions {
                        // for every position, look for an option assetType
                        if let instrument = position.instrument,
                           let assetType = instrument.assetType,
                           assetType == .OPTION,
                           let underlyingSymbol = instrument.underlyingSymbol {
                                // Add to the collection for this underlying symbol
                                if positionsByUnderlying[underlyingSymbol] == nil {
                                    positionsByUnderlying[underlyingSymbol] = []
                                }
                                // Check if this position is already in the list by comparing symbols
                                if let symbol = instrument.symbol {
                                    let positionExists = positionsByUnderlying[underlyingSymbol]!.contains { existingPosition in
                                        existingPosition.instrument?.symbol == symbol
                                    }
                                    if !positionExists {
                                        positionsByUnderlying[underlyingSymbol]!.append(position)
                                        // print("  Added option contract: \(symbol) - \(instrument.description ?? "No description")")
                                    }
                                }
                        }
                    }
                }
            }
            
            // Now create SymbolContractSummary for each underlying symbol
            for (underlyingSymbol, positions) in positionsByUnderlying {
                let summary = SymbolContractSummary(contracts: positions)
                m_symbolsWithContracts[underlyingSymbol] = summary
                // print("Created summary for \(underlyingSymbol): \(summary.contractCount) contracts, min DTE: \(summary.minimumDTE ?? -1)")
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
            print("fetchPriceHistory. Invalid URL for \(symbol)")
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
            print("fetchPriceHistory - Error for \(symbol): \(error.localizedDescription)")
            return nil
        }
        
        guard let data = responseData else {
            print("fetchPriceHistory. No data received for \(symbol)")
            return nil
        }
        
        if httpResponse?.statusCode != 200 {
            print("fetchPriceHistory - Failed to fetch price history for \(symbol). code = \(httpResponse?.statusCode ?? -1)")
            // Try to decode error response for debugging
            if let errorString = String(data: data, encoding: .utf8) {
                print("fetchPriceHistory - Error response for \(symbol): \(errorString)")
            }
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            m_lastFilteredPriceHistory = try decoder.decode(CandleList.self, from: data)
            
            // Validate the returned data
            guard let candleList = m_lastFilteredPriceHistory else {
                print("fetchPriceHistory - Failed to decode CandleList for \(symbol)")
                return nil
            }
            
            // Check if we have valid candles
            let validCandles = candleList.candles.filter { candle in
                guard let high = candle.high, let low = candle.low, let close = candle.close else {
                    return false
                }
                return high > 0 && low > 0 && close > 0 && high >= low
            }
            
            print("fetchPriceHistory - Fetched \(candleList.candles.count) total candles, \(validCandles.count) valid candles for \(symbol)")
            
            if validCandles.count < 2 {
                print("fetchPriceHistory - Warning: Insufficient valid candles for ATR calculation for \(symbol)")
            }
            
            return m_lastFilteredPriceHistory
        } catch {
            print("fetchPriceHistory - Error decoding data for \(symbol): \(error.localizedDescription)")
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
//        print("     quoteUrl: \(quoteUrl)")
        
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
            
            // print("fetchQuote - Successfully fetched quote for \(symbol)")
            //
            // // Log detailed fundamental information
            // if let fundamental = quoteData.fundamental {
            //     print("fetchQuote - Fundamental data for \(symbol):")
            //     print("  divYield: \(fundamental.divYield ?? 0)")
            //     print("  divAmount: \(fundamental.divAmount ?? 0)")
            //     print("  divFreq: \(fundamental.divFreq ?? 0)")
            //     print("  eps: \(fundamental.eps ?? 0)")
            //     print("  peRatio: \(fundamental.peRatio ?? 0)")
            //
            //     if let divYield = fundamental.divYield {
            //         print("fetchQuote - Raw dividend yield for \(symbol): \(divYield)%")
            //         print("fetchQuote - Dividend yield is already a percentage value")
            //     }
            // } else {
            //     print("fetchQuote - No fundamental data available for \(symbol)")
            // }
            
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
    public func computeATR( symbol : String )  -> Double
    {
        print("=== computeATR \(symbol) ===")

        // Check cache first without holding lock
        if( symbol == m_lastFilteredATRSymbol )
        {
            print( "  computeATR - returning cached." )
            return m_lastFilteredATR
        }
 
        // Hold lock for the entire operation to prevent race conditions
        m_lastFilteredATRLock.lock()
        defer {
            m_lastFilteredATRLock.unlock()
        }
        
        // Double-check cache after acquiring lock
        if( symbol == m_lastFilteredATRSymbol )
        {
            print( "  computeATR - returning cached (after lock)." )
            return m_lastFilteredATR
        }

        guard let priceHistory : CandleList =  self.fetchPriceHistory( symbol: symbol ) else {
            print("computeATR Failed to fetch price history for \(symbol).")
            // Don't set the symbol if we failed to get data
            return 0.0
        }

        // Get a local copy of the candles array to prevent race conditions
        let candles = priceHistory.candles
        let candlesCount = candles.count
        
        // Need at least 2 candles to compute ATR
        guard candlesCount > 1 else {
            print("computeATR: Need at least 2 candles, got \(candlesCount) for \(symbol)")
            // Don't set the symbol if we don't have enough data
            return 0.0
        }
        
        // Validate that we have valid price data
        let validCandles = candles.filter { candle in
            guard let high = candle.high, let low = candle.low, let close = candle.close else {
                return false
            }
            return high > 0 && low > 0 && close > 0 && high >= low
        }
        
        guard validCandles.count > 1 else {
            print("computeATR: Need at least 2 valid candles, got \(validCandles.count) for \(symbol)")
            // Don't set the symbol if we don't have valid data
            return 0.0
        }
        
        var close : Double  = priceHistory.previousClose ?? 0.0
        var m_lastFilteredATR : Double  = 0.0
        
        /*
         * Compute the ATR as the average of the True Range.
         * The True Range is the maximum of absolute values of the High - Low, High - previous Close, and Low - previous Close
         */
        let length : Int  =  min( validCandles.count, 21 )
        let startIndex : Int = validCandles.count - length
        
        // Additional safety check
        guard startIndex >= 0 && startIndex < validCandles.count else {
            print("computeATR: Invalid startIndex \(startIndex) for validCandlesCount \(validCandles.count) for \(symbol)")
            return 0.0
        }
        
        for indx in 0..<length
        {
            let position = startIndex + indx
            
            // Bounds check for current position - recheck validCandles.count in case array was modified
            guard position >= 0 && position < validCandles.count else {
                print("computeATR: Position \(position) out of bounds for validCandlesCount \(validCandles.count) for \(symbol)")
                continue
            }
            
            let candle : Candle  = validCandles[position]
            
            // Safe access to previous close
            let prevClose : Double
            if position == 0 {
                prevClose = priceHistory.previousClose ?? 0.0
            } else {
                let prevPosition = position - 1
                guard prevPosition >= 0 && prevPosition < validCandles.count else {
                    print("computeATR: Previous position \(prevPosition) out of bounds for validCandlesCount \(validCandles.count) for \(symbol)")
                    continue
                }
                prevClose = validCandles[prevPosition].close ?? 0.0
            }
            
            let high : Double  = candle.high ?? 0.0
            let low  : Double  = candle.low ?? 0.0
            let tr : Double = max( abs( high - low ), abs( high - prevClose ), abs( low - prevClose ) )
            close = candle.close ?? 0.0
            m_lastFilteredATR = ( (m_lastFilteredATR * Double(indx)) + tr ) / Double(indx+1)
        }
        
        // Validate final values before returning
        guard close > 0 && m_lastFilteredATR > 0 else {
            print("computeATR: Invalid final values - close: \(close), ATR: \(m_lastFilteredATR) for \(symbol)")
            return 0.0
        }
        
        // Set the symbol and ATR only if we successfully calculated a valid value
        m_lastFilteredATRSymbol = symbol
        m_lastFilteredATR = (m_lastFilteredATR * 1.08 / close * 100.0)
        
        print("computeATR: Successfully calculated ATR: \(m_lastFilteredATR)% for \(symbol)")
        
        // return the ATR as a percent.
        return m_lastFilteredATR
    }
    
    /**
     * clearATRCache - clear the ATR cache to force fresh calculation
     */
    public func clearATRCache() {
        m_lastFilteredATRLock.lock()
        defer { m_lastFilteredATRLock.unlock() }
        
        m_lastFilteredATRSymbol = ""
        m_lastFilteredATR = 0.0
        print("computeATR: Cleared ATR cache")
    }
    
    /**
     * clearPriceHistoryCache - clear the price history cache to force fresh data fetch
     */
    public func clearPriceHistoryCache() {
        m_lastFilteredPriceHistoryLock.lock()
        defer { m_lastFilteredPriceHistoryLock.unlock() }
        
        m_lastFilteredPriceHistorySymbol = ""
        m_lastFilteredPriceHistory = nil
        print("fetchPriceHistory: Cleared price history cache")
    }
    
    /**
     * clearAllCaches - clear all caches for debugging purposes
     */
    public func clearAllCaches() {
        clearATRCache()
        clearPriceHistoryCache()
        print("SchwabClient: Cleared all caches")
    }
    
    /**
     * testATRCalculation - test ATR calculation with sample data
     */
    public func testATRCalculation() {
        print("=== testATRCalculation ===")
        
        // Create sample candle data
        let sampleCandles = [
            Candle(close: 100.0, high: 105.0, low: 98.0),
            Candle(close: 102.0, high: 107.0, low: 99.0),
            Candle(close: 101.0, high: 103.0, low: 100.0),
            Candle(close: 104.0, high: 106.0, low: 101.0),
            Candle(close: 103.0, high: 105.0, low: 102.0)
        ]
        
        let sampleCandleList = CandleList(
            candles: sampleCandles,
            previousClose: 99.0
        )
        
        // Temporarily set the price history cache
        m_lastFilteredPriceHistoryLock.lock()
        m_lastFilteredPriceHistory = sampleCandleList
        m_lastFilteredPriceHistorySymbol = "TEST"
        m_lastFilteredPriceHistoryLock.unlock()
        
        // Test ATR calculation
        let atrValue = computeATR(symbol: "TEST")
        print("Test ATR value: \(atrValue)%")
        
        // Clear test data
        clearAllCaches()
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
            print(" --- fetchTransactionHistorySync -  maxQuarterDelta reached")
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
        let endDate = getDateNQuartersAgoStrForEndDate(quarterDelta: newQuarterDelta - 1)
        let startDate = getDateNQuartersAgoStr(quarterDelta: newQuarterDelta)

        print("  -- processing quarter delta: \(newQuarterDelta)")

        // Create a task group to handle multiple account requests concurrently
        await withTaskGroup(of: [Transaction]?.self) { group in
            // Add a task for each account
            for accountNumberHash in self.m_secrets.acountNumberHash {
                for transactionType in [ TransactionType.receiveAndDeliver, TransactionType.trade ] {
                            group.addTask {
                                var transactionHistoryUrl = "\(accountWeb)/\(accountNumberHash.hashValue ?? "N/A")/transactions"
                                transactionHistoryUrl += "?startDate=\(startDate)"
                                transactionHistoryUrl += "&endDate=\(endDate)"
                                transactionHistoryUrl += "&types=\(transactionType.rawValue)"
                        
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
                            let transactions = try decoder.decode([Transaction].self, from: data)

                            return transactions
                        } catch {
                            print("fetchTransactionHistory Error: \(error.localizedDescription)")
                            print("   detail:  \(error)")
                            return nil
                        }
                    } // group.addTask
                }
            } // for accountNumberHash

            // Collect results from all tasks
            var newTransactions: [Transaction] = []
            for await transactions in group {
                if let transactions = transactions {
                    newTransactions.append(contentsOf: transactions)
                }
            }
            m_transactionListLock.withLock {
                addTransactionsWithoutSorting(newTransactions)
            }
        } // await withTaskGroup

        print("Fetched \(m_transactionList.count - initialSize) transactions")
        
        // Sort all transactions once at the end for better efficiency
        // This is much more efficient than sorting after each batch:
        // - Single O(n log n) sort instead of multiple sorts
        // - Better performance for large datasets
        m_transactionListLock.withLock {
            sortTransactions()
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
//        print( "    ==== getTransactionsFor \(symbol ?? "nil")  quarters: \(quarterDeltaForLogging) ====" )
//        print("    ==== getTransactionsFor Current transaction list size: \(m_transactionList.count)")
        
        if( nil == symbol ) {
            print( "getTransactionsFor \(symbol ?? "nil")  -  No symbol provided" )
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
            // print( "    ==== getTransactionsFor   !!!!! cleared filtered transactions" )
            // get the filtered transactions for the security and fetch more until we have some or the retries are exhausted.
            m_lastFilteredTransactions =  m_transactionList.filter { transaction in
                // Check if the symbol is nil or if any transferItem in the transaction matches the symbol
                let matches = transaction.transferItems.contains { $0.instrument?.symbol == symbol }
                return matches // return from closure, not from the method
            }
            // print("    ==== getTransactionsFor Found \(m_lastFilteredTransactions.count) matching transactions.  Quarter: \(quarterDeltaForLogging) of \(self.maxQuarterDelta)")

            // Fetch more records if needed, but with proper termination conditions
            var fetchAttempts = 0
            let maxFetchAttempts = 3  // Limit the number of fetch attempts
            
            while( (self.maxQuarterDelta > quarterDeltaForLogging) && 
                   (self.m_lastFilteredTransactions.count == 0) && 
                   (fetchAttempts < maxFetchAttempts) ) {
                print( "     -- getTransactionsFor \(symbol ?? "nil")  - still no records, fetching again (attempt \(fetchAttempts + 1)/\(maxFetchAttempts))" )
                fetchAttempts += 1
                
                // Use DispatchGroup to wait for the async operation with timeout
                let group = DispatchGroup()
                group.enter()
                
                // Start the fetch operation
                Task {
                    await self.fetchTransactionHistory()
                    group.leave()
                }
                
                // Wait for completion or timeout
                let result = group.wait(timeout: .now() + m_fetchTimeout)
                if result == .timedOut {
                    print("     -- getTransactionsFor \(symbol ?? "nil")  - fetch attempt \(fetchAttempts) timed out after \(m_fetchTimeout) seconds for  \(symbol ?? "nil")")
                }
                else {
                    // Re-filter after potential new data
                    m_lastFilteredTransactions =  m_transactionList.filter { transaction in
                        // Check if the symbol is nil or if any transferItem in the transaction matches the symbol
                        let matches = symbol == nil || transaction.transferItems.contains { $0.instrument?.symbol == symbol }
                        return matches
                    }
                    print("  -- getTransactionsFor \(symbol ?? "nil")  - Found \(m_lastFilteredTransactions.count) matching transactions after fetch")
                }
            }
            
            if fetchAttempts >= maxFetchAttempts && m_lastFilteredTransactions.count == 0 {
                print("Reached maximum fetch attempts without finding transactions for symbol: \(symbol ?? "nil")")
            }
            
            // Calculate shares available for trading
            if let symbol = symbol {
                // We'll compute shares available for trading separately to avoid circular dependency
                // This will be done after tax lots are computed
                print("=== Shares Available for Trading Calculation ===")
                print("Symbol: \(symbol)")
                print("Shares available for trading will be computed after tax lots")
            }
        }
        else {
            print( "  -- getTransactionsFor  same symbol \(symbol ?? "nil") and count as last time - returning cached" )
        }
        // return the transactionlist where the symbol matches what is provided
        print( " --- getTransactionsFor \(symbol ?? "nil")  returning \(m_lastFilteredTransactions.count) transactions -- " )
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
     * Compute shares available for trading using tax lots
     * This should be called after computeTaxLots to avoid circular dependency
     */
    public func computeSharesAvailableForTrading(symbol: String, taxLots: [SalesCalcPositionsRecord]) -> Double {
        print("=== computeSharesAvailableForTrading for \(symbol) ===")
        print("  Using provided tax lots for accurate share calculation")
        print("  Found \(taxLots.count) tax lots for \(symbol)")
        
        // Calculate shares held for over 30 days from tax lots
        var sharesOver30Days: Double = 0.0
        let currentDate = Date()
        
        print("  === Processing Tax Lots ===")
        for (index, taxLot) in taxLots.enumerated() {
            // Parse tax lot date - format is "2024-12-03 14:34:41"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.timeZone = TimeZone.current
            
            guard let date = dateFormatter.date(from: taxLot.openDate)
            else {
                print("    Tax lot \(index): Skipping invalid date: \(taxLot.openDate)")
                continue
            }
            
            // Calculate days since tax lot was created
            let daysSinceTaxLot = Calendar.current.dateComponents([.day], from: date, to: currentDate).day ?? 0
            
            if daysSinceTaxLot > 30 {
                sharesOver30Days += taxLot.quantity
                print("    Tax lot \(index): \(taxLot.quantity) shares from \(taxLot.openDate) held for \(daysSinceTaxLot) days (ELIGIBLE)")
            } else {
                print("    Tax lot \(index): \(taxLot.quantity) shares from \(taxLot.openDate) held for \(daysSinceTaxLot) days (NOT ELIGIBLE)")
            }
        }
        
        print("  Total shares held for over 30 days: \(sharesOver30Days)")
        
        // Get shares under contract
        let sharesUnderContract = getContractCountForSymbol(symbol) * 100.0
        print("  Shares under contract: \(sharesUnderContract) (contracts: \(getContractCountForSymbol(symbol)))")
        
        // Calculate available shares
        let availableShares = sharesOver30Days - sharesUnderContract
        let finalAvailableShares = max(0.0, availableShares)
        
        print("  === Final Calculation ===")
        print("    Shares over 30 days: \(sharesOver30Days)")
        print("    Shares under contract: \(sharesUnderContract)")
        print("    Available shares: \(finalAvailableShares)")
        print("    Total shares owned: \(taxLots.reduce(0.0) { $0 + $1.quantity })")
        
        // Store the result for later retrieval
        m_lastFilteredTransactionSharesAvailableToTrade = finalAvailableShares
        
        return finalAvailableShares
    }
    
    /**
     * fetchOrderHistory
     *
     * /orders
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
                // ignore order status values that are not active orders
                if status == .rejected || status == .canceled || status == .replaced || status == .expired || status == .filled {
                    continue
                }
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
                            let orders = try decoder.decode([Order].self, from: data)

                            return orders
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
//                    print("Adding \(orders.count) orders from status query")
//                    for order in orders {
//                        if let orderId = order.orderId {
//                            print("  Adding order ID: \(orderId), Status: \(order.status?.rawValue ?? "nil")")
//                        }
//                    }
                    m_orderList.append(contentsOf: orders)
                }
            } // append orders
        } // await
        
        print("Fetched \(m_orderList.count) orders for all accounts")
        
        // Deduplicate orders by orderId to ensure uniqueness
        let uniqueOrders = Dictionary(grouping: m_orderList, by: { $0.orderId })
            .compactMap { (orderId, orders) in
                // If there are multiple orders with the same ID, take the first one
                // This could happen if the same order appears in multiple status queries
                // guard let orderId = orderId else { return orders.first }
                // print("Found \(orders.count) orders with ID \(orderId), keeping first one")
                return orders.first
            }
        
        m_orderList = uniqueOrders
        print("After deduplication: \(m_orderList.count) unique orders")
        
        updateSymbolsWithOrders()
    }
    
    private func updateSymbolsWithOrders() {
        // Clear existing symbols with orders
        m_symbolsWithOrders.removeAll(keepingCapacity: true)
        
        // update the m_symbolsWithOrders dictionary with each symbol in the orderList with orders that are in awaiting states
        for order in m_orderList {
            if let activeStatus = ActiveOrderStatus(from: order.status ?? .unknown, order: order) {
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
                        if let childActiveStatus = ActiveOrderStatus(from: childOrder.status ?? .unknown, order: childOrder) {
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

    // cancel select order 
    public func cancelOrders( orderIds: [Int64] ) async -> (success: Bool, errorMessage: String?) {
        print("=== cancelOrders ===")
        print("🎯 Cancelling \(orderIds.count) orders: \(orderIds)")
        print("📋 Order IDs to cancel: \(orderIds.map { String($0) }.joined(separator: ", "))")
        
        loadingDelegate?.setLoading(true)
        defer {
            loadingDelegate?.setLoading(false)
        }

        /**
         * Cancel order URL:  /accounts/{accountNumber}/orders/{orderId}
         *
         * accountNumber string    The encrypted ID of the account
         * orderId int64           The ID of the order to cancel
         * 
         * curl -X "DELETE" 
         *  "https://api.schwabapi.com/trader/v1/accounts/<encrypted_account>/orders/<orderId>" 
         *  -H "accept: *" 
         *  -H "Authorization: Bearer I0......@"
         *
         * 
         */
        
        var failedOrders: [Int64] = []
        var errorMessages: [String] = []
        
        // Process each order cancellation in parallel
        await withTaskGroup(of: (orderId: Int64, success: Bool, errorMessage: String?).self) { group in
            for orderId in orderIds {
                group.addTask {
                    // Find the order by ID to get its account number
                    guard let order = self.m_orderList.first(where: { $0.orderId == orderId }) else {
                        return (orderId: orderId, success: false, errorMessage: "Order not found in order list")
                    }
                    
                    guard let orderAccountNumber = order.accountNumber else {
                        return (orderId: orderId, success: false, errorMessage: "Order does not have account number")
                    }
                    
                    // Find the account hash for this order's account number
                    guard let accountNumberHash = self.m_secrets.acountNumberHash.first(where: { 
                        $0.accountNumber == String(orderAccountNumber) 
                    }) else {
                        return (orderId: orderId, success: false, errorMessage: "Account hash not found for account number \(orderAccountNumber)")
                    }
                    
                    guard let hashValue = accountNumberHash.hashValue else {
                        return (orderId: orderId, success: false, errorMessage: "Invalid account hash value")
                    }
                    
                    let cancelOrderUrl = "\(accountWeb)/\(hashValue)/orders/\(orderId)"
                    
                    guard let url = URL(string: cancelOrderUrl) else {
                        return (orderId: orderId, success: false, errorMessage: "Invalid URL for order cancellation")
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "DELETE"
                    request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("*/*", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = self.requestTimeout
                    
                    // Log the request details for verification
                    print("🔍 DELETE REQUEST VERIFICATION:")
                    print("  📍 URL: \(cancelOrderUrl)")
                    print("  🆔 Order ID: \(orderId)")
                    print("  🏦 Order Account Number: \(orderAccountNumber)")
                    print("  🔑 Account Hash: \(hashValue)")
                    print("  🏷️  HTTP Method: \(request.httpMethod ?? "nil")")
                    print("  📋 Headers:")
                    print("    Authorization: Bearer \(String(self.m_secrets.accessToken.prefix(20)))...")
                    print("    Accept: \(request.value(forHTTPHeaderField: "Accept") ?? "nil")")
                    print("  ⏱️  Timeout: \(request.timeoutInterval) seconds")
                    print("  📊 Request would delete order \(orderId) from account \(orderAccountNumber) (hash: \(hashValue))")
                    print("  ✅ Request verification complete - ready to execute DELETE")
                    
                    
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        
                        guard let httpResponse = response as? HTTPURLResponse else {
                            return (orderId: orderId, success: false, errorMessage: "Invalid response type")
                        }
                        
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                            print("✅ Successfully cancelled order \(orderId)")
                            return (orderId: orderId, success: true, errorMessage: nil)
                        } else {
                            // Try to decode error response
                            let errorMessage: String
                            if let responseString = String(data: data, encoding: .utf8) {
                                errorMessage = "HTTP \(httpResponse.statusCode): \(responseString)"
                            } else {
                                errorMessage = "HTTP \(httpResponse.statusCode): Unknown error"
                            }
                            
                            print("❌ Failed to cancel order \(orderId): \(errorMessage)")
                            return (orderId: orderId, success: false, errorMessage: errorMessage)
                        }
                    } catch {
                        let errorMessage = "Network error: \(error.localizedDescription)"
                        print("❌ Error cancelling order \(orderId): \(errorMessage)")
                        return (orderId: orderId, success: false, errorMessage: errorMessage)
                    }
                }
            }
            
            // Collect results
            for await result in group {
                if !result.success {
                    failedOrders.append(result.orderId)
                    if let errorMessage = result.errorMessage {
                        errorMessages.append("Order \(result.orderId): \(errorMessage)")
                    }
                }
            }
        }
        
        // Remove successfully cancelled orders from the order list
        if failedOrders.isEmpty {
            // All orders were cancelled successfully, remove them from the order list
            m_orderList.removeAll { order in
                if let orderId = order.orderId {
                    return orderIds.contains(orderId)
                }
                return false
            }
            
            // Update symbols with orders
            updateSymbolsWithOrders()
            
            print("✅ SUCCESS: Cancelled all \(orderIds.count) orders successfully")
            print("📊 Final Results:")
            print("  🎯 Total orders requested: \(orderIds.count)")
            print("  ✅ Successfully cancelled: \(orderIds.count)")
            print("  ❌ Failed to cancel: 0")
            return (success: true, errorMessage: nil)
        } else {
            // Some orders failed to cancel
            let errorMessage = "Failed to cancel \(failedOrders.count) orders:\n" + errorMessages.joined(separator: "\n")
            print("❌ FAILURE: Cancellation failed")
            print("📊 Final Results:")
            print("  🎯 Total orders requested: \(orderIds.count)")
            print("  ✅ Successfully cancelled: \(orderIds.count - failedOrders.count)")
            print("  ❌ Failed to cancel: \(failedOrders.count)")
            print("  📝 Error details: \(errorMessage)")
            return (success: false, errorMessage: errorMessage)
        }
    }

    // place an order
    public func placeOrder( order: Order ) {
        print("=== placeOrder  ===")
        /**
         * /accounts/{accountNumber}/orders
         *
         * example order:
         *
            [
                {
                    "orderStrategyType": "OCO",
                    "complexOrderStrategyType": "NONE",
                    "orderId": 0,
                    "cancelable": true,
                    "editable": false,
                    "status": "AWAITING_PARENT_ORDER",
                    "enteredTime": <currentDateTime>,
                    "accountNumber": <accountNumber>,
                    "childOrderStrategies": [
                        {
                        "session": "NORMAL",
                        "duration": "GOOD_TILL_CANCEL",
                        "orderType": "TRAILING_STOP_LIMIT",
                        "complexOrderStrategyType": "NONE",
                        "quantity": <buy-quantity>,
                        "filledQuantity": 0,
                        "remainingQuantity": <buy-quantity>,
                        "requestedDestination": "AUTO",
                        "destinationLinkName": "AutoRoute",
                        "releaseTime": <submitTime>,
                        "stopType": "BID",
                            "priceLinkBasis": "LAST",
                        "priceLinkType": "PERCENT",
                        "priceOffset": 0.02,
                        "orderLegCollection": [
                            {
                            "orderLegType": "EQUITY",
                            "legId": 1,
                            "instrument": {
                                "assetType": "EQUITY",
                                "cusip": <hopefully we can get this from the instrument>,
                                "symbol": <symbol>,
                                "instrumentId": <hopefully we can get this from the instrument>
                            },
                            "instruction": "BUY",
                            "positionEffect": "OPENING",
                            "quantity": <buy-quantity>
                            }
                        ],
                        "orderStrategyType": "SINGLE",
                        "orderId": <0>,
                        "cancelable": true,
                        "editable": false,
                        "status": "AWAITING_RELEASE_TIME",
                        "enteredTime": <submitTime>,
                        "tag": "API_TOS:CHART",
                        "accountNumber": <accountNumber>
                        },
                        {
                        "session": "NORMAL",
                        "duration": "GOOD_TILL_CANCEL",
                        "orderType": "TRAILING_STOP_LIMIT",
                        "complexOrderStrategyType": "NONE",
                        "quantity": <sell-quantity>,
                        "filledQuantity": 0,
                        "remainingQuantity": <sell-quantity>,
                        "requestedDestination": "AUTO",
                        "destinationLinkName": "AutoRoute",
                        "releaseTime": <submitTime>,
                        "stopType": "ASK",
                        "priceLinkBasis": "LAST",
                        "priceLinkType": "PERCENT",
                        "priceOffset": -0.02,
                        "orderLegCollection": [
                            {
                            "orderLegType": "EQUITY",
                            "legId": 1,
                            "instrument": {
                                "assetType": "EQUITY",
                                "cusip": <hopefully we can get this from the instrument>,
                                "symbol": <symbol>,
                                "instrumentId": <hopefully we can get this from the instrument>
                            },
                            "instruction": "SELL",
                            "positionEffect": "CLOSING",
                            "quantity": <sell-quantity>
                            }
                        ],
                        "orderStrategyType": "SINGLE",
                        "orderId": <0>,
                        "cancelable": true,
                        "editable": false,
                        "status": "AWAITING_RELEASE_TIME",
                        "enteredTime": <submitTime>,
                        "tag": "API_TOS:CHART",
                        "accountNumber": <accountNumber>
                        }
                    ]
                }

            ]

         * https://api.schwabapi.com/trader/v1/accounts/<accountHash>/orders

         */
        // print the order
        print("  order: \(order)")
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
     * getOrderList - return all orders
     */
    public func getOrderList() -> [Order]
    {
        print("[SchwabClient] getOrderList() called, returning \(m_orderList.count) orders")
        
        // Debug: Print all order IDs to check for duplicates
        let orderIds = m_orderList.compactMap { $0.orderId }
        let uniqueOrderIds = Set(orderIds)
        print("[SchwabClient] Total order IDs: \(orderIds.count), Unique order IDs: \(uniqueOrderIds.count)")
        
        if orderIds.count != uniqueOrderIds.count {
            print("[SchwabClient] WARNING: Found duplicate order IDs!")
            let duplicates = Dictionary(grouping: orderIds, by: { $0 })
                .filter { $0.value.count > 1 }
                .map { $0.key }
            print("[SchwabClient] Duplicate order IDs: \(duplicates)")
        }
        
        return m_orderList
    }
    
    /**
     * handleMergedRenamedSecurities - handle cases where the earliest transaction has cost = 0
     * 
     * When a security has been merged or renamed, the earliest transaction (which is the last one
     * processed since we work backwards) may have a cost of 0.00. In this case, we need to compute
     * the cost-per-share based on the current share count and the difference between the costs for
     * the later tax lots and the overall cost.
     */
    private func handleMergedRenamedSecurities(_ taxLots: [SalesCalcPositionsRecord], symbol: String) -> [SalesCalcPositionsRecord] {
        print("=== handleMergedRenamedSecurities - processing \(taxLots.count) tax lots ===")
        
        guard !taxLots.isEmpty else {
            print("  --- No tax lots to process")
            return taxLots
        }
        
        // Sort by date (oldest first) to find the earliest transaction
        let sortedLots = taxLots.sorted { $0.openDate < $1.openDate }
        let earliestLot = sortedLots.first!
        
        // Check if the earliest transaction has cost = 0 (indicating a merge/rename)
        if earliestLot.costPerShare == 0.0 && earliestLot.quantity > 0 {
            print("  --- Found potential merged/renamed security: \(earliestLot.openDate), shares: \(earliestLot.quantity), cost: \(earliestLot.costPerShare)")
            
            // Get current share count from position
            let currentShareCount = getShareCount(symbol: symbol)
            print("  --- Current share count: \(currentShareCount)")
            
            // Check if the earliest transaction matches the current share count
            if abs(earliestLot.quantity - currentShareCount) < 0.01 {
                print("  --- Earliest transaction matches current share count - computing cost-per-share")
                
                // Calculate sum of later tax lots costs
                let laterTaxLots = sortedLots.dropFirst()
                let sumOfLaterTaxLotsCosts = laterTaxLots.reduce(0.0) { $0 + $1.costBasis }
                print("  --- Sum of later tax lots costs: $\(sumOfLaterTaxLotsCosts)")
                
                // Get average price from position
                let averagePrice = getAveragePrice(symbol: symbol)
                print("  --- Average price from position: $\(averagePrice)")
                
                // Compute the cost-per-share using the formula from README
                let receivedCostPerShare = ((averagePrice * earliestLot.quantity) - sumOfLaterTaxLotsCosts) / currentShareCount
                print("  --- Computed cost-per-share: $\(receivedCostPerShare)")
                
                // Update the earliest lot with the computed cost
                var updatedLots = taxLots
                if let index = updatedLots.firstIndex(where: { $0.id == earliestLot.id }) {
                    updatedLots[index].costPerShare = receivedCostPerShare
                    updatedLots[index].costBasis = receivedCostPerShare * earliestLot.quantity
                    updatedLots[index].gainLossDollar = (earliestLot.price - receivedCostPerShare) * earliestLot.quantity
                    updatedLots[index].gainLossPct = ((earliestLot.price - receivedCostPerShare) / receivedCostPerShare) * 100.0
                    
                    print("  --- Updated earliest lot with computed cost: $\(receivedCostPerShare)")
                }
                
                return updatedLots
            } else {
                print("  --- Earliest transaction does not match current share count - skipping")
            }
        } else {
            print("  --- No merged/renamed security detected")
        }
        
        return taxLots
    }

    /**
     * adjustForStockSplits - adjust tax lots for stock splits
     * 
     * When a security experiences a stock split, the additional shares are added to the account
     * and show as a transaction (buy) with a zero price. This function adjusts the prior holdings
     * by the split ratio and removes the zero-cost split transaction.
     */
    private func adjustForStockSplits(_ taxLots: [SalesCalcPositionsRecord]) -> [SalesCalcPositionsRecord] {
        print("=== adjustForStockSplits - processing \(taxLots.count) tax lots ===")
        
        // Sort by date (oldest first)
        let sortedLots = taxLots.sorted { $0.openDate < $1.openDate }
        var adjustedLots: [SalesCalcPositionsRecord] = []
        var i = 0
        
        while i < sortedLots.count {
            let currentLot = sortedLots[i]
            
            // Check if this is a zero-cost transaction (potential split)
            if currentLot.costPerShare == 0.0 && currentLot.quantity > 0 {
                print("  --- Found potential split transaction: \(currentLot.openDate), shares: \(currentLot.quantity), cost: \(currentLot.costPerShare)")
                
                // Calculate total shares before this split
                let sharesBeforeSplit = adjustedLots.reduce(0.0) { $0 + $1.quantity }
                let sharesFromSplit = currentLot.quantity
                let totalSharesAfterSplit = sharesBeforeSplit + sharesFromSplit
                
                if sharesBeforeSplit > 0 {
                    // Calculate split ratio
                    let splitRatio = totalSharesAfterSplit / sharesBeforeSplit
                    print("  --- Split calculation:")
                    print("    Shares before split: \(sharesBeforeSplit)")
                    print("    Shares from split: \(sharesFromSplit)")
                    print("    Total shares after split: \(totalSharesAfterSplit)")
                    print("    Split ratio: \(splitRatio)")
                    
                    // Adjust all prior holdings by the split ratio
                    for j in 0..<adjustedLots.count {
                        adjustedLots[j].quantity *= splitRatio
                        adjustedLots[j].costPerShare /= splitRatio
                        adjustedLots[j].marketValue = adjustedLots[j].quantity * adjustedLots[j].price
                        adjustedLots[j].costBasis = adjustedLots[j].quantity * adjustedLots[j].costPerShare
                        adjustedLots[j].gainLossDollar = (adjustedLots[j].price - adjustedLots[j].costPerShare) * adjustedLots[j].quantity
                        adjustedLots[j].gainLossPct = ((adjustedLots[j].price - adjustedLots[j].costPerShare) / adjustedLots[j].costPerShare) * 100.0
                        adjustedLots[j].splitMultiple *= splitRatio
                        
                        print("    Adjusted lot \(j): \(adjustedLots[j].openDate), shares: \(adjustedLots[j].quantity), cost: \(adjustedLots[j].costPerShare), basis: \(adjustedLots[j].costBasis), multiple: \(adjustedLots[j].splitMultiple)")
                    }
                    
                    print("  --- Removed split transaction and adjusted \(adjustedLots.count) prior lots")
                } else {
                    print("  --- No prior shares to adjust, skipping split transaction")
                }
                
                // Skip this zero-cost transaction (don't add it to adjustedLots)
                i += 1
                continue
            }
            
            // Add non-split transactions to adjusted lots
            adjustedLots.append(currentLot)
            i += 1
        }
        
        // Sort by highest cost basis (descending)
        adjustedLots.sort { $0.costBasis > $1.costBasis }
        
        print("=== adjustForStockSplits - returning \(adjustedLots.count) adjusted lots ===")
        return adjustedLots
    }

    /**
     * computeTaxLots - compute a list of tax lots as [SalesCalcPositionsRecord]
     *
     * We cannot get the tax lots from Schwab so we will need to compute it based on the transactions.
     */
    public func computeTaxLots(symbol: String, currentPrice: Double? = nil) -> [SalesCalcPositionsRecord] {
//        let debug : Bool = true
        // display the busy indicator
//        if debug { print("🔍 computeTaxLots - Setting loading to TRUE") }
        loadingDelegate?.setLoading(true)
        defer {
//            if debug { print("🔍 computeTaxLots - Setting loading to FALSE") }
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
        var totalTransactionsFound = 0
        var totalSharesFound = 0.0
        
        // Process transactions until we find zero shares or reach max quarters
        while fetchAttempts < maxFetchAttempts {
            fetchAttempts += 1
            print("  --- computeTaxLots iteration \(fetchAttempts)/\(maxFetchAttempts) ---")

            // Clear previous results
            m_lastFilteredPositionRecords.removeAll(keepingCapacity: true)

            // Get current share count
            var currentShareCount : Double = getShareCount(symbol: symbol)
            // Get quarter delta safely for logging
            let quarterDeltaForLogging = m_quarterDeltaLock.withLock {
                return m_quarterDelta
            }
            print("  --- computeTaxLots -- \(symbol) -- computeTaxLots() currentShareCount: \(currentShareCount) quarterDelta: \(quarterDeltaForLogging) --")

            // get last price for this security
            let lastPrice = currentPrice ?? fetchPriceHistory(symbol: symbol)?.candles.last?.close ?? 0.0
            showIncompleteDataWarning = true
            // Process all trade transactions - only process again if the number of transactions changes
            print( "  --- computeTaxLots  - calling getTransactionsFor(symbol: \(symbol))" )
            for transaction in self.getTransactionsFor(symbol: symbol)
            where ( (transaction.type == .trade) || (transaction.type == .receiveAndDeliver))
            {
                totalTransactionsFound += 1
                print("  --- Processing transaction \(totalTransactionsFound): \(transaction.tradeDate ?? "unknown"), type: \(transaction.type?.rawValue ?? "n/a"), activity: \(transaction.activityType ?? .UNKNOWN)")
                
                for transferItem in transaction.transferItems {
                    // find transferItems where the shares, value, and cost are not 0
                    guard let numberOfShares = transferItem.amount,
                          numberOfShares != 0.0,
                          transferItem.instrument?.symbol == symbol
                    else {
                        print("  --- Skipping transferItem: shares=\(transferItem.amount ?? 0), cost=\(transferItem.price ?? 0), symbol=\(transferItem.instrument?.symbol ?? "nil")")
                        continue
                    }
                    
                    totalSharesFound += numberOfShares
                    print("  --- Found transferItem: \(numberOfShares) shares at $\(transferItem.price ?? 0) on \(transaction.tradeDate ?? "unknown")")
                    
                    let gainLossDollar = (lastPrice - transferItem.price!) * numberOfShares
                    let gainLossPct = ((lastPrice - transferItem.price!) / transferItem.price!) * 100.0
                    
                    // Parse trade date
                    guard let tradeDate : String = try? Date(transaction.tradeDate ?? "1970-01-01T00:00:00+0000",
                                                  strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false)).dateString() else {
                        print( " -- Failed to parse date in trade.  transferItem: \(transferItem.dump())")
                        continue
                    }
                    
                    // Update share count (working backwards)
                    // For BUY transactions (positive shares): subtract the shares we bought
                    // For SELL transactions (negative shares): add back the shares we sold
                    if numberOfShares > 0 {
                        // BUY transaction - subtract shares
                        currentShareCount = ( (currentShareCount - numberOfShares) * 100000 ).rounded()/100000
                    } else {
                        // SELL transaction - add back shares (numberOfShares is negative, so we add abs value)
                        currentShareCount = ( (currentShareCount + abs(numberOfShares)) * 100000 ).rounded()/100000
                    }
                    
                    // Log the balance after each transaction
                    print("  --- Balance after transaction: \(numberOfShares) shares -> currentShareCount: \(currentShareCount)")
                    
                    // Add position record for this transaction
                    m_lastFilteredPositionRecords.append(
                        SalesCalcPositionsRecord(
                            openDate: tradeDate,
                            gainLossPct: gainLossPct,
                            gainLossDollar: gainLossDollar,
                            quantity: numberOfShares,
                            price: lastPrice,
                            costPerShare: transferItem.price!,
                            marketValue: numberOfShares * lastPrice,
                            costBasis: transferItem.price! * numberOfShares,
                            splitMultiple: 1.0  // Initial value, will be adjusted by splits if needed
                        )
                    )

                } // for transferItem

                // break if we find zero
                if isNearZero( currentShareCount ) {
                    showIncompleteDataWarning = false
                    print( "  -- computeTaxLots:  -- Found zero -- " )
                    print( "  -- computeTaxLots:  -- SUCCESS: Zero point found at iteration \(fetchAttempts) -- " )
                    break
                }
                // Don't break on negative share count - continue processing to find all buy transactions
                // The negative share count indicates we've encountered more sell transactions than buy transactions
                // but we need to continue to find all the buy transactions that account for our current position

            } // for transaction
            
            // Break if we've found zero shares or reached max quarters
            if ( isNearZero(currentShareCount) ) {
                print( "  -- computeTaxLots:  -- found near zero --  currentShareCount = \(currentShareCount)" )
                print( "  -- computeTaxLots:  -- SUCCESS: Zero point found after processing all transactions -- " )
                showIncompleteDataWarning = false
                break
            }
            // Don't break on negative share count - continue processing to find all buy transactions
            // The negative share count indicates we've encountered more sell transactions than buy transactions
            // but we need to continue to find all the buy transactions that account for our current position
            else if  ( self.maxQuarterDelta <= quarterDeltaForLogging )  {
//                showIncompleteDataWarning = true
                print( " -- Reached max quarter delta --" )
                print( " -- WARNING: Incomplete data - reached max quarter delta. Setting showIncompleteDataWarning = true --" )
                break
            }
            else if fetchAttempts >= maxFetchAttempts {
//                showIncompleteDataWarning = true
                print( " -- Reached max fetch attempts --" )
                print( " -- WARNING: Incomplete data - reached max fetch attempts. Setting showIncompleteDataWarning = true --" )
                break
            }
            else
            {
                print( " -- Fetching more records (attempt \(fetchAttempts)) --" )
                // Use DispatchGroup to wait for the async operation with timeout
                let group = DispatchGroup()
                group.enter()
                
                // Start the fetch operation
                Task {
                    await self.fetchTransactionHistory()
                    group.leave()
                }
                
                // Wait for completion or timeout
                let result = group.wait(timeout: .now() + m_fetchTimeout)
                if result == .timedOut {
                    print("   !!! fetch attempt \(fetchAttempts) timed out after \(m_fetchTimeout) seconds")
                }
            }
            
        }
        
        if fetchAttempts >= maxFetchAttempts {
            print("Warning: computeTaxLots reached maximum fetch attempts for symbol: \(symbol)")
            // invalid or incomplete warning
        }
        
        // Sort records by date (oldest first) and cost (highest first for same date)
        m_lastFilteredPositionRecords.sort { ($0.openDate < $1.openDate) || ($0.openDate == $1.openDate && ( ($0.costPerShare > $1.costPerShare) || ($0.quantity > $1.quantity) ) ) }
        
        // Match sells with buys using highest price up to that point
        var remainingRecords: [SalesCalcPositionsRecord] = []
        var buyQueue: [SalesCalcPositionsRecord] = []
//        if debug {  print( "  -- computeTaxLots:  -- removing sold shares -- " ) }
        for record : SalesCalcPositionsRecord in m_lastFilteredPositionRecords {
            // collect buy records until you find a sell trade record.
            if record.quantity > 0 {
//                if debug {  print( "  -- computeTaxLots:     ++++   adding buy to queue: \t\(record.openDate), \tquantity: \(record.quantity), \tcostPerShare: \(record.costPerShare)" ) }
                // Add buy record to queue
                buyQueue.append(record)
            } else {
//                if debug {  print( "  -- computeTaxLots:     ----   processing sell.  buy queue size: \(buyQueue.count),  sell: \t\(record.openDate), \tquantity: \(record.quantity), \tcostPerShare: \(record.costPerShare),  marketValue: \(record.marketValue)" ) }
                // If this is a .trade record, sort the buy queue by high price.  On trades, the cost-per-share will not be zero
                buyQueue.sort { ( ( 0.0 == $0.costPerShare) || ($0.costPerShare > $1.costPerShare) )}

//                // print the buy queue for debugging
//                if debug
//                {
//                    // print each record in the buy queue
//                    for buyRecord in buyQueue
//                    {
//                        print( "  -- computeTaxLots:         !         buyRecord: \t\(buyRecord.openDate), \t\(buyRecord.quantity), \t\(buyRecord.costPerShare)")
//                    }
//                }


                // Process sell record
                var remainingSellQuantity = abs(record.quantity)

                // Match sell with buys
                while remainingSellQuantity > 0 && !buyQueue.isEmpty {
                    var buyRecord = buyQueue.removeFirst()
                    let buyQuantity = buyRecord.quantity

//                    if debug {  print( "  -- computeTaxLots:         remainingSellQuantity: \(remainingSellQuantity),  buyQuantity: \(buyQuantity),  queue size: \(buyQueue.count)" ) }
//                    if debug {  print( "  -- computeTaxLots:         !         buyRecord: \t\(buyRecord.openDate), \t\(buyRecord.quantity), \t\(buyRecord.costPerShare)") }
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

        // Handle merged/renamed securities where the earliest transaction has cost = 0
        remainingRecords = handleMergedRenamedSecurities(remainingRecords, symbol: symbol)

        print("=== computeTaxLots Summary for \(symbol) ===")
        print("Total transactions processed: \(totalTransactionsFound)")
        print("Total shares found in transactions: \(totalSharesFound)")
        print("Current share count from position: \(getShareCount(symbol: symbol))")
        print("Final tax lots created: \(remainingRecords.count)")
        for (index, record) in remainingRecords.enumerated() {
            print("  Lot \(index): \(record.quantity) shares at $\(record.costPerShare) on \(record.openDate)")
        }
        print("=== End computeTaxLots Summary ===")

        m_lastFilteredPositionRecords = remainingRecords
        
        // Apply stock split adjustments
        m_lastFilteredPositionRecords = adjustForStockSplits(m_lastFilteredPositionRecords)
        
//        if debug { print("  -- computeTaxLots: returning \(m_lastFilteredPositionRecords.count) records for symbol \(symbol)") }
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
                                    let endDate = getDateNQuartersAgoStrForEndDate(quarterDelta: quarter - 1)
                let startDate = getDateNQuartersAgoStr(quarterDelta: quarter)
                    
                    print("  -- processing quarter: \(quarter)")
                    
                    // Fetch for all accounts in parallel
                    await withTaskGroup(of: [Transaction]?.self) { accountGroup in
                        for accountNumberHash in self.m_secrets.acountNumberHash {
                            for transactionType in [ TransactionType.receiveAndDeliver, TransactionType.trade ] {
                                accountGroup.addTask {
                                    var transactionHistoryUrl = "\(accountWeb)/\(accountNumberHash.hashValue ?? "N/A")/transactions"
                                    transactionHistoryUrl += "?startDate=\(startDate)"
                                    transactionHistoryUrl += "&endDate=\(endDate)"
                                    transactionHistoryUrl += "&types=\(transactionType.rawValue)"
                                    
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
                                        let transactions = try decoder.decode([Transaction].self, from: data)

//                                        /** @TODO:  REMOVE */
//                                        if true { // if TransactionType.receiveAndDeliver == transactionType {
//                                            // Check if any transaction contains "FAST" as a symbol
//                                            for transaction in transactions {
//                                                for transferItem in transaction.transferItems {
//                                                    if transferItem.instrument?.symbol  == "FAST" { // != "MMDA1" { //
//                                                        // print the data for debugging
//                                                        print(" ***** fetchTransactionHistoryReduced: Found \(transactionType.rawValue)  \(transferItem.instrument?.symbol ?? "n/a") transaction: ")
//                                                        print("       \(transaction.dump())")
//                                                        //break
//                                                    }
//                                                }
//                                            }
//                                        }
                                        
                                        return transactions
                                    } catch {
                                        print("fetchTransactionHistoryReduced Error: \(error.localizedDescription)")
                                        return nil
                                    }
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
                            self.addTransactionsWithoutSorting(newTransactions)
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
        
        // Sort all transactions once at the end for better efficiency
        // This is much more efficient than sorting after each batch:
        // - Single O(n log n) sort instead of multiple sorts
        // - Better performance for large datasets
        m_transactionListLock.withLock {
            sortTransactions()
        }
        self.setLatestTradeDates()
    }

    /**
     * getContractsForSymbol - return the option contracts for a given underlying symbol
     * Note: This method now returns nil since we no longer store individual positions
     */
    public func getContractsForSymbol(_ symbol: String) -> [Position]? {
        let summary = m_symbolsWithContracts[symbol]
        print("🔍 getContractsForSymbol: Symbol '\(symbol)' has \(summary?.contractCount ?? 0) contracts")
        if let summary = summary {
            print("  📋 Summary: \(summary.contractCount) contracts, min DTE: \(summary.minimumDTE ?? -1), total quantity: \(summary.totalQuantity)")
        }
        // Since we no longer store individual positions, return nil
        return nil
    }

    /**
     * get the number of contracts for the given symbol
     */
    public func getContractCountForSymbol(_ symbol: String) -> Double {
        guard let summary = m_symbolsWithContracts[symbol] else {
            return 0.0
        }
        return summary.totalQuantity
    }

    /**
     * getMinimumDTEForSymbol - return the minimum DTE for a given underlying symbol
     */
    public func getMinimumDTEForSymbol(_ symbol: String) -> Int? {
        guard let summary = m_symbolsWithContracts[symbol], summary.contractCount > 0 else {
            return nil
        }
        return summary.minimumDTE
    }


    /**
     * Calculate total shares for a transaction
     */
    private func totalShares(for transaction: Transaction) -> Double {
        return transaction.transferItems.lazy.reduce(0.0) { sum, item in
            sum + (item.amount ?? 0.0)
        }
    }

    /**
     * Sort transactions by date (newest first) and then by total shares (least to greatest)
     * This method should be called within a lock on m_transactionListLock
     */
    private func sortTransactions() {
        // Early exit if no transactions to sort
        guard !m_transactionList.isEmpty else { return }
        
        m_transactionList.sort { 
            // First sort by newest date
            let date1 = $0.tradeDate ?? "0000"
            let date2 = $1.tradeDate ?? "0000"
            
            if date1 != date2 {
                return date1 > date2
            }
            
            // If dates are equal, sort by total shares from least to greatest
            let totalShares1 = totalShares(for: $0)
            let totalShares2 = totalShares(for: $1)
            
            return totalShares1 < totalShares2
        }
    }

    /**
     * Add new transactions to the list without sorting
     * This method should be called within a lock on m_transactionListLock
     * Use this for bulk additions where sorting will be done at the end
     */
    private func addTransactionsWithoutSorting(_ newTransactions: [Transaction]) {
        guard !newTransactions.isEmpty else { return }
        
        // Create a set of existing transaction activityIds to avoid duplicates
        let existingActivityIds = Set(m_transactionList.compactMap { $0.activityId })
        let uniqueNewTransactions = newTransactions.filter { transaction in
            guard let activityId = transaction.activityId else { return true } // Include transactions without activityIds
            return !existingActivityIds.contains(activityId)
        }
        
        if uniqueNewTransactions.count != newTransactions.count {
            print("  -- Removed \(newTransactions.count - uniqueNewTransactions.count) duplicate transactions")
        }
        
        m_transactionList.append(contentsOf: uniqueNewTransactions)
    }

    // MARK: - Public Debug Methods
    
    var isRefreshTokenRunning: Bool {
        return m_refreshAccessToken_running
    }
    
    var isLoading: Bool {
        if let loadingState = loadingDelegate as? LoadingState {
            return loadingState.isLoading
        }
        return false
    }

} // SchwabClient
