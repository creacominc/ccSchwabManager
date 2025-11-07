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

// MARK: - Extract Strike Price from Symbol or Description
func extractStrike(from symbol: String?) -> Double? {
    // Primary method: Extract strike price from option symbol
    if let symbol: String = symbol {
        // Look for 8 consecutive digits after the 'C' or 'P'
        // Example: "B     250808C00025000" -> extract "00025000"
        let pattern: String = #"[CP](\d{8})"#
        if let regex: NSRegularExpression = try? NSRegularExpression(pattern: pattern),
           let match: NSTextCheckingResult = regex.firstMatch(in: symbol, range: NSRange(symbol.startIndex..., in: symbol)) {
            let strikeString: String = String(symbol[Range(match.range(at: 1), in: symbol)!])
            if var strike: Double = Double(strikeString) {
                strike = strike / 1000.00
                // AppLogger.shared.debug("🔍 extractStrike: \(strike)  for symbol: \(symbol)")
                return strike
            }
            else {
                AppLogger.shared.error("🔍 extractStrike: failed to convert \(strikeString)  for symbol: \(symbol)")
            }
        }
    }
    return nil
}


// MARK: - DateFormatter Extension for Schwab API

extension DateFormatter {
    static let schwabDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}

// MARK: - Symbol Contract Summary Structure

struct SymbolContractSummary {
    let minimumDTE: Int?
    let minimumStrike: Double?
    let contractCount: Int
    let totalQuantity: Double
    
    init(contracts: [Position]) {
        var minDTE: Int?
        var minStrike: Double?
        var totalQty: Double = 0.0
        
        for position: Position in contracts {
            // Calculate DTE for this contract
            if let dte: Int = extractExpirationDate(from: position.instrument?.symbol, description: position.instrument?.description) {
                if minDTE == nil || dte < minDTE! {
                    minDTE = dte
                }
            }
            // Calculate Strike for this contract
            if let strike: Double = extractStrike(from: position.instrument?.symbol) {
                if minStrike == nil || strike < minStrike! {
                    minStrike = strike
                }
            }
            // Sum up quantities
            totalQty += (position.longQuantity ?? 0.0) + (position.shortQuantity ?? 0.0)
        }
        
        self.minimumDTE = minDTE
        self.minimumStrike = minStrike
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
    
    // MARK: - Performance Optimization Cache
    private var m_taxLotCache: [String: (timestamp: Date, data: [SalesCalcPositionsRecord])] = [:]
    private let m_taxLotCacheLock = NSLock()
    private let m_taxLotCacheTimeout: TimeInterval = 300 // 5 minutes
    
    // Cache for transaction history to avoid repeated API calls
    private var m_transactionHistoryCache: [String: (timestamp: Date, data: [Transaction])] = [:]
    private let m_transactionHistoryCacheLock = NSLock()
    private let m_transactionHistoryCacheTimeout: TimeInterval = 600 // 10 minutes
    
    // Performance monitoring
    private var m_performanceMetrics: [String: (startTime: Date, endTime: Date?)] = [:]
    private let m_performanceMetricsLock = NSLock()

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
    
    // MARK: - Performance Optimization Methods
    private func startPerformanceTimer(_ operation: String) {
        m_performanceMetricsLock.withLock {
            m_performanceMetrics[operation] = (startTime: Date(), endTime: nil)
        }
    }
    
    private func endPerformanceTimer(_ operation: String) -> TimeInterval? {
        m_performanceMetricsLock.withLock {
            guard let metrics = m_performanceMetrics[operation] else { return nil }
            let endTime = Date()
            m_performanceMetrics[operation] = (startTime: metrics.startTime, endTime: endTime)
            return endTime.timeIntervalSince(metrics.startTime)
        }
    }
    
    private func logPerformance(_ operation: String) {
        if let duration = endPerformanceTimer(operation) {
            AppLogger.shared.info("⏱️ Performance: \(operation) completed in \(String(format: "%.2f", duration))s")
        }
    }
    
    // MARK: - Optimized Caching Methods
    private func getCachedTaxLots(for symbol: String) -> [SalesCalcPositionsRecord]? {
        m_taxLotCacheLock.withLock {
            guard let cacheEntry = m_taxLotCache[symbol] else { return nil }
            
            // Check if cache is still valid
            if Date().timeIntervalSince(cacheEntry.timestamp) < m_taxLotCacheTimeout {
                AppLogger.shared.debug("📦 Using cached tax lots for \(symbol) (age: \(String(format: "%.1f", Date().timeIntervalSince(cacheEntry.timestamp)))s)")
                return cacheEntry.data
            } else {
                // Cache expired, remove it
                m_taxLotCache.removeValue(forKey: symbol)
                return nil
            }
        }
    }
    
    private func cacheTaxLots(_ taxLots: [SalesCalcPositionsRecord], for symbol: String) {
        m_taxLotCacheLock.withLock {
            m_taxLotCache[symbol] = (timestamp: Date(), data: taxLots)
            AppLogger.shared.debug("📦 Cached \(taxLots.count) tax lots for \(symbol)")
        }
    }
    
    private func getCachedTransactionHistory(for symbol: String) -> [Transaction]? {
        m_transactionHistoryCacheLock.withLock {
            guard let cacheEntry = m_transactionHistoryCache[symbol] else { return nil }
            
            // Check if cache is still valid
            if Date().timeIntervalSince(cacheEntry.timestamp) < m_transactionHistoryCacheTimeout {
                AppLogger.shared.debug("📦 Using cached transaction history for \(symbol) (age: \(String(format: "%.1f", Date().timeIntervalSince(cacheEntry.timestamp)))s)")
                return cacheEntry.data
            } else {
                // Cache expired, remove it
                m_transactionHistoryCache.removeValue(forKey: symbol)
                return nil
            }
        }
    }
    
    private func cacheTransactionHistory(_ transactions: [Transaction], for symbol: String) {
        m_transactionHistoryCacheLock.withLock {
            m_transactionHistoryCache[symbol] = (timestamp: Date(), data: transactions)
            AppLogger.shared.debug("📦 Cached \(transactions.count) transactions for \(symbol)")
        }
    }
    
    // MARK: - Optimized Transaction Fetching
    private func getTransactionsForOptimized(symbol: String) -> [Transaction] {
        // First check cache
        if let cachedTransactions = getCachedTransactionHistory(for: symbol) {
            return cachedTransactions
        }
        
        // If not cached, fetch and cache
        let transactions = getTransactionsFor(symbol: symbol)
        cacheTransactionHistory(transactions, for: symbol)
        return transactions
    }
    
    // MARK: - Smart Tax Lot Calculation
    private func calculateOptimalTimeRange(for symbol: String, currentShares: Double) -> Int {
        // Start with a reasonable range based on current shares
        // If we have a lot of shares, we likely need more history
        if currentShares > 1000 {
            return 8 // 2 years
        } else if currentShares > 100 {
            return 6 // 1.5 years
        } else if currentShares > 10 {
            return 4 // 1 year
        } else {
            return 3 // 9 months
        }
    }
    
    private init()
    {
        self.m_secrets = Secrets()
    }


    func configure(with secrets: inout Secrets) {
        AppLogger.shared.debug( "=== configure - starting refresh thread. ===" )
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
        AppLogger.shared.debug( "=== getAccounts: accounts: \(self.m_accounts.count) ===" )
        return self.m_accounts
    }
    
    public func hasSymbols() -> Bool
    {
        AppLogger.shared.debug( "=== hasSymbols: accounts: \(self.m_accounts.count) ===" )
        var symbolCount : Int = 0
        for account in self.m_accounts
        {
            symbolCount += account.securitiesAccount?.positions.count ?? 0
        }
        AppLogger.shared.debug( "=== hasSymbols symbols: \(symbolCount) ===" )
        return (symbolCount > 0)
    }

    private func getShareCount(symbol: String) -> Double {
        AppLogger.shared.debug("=== getShareCount \(symbol) ===")

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
        // AppLogger.shared.debug( "  -- getShareCount: returning \(shareCount) shares for symbol \(symbol)" )
        return shareCount
    }

    private func getAveragePrice(symbol: String) -> Double {
        AppLogger.shared.debug("=== getAveragePrice \(symbol) ===")

        var averagePrice: Double = 0.0
        
        // Find the position for this symbol
        for account in m_accounts {
            if let positions = account.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        averagePrice = position.averagePrice ?? 0.0
                        AppLogger.shared.debug("  --- Found average price: $\(averagePrice)")
                        return averagePrice
                    }
                }
            }
        }
        
        AppLogger.shared.debug("  --- No position found for symbol \(symbol), returning 0.0")
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
        AppLogger.shared.debug("=== getComputedPriceForTransaction ===")
        
        // Get the original price from the transaction
        guard let transferItem = transaction.transferItems.first(where: { $0.instrument?.symbol == symbol }) else {
            AppLogger.shared.debug("  --- No transfer item found for symbol \(symbol)")
            return 0.0
        }
        
        let originalPrice = transferItem.price ?? 0.0
        //AppLogger.shared.debug("  --- Original price: $\(originalPrice)")
        
        // If the original price is not zero, return it
        if originalPrice > 0.0 {
            //AppLogger.shared.debug("  --- Returning original price: $\(originalPrice)")
            return originalPrice
        }
        
        // For zero-price transactions, check if we have computed tax lots
        let taxLots = computeTaxLots(symbol: symbol)
        guard !taxLots.isEmpty else {
            AppLogger.shared.debug("  --- No tax lots available")
            return originalPrice
        }
        
        // Parse the transaction date to match with tax lots
        guard let tradeDate = transaction.tradeDate,
              let date = ISO8601DateFormatter().date(from: tradeDate) else {
            AppLogger.shared.error("  --- Could not parse transaction date")
            return originalPrice
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let transactionDateString = formatter.string(from: date)
        
        AppLogger.shared.debug("  --- Transaction date: \(transactionDateString)")
        
        // Find the matching tax lot by date and quantity
        let transferItemAmount = transferItem.amount ?? 0.0
        for taxLot in taxLots {
            AppLogger.shared.debug("  --- Checking tax lot: \(taxLot.openDate), quantity: \(taxLot.quantity)")
            
            // Check if this tax lot matches the transaction
            if taxLot.openDate == transactionDateString && abs(taxLot.quantity - transferItemAmount) < 0.01 {
                AppLogger.shared.debug("  --- Found matching tax lot with computed cost: $\(taxLot.costPerShare)")
                return taxLot.costPerShare
            }
        }
        
        AppLogger.shared.debug("  --- No matching tax lot found, returning original price: $\(originalPrice)")
        return originalPrice
    }

    public func getSecrets() -> Secrets
    {
        return self.m_secrets
    }
    
    public func setSecrets( secrets: inout Secrets )
    {
        //AppLogger.shared.debug( "client setting secrets to: \(secrets.dump())")
        m_secrets = secrets
    }
    
    public func getSelectedAccountName() -> String
    {
        return self.m_selectedAccountName
    }
    
    public func setSelectedAccountName( name: String )
    {
        AppLogger.shared.debug( "setSelectedAccountName to \(name)" )
        self.m_selectedAccountName = name
    }
    
    /**
     * getAuthorizationUrl : Executes the completion with the URL for logging into and authenticating the connection.
     *
     */
    func getAuthorizationUrl(completion: @escaping (Result<URL, ErrorCodes>) -> Void)
    {
        AppLogger.shared.debug( "=== getAuthorizationUrl ===" )
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
        AppLogger.shared.debug( "=== extractCodeFromURL from \(url) ===" )
        // extract the code and session from the URL
        let urlComponents = URLComponents(string: url )!
        let queryItems = urlComponents.queryItems
        self.m_secrets.code = String( queryItems?.first(where: { $0.name == "code" })?.value ?? "" )
        self.m_secrets.session = String( queryItems?.first(where: { $0.name == "session" })?.value ?? "" )
        //AppLogger.shared.debug( "secrets with session: \(self.m_secrets.dump())" )
        if( KeychainManager.saveSecrets(secrets: &self.m_secrets) )
        {
            AppLogger.shared.debug( "extractCodeFromURL upated secrets with code and session. " )
            completion( .success( Void() ) )
        }
        else
        {
            AppLogger.shared.error( "Failed to save secrets." )
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
        AppLogger.shared.debug( "=== getAccessToken ===" )
        //AppLogger.shared.debug("🔍 getAccessToken - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        
        let url: URL = URL( string: "\(accessTokenWeb)" )!
        //AppLogger.shared.debug( "accessTokenUrl: \(url)" )
        var accessTokenRequest: URLRequest = URLRequest( url: url )
        // set a 10 second timeout on this request
        accessTokenRequest.timeoutInterval = self.requestTimeout
        accessTokenRequest.httpMethod = "POST"
        // headers
        let authStringUnencoded: String = String("\( self.m_secrets.appId ):\( self.m_secrets.appSecret )")
        let authStringEncoded: String = authStringUnencoded.data(using: .utf8)!.base64EncodedString()
        
        accessTokenRequest.setValue( "Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization" )
        accessTokenRequest.setValue( "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type" )
        // body
        accessTokenRequest.httpBody = String("grant_type=authorization_code&code=\( self.m_secrets.code )&redirect_uri=\( self.m_secrets.redirectUrl )").data(using: .utf8)!
        AppLogger.shared.debug( "Posting access token request:  \(accessTokenRequest)" )
        
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        var result: Result<Void, ErrorCodes> = .failure(.notAuthenticated)
        
        URLSession.shared.dataTask(with: accessTokenRequest)
        { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    //AppLogger.shared.debug("🔍 getAccessToken - Setting loading to FALSE")
                    self?.loadingDelegate?.setLoading(false)
                }
                semaphore.signal()
            }
            
            guard let data = data, ( (error == nil) && ( response != nil ) )
            else
            {
                AppLogger.shared.error( "Error: \( error?.localizedDescription ?? "Unknown error" )" )
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
                        AppLogger.shared.error( "Failed to save secrets with access and refresh tokens." )
                        result = .failure(ErrorCodes.failedToSaveSecrets)
                        return
                    }
                    result = .success( Void() )
                }
                else
                {
                    AppLogger.shared.error( "Failed to parse token response" )
                    result = .failure(ErrorCodes.notAuthenticated)
                }
            }
            else
            {
                AppLogger.shared.error( "Failed to fetch account numbers.   error: \(httpResponse.statusCode). \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))" )
                result = .failure(ErrorCodes.notAuthenticated)
            }
        }.resume()
        
        // Wait for completion with timeout to prevent deadlock
        let timeoutResult = semaphore.wait(timeout: .now() + 30.0) // 30 second timeout
        if timeoutResult == .timedOut {
            AppLogger.shared.error("getAccessToken timed out")
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
        AppLogger.shared.debug("=== refreshAccessToken: Refreshing access token...")

        // if the accessToken or refreshToken are empty, call getAccessToken instead
        if ( self.m_secrets.accessToken == "" ) || ( self.m_secrets.refreshToken == "" ) {
            AppLogger.shared.debug("Access token or refresh token is empty, getting initial access token...")
            self.getAccessToken{ result in
                switch result {
                case .success:
                    AppLogger.shared.debug(" refreshAccessToken - Successfully got access token")
                case .failure(let error):
                    AppLogger.shared.error(" refreshAccessToken - Failed to get access token: \(error.localizedDescription)")
                    // resetting code
                    self.m_secrets.code = ""
                }
            }
            // Return early since getAccessToken is now synchronous and handles the token acquisition
            return
        }
        
        //AppLogger.shared.debug("🔍 refreshAccessToken - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //AppLogger.shared.debug("🔍 refreshAccessToken - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }

        // Access Token Refresh Request
        guard let url = URL(string: "\(accessTokenWeb)") else {
            AppLogger.shared.error("Invalid URL for refreshing access token")
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
                AppLogger.shared.error("SchwabClient deallocated during token refresh")
                return
            }
            
            do {
                if let error = error {
                    AppLogger.shared.error("Network error during token refresh: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    AppLogger.shared.error("No data received during token refresh")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        // Parse the response
                        if let tokenDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            self.m_secrets.accessToken = (tokenDict["access_token"] as? String ?? "")
                            self.m_secrets.refreshToken = (tokenDict["refresh_token"] as? String ?? "")
                            
                            if KeychainManager.saveSecrets(secrets: &self.m_secrets) {
                                AppLogger.shared.debug("Successfully refreshed and saved access token.")
                            } else {
                                AppLogger.shared.error("Failed to save refreshed tokens.")
                            }
                        } else {
                            AppLogger.shared.error("Failed to parse token response.")
                        }
                    } else {
                        AppLogger.shared.error("Token refresh failed with status code: \(httpResponse.statusCode)")
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
            AppLogger.shared.error("Token refresh timed out")
        }
    }
    
    private func startRefreshAccessTokenThread() {
        guard !m_refreshAccessToken_running else {
            AppLogger.shared.debug("Refresh token thread already running")
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
        AppLogger.shared.debug(" === fetchAccountNumbers ===  \(accountNumbersWeb)")
        //AppLogger.shared.debug("🔍 fetchAccountNumbers - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //AppLogger.shared.debug("🔍 fetchAccountNumbers - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }
        
        guard let url = URL(string: accountNumbersWeb) else {
            AppLogger.shared.debug("Invalid URL")
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
                AppLogger.shared.error( "Failed to fetch account numbers.  Status: \(httpResponse.statusCode).  Error: \(httpResponse.description)" )
                return
            }
            // AppLogger.shared.debug( "response: \(response)" )
            //            AppLogger.shared.debug( "data:  \(String(data: data, encoding: .utf8) ?? "Missing data" )" )
            
            let decoder = JSONDecoder()
            let accountNumberHashes = try decoder.decode([AccountNumberHash].self, from: data)
            AppLogger.shared.debug("accountNumberHashes: \(accountNumberHashes.count)")
            
            if !accountNumberHashes.isEmpty
            {
                await MainActor.run
                {
                    self.m_secrets.acountNumberHash = accountNumberHashes
                    if KeychainManager.saveSecrets(secrets: &self.m_secrets)
                    {
                        AppLogger.shared.debug("Save \(self.m_secrets.acountNumberHash.count)  account numbers")
                    }
                    else
                    {
                        AppLogger.shared.error("Error saving account numbers")
                    }
                }
            } else {
                AppLogger.shared.debug("No account numbers returned")
            }
        } catch {
            AppLogger.shared.error("fetchAccountNumbers Error: \(error.localizedDescription)")
            AppLogger.shared.error("   detail:  \(error)")
        }
    }
    
    /**
     * fetchAccounts - get the account numbers and balances.
     */
    func fetchAccounts( retry : Bool = false ) async
    {
        AppLogger.shared.debug("=== fetchAccounts: selected: \(self.m_selectedAccountName) ===")
        //AppLogger.shared.debug("🔍 fetchAccounts - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //AppLogger.shared.debug("🔍 fetchAccounts - Setting loading to FALSE")
            loadingDelegate?.setLoading(false)
        }
        
        var accountUrl = accountWeb
        if self.m_selectedAccountName != "All"
        {
            AppLogger.shared.debug( "fetching for account: \(self.m_selectedAccountName)" )
            accountUrl += "/\(self.m_selectedAccountName)"
        }
        accountUrl += "?fields=positions"
        
        guard let url = URL(string: accountUrl) else {
            AppLogger.shared.debug("Invalid URL")
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
                AppLogger.shared.debug("Invalid response type")
                return
            }
            
            if httpResponse.statusCode != 200 {
                // decode data as a ServiceError
                AppLogger.shared.warning( "fetchAccounts: decoding json as ServiceError" )
                let serviceError = try JSONDecoder().decode(ServiceError.self, from: data)
                serviceError.printErrors(prefix: "fetchAccounts ")
                // if the status is 401 and retry is true, call fetchAccounts again after refreshing the access token
                if httpResponse.statusCode == 401 && retry {
                    AppLogger.shared.warning( "=== retrying fetchAccounts after refreshing access token ===" )
                    refreshAccessToken()
                    // Add a small delay to prevent rapid retries
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await fetchAccounts(retry: false)
                } else {
                    // Log the error for debugging
                    AppLogger.shared.error("fetchAccounts failed with status code: \(httpResponse.statusCode)")
                    if let errorData = String(data: data, encoding: .utf8) {
                        AppLogger.shared.error("Error response: \(errorData)")
                    }
                }
                return
            }
            
            let decoder = JSONDecoder()
            AppLogger.shared.debug( "=== decoding accounts ===" )
            m_accounts  = try decoder.decode([AccountContent].self, from: data)
            AppLogger.shared.debug( "  decoded \(m_accounts.count) accounts" )
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
                                        // AppLogger.shared.debug("  Added option contract: \(symbol) - \(instrument.description ?? "No description")")
                                    }
                                }
                        }
                    }
                }
            }
            
            // Now create SymbolContractSummary for each underlying symbol
            for (underlyingSymbol, positions) in positionsByUnderlying {
                let summary: SymbolContractSummary = SymbolContractSummary(contracts: positions)
                m_symbolsWithContracts[underlyingSymbol] = summary
                // AppLogger.shared.debug("Created summary for \(underlyingSymbol): \(summary.contractCount) contracts, min DTE: \(summary.minimumDTE ?? -1)")
            }
            
            AppLogger.shared.debug("Built contracts map with \(m_symbolsWithContracts.count) underlying symbols")
            return
        }
        catch
        {
            AppLogger.shared.error("fetchAccounts Error: \(error.localizedDescription)")
            AppLogger.shared.error("   detail:  \(error)")
            return
        }
    }
    
    
    /**
     * fettchPriceHistory  get the history of prices for all securities
     */
    func fetchPriceHistory( symbol : String )  -> CandleList?
    {
        AppLogger.shared.debug("=== fetchPriceHistory \(symbol) ===")

        // Check cache first without holding lock
        if( (symbol == m_lastFilteredPriceHistorySymbol) && (!(m_lastFilteredPriceHistory?.empty ?? true)) )
        {
            AppLogger.shared.debug( "  fetchPriceHistory - returning cached." )
            // Return a copy to prevent mutation issues (CandleList is a class/reference type)
            if let cached = m_lastFilteredPriceHistory {
                return CandleList(
                    candles: cached.candles,
                    empty: cached.empty,
                    previousClose: cached.previousClose,
                    previousCloseDate: cached.previousCloseDate,
                    previousCloseDateISO8601: cached.previousCloseDateISO8601,
                    symbol: cached.symbol
                )
            }
            return m_lastFilteredPriceHistory
        }

        //AppLogger.shared.debug("🔍 fetchPriceHistory - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //AppLogger.shared.debug("🔍 fetchPriceHistory - Setting loading to FALSE")
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
            AppLogger.shared.debug( "  fetchPriceHistory - returning cached (after lock)." )
            // Return a copy to prevent mutation issues (CandleList is a class/reference type)
            if let cached = m_lastFilteredPriceHistory {
                return CandleList(
                    candles: cached.candles,
                    empty: cached.empty,
                    previousClose: cached.previousClose,
                    previousCloseDate: cached.previousCloseDate,
                    previousCloseDateISO8601: cached.previousCloseDateISO8601,
                    symbol: cached.symbol
                )
            }
            return m_lastFilteredPriceHistory
        }
        
        m_lastFilteredPriceHistorySymbol = symbol
        m_lastFilteredPriceHistory?.candles.removeAll(keepingCapacity: true)

        let millisecondsSinceEpoch : Int64 = Int64(Date().timeIntervalSince1970 * 1000)
        // AppLogger.shared.debug date
        AppLogger.shared.debug( "      endDate = \(Date( timeIntervalSince1970: Double(millisecondsSinceEpoch)/1000.0 ) )")

        var priceHistoryUrl = "\(priceHistoryWeb)"
        priceHistoryUrl += "?symbol=\(symbol)"
        priceHistoryUrl += "&periodType=year"
        priceHistoryUrl += "&period=1"
        priceHistoryUrl += "&frequencyType=daily"
//        priceHistoryUrl += "&endDate=\(millisecondsSinceEpoch)"
        //AppLogger.shared.debug( "     priceHistoryUrl: \(priceHistoryUrl)" )
        
        guard let url = URL( string: priceHistoryUrl ) else {
            AppLogger.shared.debug("fetchPriceHistory. Invalid URL for \(symbol)")
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
            AppLogger.shared.error("fetchPriceHistory - Error for \(symbol): \(error.localizedDescription)")
            return nil
        }
        
        guard let data = responseData else {
            AppLogger.shared.debug("fetchPriceHistory. No data received for \(symbol)")
            return nil
        }
        
        if httpResponse?.statusCode != 200 {
            AppLogger.shared.error("fetchPriceHistory - Failed to fetch price history for \(symbol). code = \(httpResponse?.statusCode ?? -1)")
            // Try to decode error response for debugging
            if let errorString = String(data: data, encoding: .utf8) {
                AppLogger.shared.error("fetchPriceHistory - Error response for \(symbol): \(errorString)")
            }
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            m_lastFilteredPriceHistory = try decoder.decode(CandleList.self, from: data)
            
            // Validate the returned data
            guard let candleList = m_lastFilteredPriceHistory else {
                AppLogger.shared.error("fetchPriceHistory - Failed to decode CandleList for \(symbol)")
                return nil
            }
            
            // Check if we have valid candles
            let validCandles = candleList.candles.filter { candle in
                guard let high = candle.high, let low = candle.low, let close = candle.close else {
                    return false
                }
                return high > 0 && low > 0 && close > 0 && high >= low
            }
            
            AppLogger.shared.debug("fetchPriceHistory - Fetched \(candleList.candles.count) total candles, \(validCandles.count) valid candles for \(symbol)")
            
            if validCandles.count < 2 {
                AppLogger.shared.warning("fetchPriceHistory - Warning: Insufficient valid candles for ATR calculation for \(symbol)")
            }
            
            // Return a copy to prevent mutation issues when this is called again for a different symbol
            // (CandleList is a class/reference type, so we need to avoid shared mutable state)
            return CandleList(
                candles: candleList.candles,
                empty: candleList.empty,
                previousClose: candleList.previousClose,
                previousCloseDate: candleList.previousCloseDate,
                previousCloseDateISO8601: candleList.previousCloseDateISO8601,
                symbol: candleList.symbol
            )
        } catch {
            AppLogger.shared.error("fetchPriceHistory - Error decoding data for \(symbol): \(error.localizedDescription)")
            AppLogger.shared.error("   detail:  \(error)")
            return nil
        }
    }
    
    /**
     * fetchQuote - get quote data including fundamental information for a symbol
     */
    func fetchQuote(symbol: String) -> QuoteData? {
        AppLogger.shared.debug("=== fetchQuote \(symbol) ===")
        
        let quoteUrl = "\(marketdataAPI)/\(symbol)/quotes"
        
        guard let url = URL(string: quoteUrl) else {
            AppLogger.shared.debug("fetchQuote. Invalid URL")
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
            AppLogger.shared.error("fetchQuote - Error: \(error.localizedDescription)")
            return nil
        }
        
        guard let data = responseData else {
            AppLogger.shared.debug("fetchQuote. No data received")
            return nil
        }
        
        if httpResponse?.statusCode != 200 {
            AppLogger.shared.error("fetchQuote - Failed to fetch quote. code = \(httpResponse?.statusCode ?? -1)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let quoteResponse = try decoder.decode(QuoteResponse.self, from: data)
            
            // Get the quote data for the requested symbol
            guard let quoteData = quoteResponse.quotes[symbol] else {
                AppLogger.shared.debug("fetchQuote - No quote data found for symbol \(symbol)")
                return nil
            }
            
            // AppLogger.shared.debug("fetchQuote - Successfully fetched quote for \(symbol)")
            //
            // // Log detailed fundamental information
            // if let fundamental = quoteData.fundamental {
            //     AppLogger.shared.debug("fetchQuote - Fundamental data for \(symbol):")
            //     AppLogger.shared.debug("  divYield: \(fundamental.divYield ?? 0)")
            //     AppLogger.shared.debug("  divAmount: \(fundamental.divAmount ?? 0)")
            //     AppLogger.shared.debug("  divFreq: \(fundamental.divFreq ?? 0)")
            //     AppLogger.shared.debug("  eps: \(fundamental.eps ?? 0)")
            //     AppLogger.shared.debug("  peRatio: \(fundamental.peRatio ?? 0)")
            //
            //     if let divYield = fundamental.divYield {
            //         AppLogger.shared.debug("fetchQuote - Raw dividend yield for \(symbol): \(divYield)%")
            //         AppLogger.shared.debug("fetchQuote - Dividend yield is already a percentage value")
            //     }
            // } else {
            //     AppLogger.shared.debug("fetchQuote - No fundamental data available for \(symbol)")
            // }
            
            return quoteData
        } catch {
            AppLogger.shared.error("fetchQuote - Error: \(error.localizedDescription)")
            AppLogger.shared.error("   detail: \(error)")
            return nil
        }
    }
    
    /**
     * compute ATR for given symbol
     */
    public func computeATR( symbol : String )  -> Double
    {
        AppLogger.shared.debug("=== computeATR \(symbol) ===")

        // Check cache first without holding lock
        if( symbol == m_lastFilteredATRSymbol )
        {
            AppLogger.shared.debug( "  computeATR - returning cached." )
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
            AppLogger.shared.debug( "  computeATR - returning cached (after lock)." )
            return m_lastFilteredATR
        }

        guard let priceHistory : CandleList =  self.fetchPriceHistory( symbol: symbol ) else {
            AppLogger.shared.error("computeATR Failed to fetch price history for \(symbol).")
            // Don't set the symbol if we failed to get data - this allows retry on next call
            return 0.0
        }

        // Get a local copy of the candles array to prevent race conditions
        let candles = priceHistory.candles
        let candlesCount = candles.count
        
        // Need at least 2 candles to compute ATR
        guard candlesCount > 1 else {
            AppLogger.shared.debug("computeATR: Need at least 2 candles, got \(candlesCount) for \(symbol)")
            // Don't set the symbol if we don't have enough data - this allows retry on next call
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
            AppLogger.shared.debug("computeATR: Need at least 2 valid candles, got \(validCandles.count) for \(symbol)")
            // Don't set the symbol if we don't have valid data - this allows retry on next call
            return 0.0
        }
        
        var close : Double  = priceHistory.previousClose ?? 0.0
        var localATR : Double  = 0.0
        
        /*
         * Compute the ATR as the average of the True Range.
         * The True Range is the maximum of absolute values of the High - Low, High - previous Close, and Low - previous Close
         */
        let length : Int  =  min( validCandles.count, 21 )
        let startIndex : Int = validCandles.count - length
        
        // Additional safety check
        guard startIndex >= 0 && startIndex < validCandles.count else {
            AppLogger.shared.debug("computeATR: Invalid startIndex \(startIndex) for validCandlesCount \(validCandles.count) for \(symbol)")
            // Don't set the symbol if we have invalid data - this allows retry on next call
            return 0.0
        }
        
        for indx in 0..<length
        {
            let position = startIndex + indx
            
            // Bounds check for current position - recheck validCandles.count in case array was modified
            guard position >= 0 && position < validCandles.count else {
                AppLogger.shared.debug("computeATR: Position \(position) out of bounds for validCandlesCount \(validCandles.count) for \(symbol)")
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
                    AppLogger.shared.debug("computeATR: Previous position \(prevPosition) out of bounds for validCandlesCount \(validCandles.count) for \(symbol)")
                    continue
                }
                prevClose = validCandles[prevPosition].close ?? 0.0
            }
            
            let high : Double  = candle.high ?? 0.0
            let low  : Double  = candle.low ?? 0.0
            let tr : Double = max( abs( high - low ), abs( high - prevClose ), abs( low - prevClose ) )
            close = candle.close ?? 0.0
            localATR = ( (localATR * Double(indx)) + tr ) / Double(indx+1)
        }
        
        // Validate final values before returning
        guard close > 0 && localATR > 0 else {
            AppLogger.shared.debug("computeATR: Invalid final values - close: \(close), ATR: \(localATR) for \(symbol)")
            // Don't set the symbol if we have invalid final values - this allows retry on next call
            return 0.0
        }
        
        // Set the symbol and ATR only if we successfully calculated a valid value
        m_lastFilteredATRSymbol = symbol
        m_lastFilteredATR = (localATR * 1.08 / close * 100.0)
        
        AppLogger.shared.debug("computeATR: Successfully calculated ATR: \(m_lastFilteredATR)% for \(symbol)")
        
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
        AppLogger.shared.debug("computeATR: Cleared ATR cache")
    }
    
    /**
     * clearPriceHistoryCache - clear the price history cache to force fresh data fetch
     */
    public func clearPriceHistoryCache() {
        m_lastFilteredPriceHistoryLock.lock()
        defer { m_lastFilteredPriceHistoryLock.unlock() }
        
        m_lastFilteredPriceHistorySymbol = ""
        m_lastFilteredPriceHistory = nil
        AppLogger.shared.debug("fetchPriceHistory: Cleared price history cache")
    }
    
    /**
     * clearAllCaches - clear all caches for debugging purposes
     */
    public func clearAllCaches() {
        clearATRCache()
        clearPriceHistoryCache()
        AppLogger.shared.debug("SchwabClient: Cleared all caches")
    }
    
    /**
     * testATRCalculation - test ATR calculation with sample data
     */
    public func testATRCalculation() {
        AppLogger.shared.debug("=== testATRCalculation ===")
        
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
        AppLogger.shared.debug("Test ATR value: \(atrValue)%")
        
        // Clear test data
        clearAllCaches()
    }
    
    /**
     * fetchTransactionHistorySync - synchronous fetch of transaction history
     * Note: This method should be avoided in favor of async versions
     */
    public func fetchTransactionHistorySync() {
        AppLogger.shared.debug("=== fetchTransactionHistorySync  ===")
        
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
            AppLogger.shared.debug(" --- fetchTransactionHistorySync -  maxQuarterDelta reached")
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
            AppLogger.shared.debug("fetchTransactionHistorySync timed out")
            task.cancel()
        }
        
        AppLogger.shared.debug(" --- fetchTransactionHistorySync done ---")
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
        AppLogger.shared.debug("=== fetchTransactionHistory -  quarterDelta: \(quarterDeltaForLogging) ===")
        //AppLogger.shared.debug("🔍 fetchTransactionHistory - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //AppLogger.shared.debug("🔍 fetchTransactionHistory - Setting loading to FALSE")
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
            AppLogger.shared.debug(" --- fetchTransactionHistory -  maxQuarterDelta reached")
            return
        }
        
        let newQuarterDelta = currentQuarterDelta

        let initialSize: Int = m_transactionList.count
        let endDate = getDateNQuartersAgoStrForEndDate(quarterDelta: newQuarterDelta - 1)
        let startDate = getDateNQuartersAgoStr(quarterDelta: newQuarterDelta)

        AppLogger.shared.debug("  -- processing quarter delta: \(newQuarterDelta)")

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
                            AppLogger.shared.debug("fetchTransactionHistory. Invalid URL")
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
                                AppLogger.shared.debug("Invalid response type")
                                return nil
                            }
                            
                            if httpResponse.statusCode != 200 {
                                AppLogger.shared.debug("response code: \(httpResponse.statusCode)  data: \(String(data: data, encoding: .utf8) ?? "N/A")")
                                if let serviceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                                    serviceError.printErrors(prefix: "  fetchTransactionHistory ")
                                }
                                return nil
                            }

                            let decoder = JSONDecoder()
                            let transactions = try decoder.decode([Transaction].self, from: data)

                            return transactions
                        } catch {
                            AppLogger.shared.error("fetchTransactionHistory Error: \(error.localizedDescription)")
                            AppLogger.shared.error("   detail:  \(error)")
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

        AppLogger.shared.debug("Fetched \(m_transactionList.count - initialSize) transactions")
        
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
//        AppLogger.shared.debug( "    ==== getTransactionsFor \(symbol ?? "nil")  quarters: \(quarterDeltaForLogging) ====" )
//        AppLogger.shared.debug("    ==== getTransactionsFor Current transaction list size: \(m_transactionList.count)")
        
        if( nil == symbol ) {
            AppLogger.shared.debug( "getTransactionsFor \(symbol ?? "nil")  -  No symbol provided" )
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
            // AppLogger.shared.debug( "    ==== getTransactionsFor   !!!!! cleared filtered transactions" )
            // get the filtered transactions for the security and fetch more until we have some or the retries are exhausted.
            m_lastFilteredTransactions =  m_transactionList.filter { transaction in
                // Check if the symbol is nil or if any transferItem in the transaction matches the symbol
                let matches = transaction.transferItems.contains { $0.instrument?.symbol == symbol }
                return matches // return from closure, not from the method
            }
            // AppLogger.shared.debug("    ==== getTransactionsFor Found \(m_lastFilteredTransactions.count) matching transactions.  Quarter: \(quarterDeltaForLogging) of \(self.maxQuarterDelta)")

            // Fetch more records if needed, but with proper termination conditions
            var fetchAttempts = 0
            let maxFetchAttempts = 3  // Limit the number of fetch attempts
            
            while( (self.maxQuarterDelta > quarterDeltaForLogging) && 
                   (self.m_lastFilteredTransactions.count == 0) && 
                   (fetchAttempts < maxFetchAttempts) ) {
                AppLogger.shared.debug( "     -- getTransactionsFor \(symbol ?? "nil")  - still no records, fetching again (attempt \(fetchAttempts + 1)/\(maxFetchAttempts))" )
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
                    AppLogger.shared.debug("     -- getTransactionsFor \(symbol ?? "nil")  - fetch attempt \(fetchAttempts) timed out after \(m_fetchTimeout) seconds for  \(symbol ?? "nil")")
                }
                else {
                    // Re-filter after potential new data
                    m_lastFilteredTransactions =  m_transactionList.filter { transaction in
                        // Check if the symbol is nil or if any transferItem in the transaction matches the symbol
                        let matches = symbol == nil || transaction.transferItems.contains { $0.instrument?.symbol == symbol }
                        return matches
                    }
                    AppLogger.shared.debug("  -- getTransactionsFor \(symbol ?? "nil")  - Found \(m_lastFilteredTransactions.count) matching transactions after fetch")
                }
            }
            
            if fetchAttempts >= maxFetchAttempts && m_lastFilteredTransactions.count == 0 {
                AppLogger.shared.debug("Reached maximum fetch attempts without finding transactions for symbol: \(symbol ?? "nil")")
            }
            
            // Calculate shares available for trading
            if let symbol = symbol {
                // We'll compute shares available for trading separately to avoid circular dependency
                // This will be done after tax lots are computed
                AppLogger.shared.debug("=== Shares Available for Trading Calculation ===")
                AppLogger.shared.debug("Symbol: \(symbol)")
                AppLogger.shared.debug("Shares available for trading will be computed after tax lots")
            }
        }
        else {
            AppLogger.shared.debug( "  -- getTransactionsFor  same symbol \(symbol ?? "nil") and count as last time - returning cached" )
        }
        // return the transactionlist where the symbol matches what is provided
        AppLogger.shared.debug( " --- getTransactionsFor \(symbol ?? "nil")  returning \(m_lastFilteredTransactions.count) transactions -- " )
        return m_lastFilteredTransactions
    } // getTransactionsFor
    

    


    private func setLatestTradeDates()
    {
        AppLogger.shared.debug( "--- setLatestTradeDates ---" )
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
                        // AppLogger.shared.debug( "=== dateStr: \(dateStr), dateDte: \(dateDte) ==" )
                    }
                    catch {
                        AppLogger.shared.error( "Error parsing date: \(error)" )
                        continue
                    }
                    // if the symbol is not in the dictionary, add it with the date.  otherwise compare the date and update only if newer
                    if m_latestDateForSymbol[symbol] == nil || dateDte > m_latestDateForSymbol[symbol]! {
                        m_latestDateForSymbol[symbol] = dateDte
                        // AppLogger.shared.debug( "Added or updated \(symbol) at \(dateDte) - latest date \(latestDateForSymbol[symbol] ?? Date())" )
                    }
                }
            }
        }
        AppLogger.shared.debug( " ! setLatestTradeDates - set dates for \(m_latestDateForSymbol.count) symbols !" )
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
        AppLogger.shared.debug("=== computeSharesAvailableForTrading for \(symbol) ===")
        AppLogger.shared.debug("  Using provided tax lots for accurate share calculation")
        AppLogger.shared.debug("  Found \(taxLots.count) tax lots for \(symbol)")
        
        // Calculate shares held for over 30 days and under 30 days from tax lots
        var sharesOver30Days: Double = 0.0
        var sharesUnder30Days: Double = 0.0
        let currentDate = Date()
        
        AppLogger.shared.debug("  === Processing Tax Lots ===")
        for (index, taxLot) in taxLots.enumerated() {
            // Parse tax lot date - format is "2024-12-03 14:34:41"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.timeZone = TimeZone.current
            
            guard let date = dateFormatter.date(from: taxLot.openDate)
            else {
                AppLogger.shared.debug("    Tax lot \(index): Skipping invalid date: \(taxLot.openDate)")
                continue
            }
            
            // Calculate days since tax lot was created
            let daysSinceTaxLot = Calendar.current.dateComponents([.day], from: date, to: currentDate).day ?? 0
            
            if daysSinceTaxLot > 30 {
                sharesOver30Days += taxLot.quantity
                AppLogger.shared.debug("    Tax lot \(index): \(taxLot.quantity) shares from \(taxLot.openDate) held for \(daysSinceTaxLot) days (ELIGIBLE)")
            } else {
                sharesUnder30Days += taxLot.quantity
                AppLogger.shared.debug("    Tax lot \(index): \(taxLot.quantity) shares from \(taxLot.openDate) held for \(daysSinceTaxLot) days (NOT ELIGIBLE)")
            }
        }
        
        AppLogger.shared.debug("  Total shares held for over 30 days: \(sharesOver30Days)")
        AppLogger.shared.debug("  Total shares held for under or equal to 30 days: \(sharesUnder30Days)")
        
        // Get total shares under contract and offset them by <30 day shares first
        let totalContractShares = getContractCountForSymbol(symbol) * 100.0
        let contractsAbsorbedByUnder30 = min(sharesUnder30Days, totalContractShares)
        let sharesUnderContractAffectingOver30 = totalContractShares - contractsAbsorbedByUnder30
        AppLogger.shared.debug("  Contract shares (raw): \(totalContractShares) (contracts: \(getContractCountForSymbol(symbol)))")
        AppLogger.shared.debug("  Contract shares absorbed by <30d holdings: \(contractsAbsorbedByUnder30)")
        AppLogger.shared.debug("  Contract shares affecting >30d holdings: \(sharesUnderContractAffectingOver30)")
        
        // Calculate available shares: >30 day shares reduced only by contracts not covered by <30 day shares
        let availableShares = sharesOver30Days - sharesUnderContractAffectingOver30
        let finalAvailableShares = max(0.0, availableShares)
        
        AppLogger.shared.debug("  === Final Calculation ===")
        AppLogger.shared.debug("    Shares over 30 days: \(sharesOver30Days)")
        AppLogger.shared.debug("    Shares under contract affecting >30d: \(sharesUnderContractAffectingOver30)")
        AppLogger.shared.debug("    Available shares: \(finalAvailableShares)")
        AppLogger.shared.debug("    Total shares owned: \(taxLots.reduce(0.0) { $0 + $1.quantity })")
        
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
        AppLogger.shared.info("fetchOrderHistory === fetchOrderHistory  ===")
        // Clear existing orders
        m_orderList.removeAll(keepingCapacity: true)
        // Get date range for the 6 months
        let today: Date = Date()
        let sixMonthsAgo: Date = Calendar.current.date(byAdding: .day, value: -31, to: today) ?? today
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let todayStr: String = dateFormatter.string(from: today)
        let dateSixMonthsAgoStr: String = dateFormatter.string(from: sixMonthsAgo)
        AppLogger.shared.info("fetchOrderHistory 📅 Date range: \(dateSixMonthsAgoStr) to \(todayStr)")

        // Fetch orders for each active status
        await withTaskGroup(of: [Order]?.self) { group in
            for status in OrderStatus.allCases {
                // ignore order status values that are not active orders
                if status == .rejected || status == .canceled || status == .replaced || status == .expired || status == .filled {
                    continue
                }
                AppLogger.shared.info("fetchOrderHistory 🔍 Fetching orders for status: \(status.rawValue)")
                group.addTask {
                    var orderHistoryUrl: String = "\(ordersWeb)"
                    orderHistoryUrl += "?fromEnteredTime=\(dateSixMonthsAgoStr)"
                    orderHistoryUrl += "&toEnteredTime=\(todayStr)"
                    orderHistoryUrl += "&status=\(status.rawValue)"

                    guard let url: URL = URL( string: orderHistoryUrl ) else {
                        AppLogger.shared.error("fetchOrderHistory ❌ fetchOrderHistory. Invalid URL")
                        return nil
                    }

                    var request: URLRequest = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "accept")
                    // set a 10 second timeout on this request
                    request.timeoutInterval = self.requestTimeout

                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
                            AppLogger.shared.error("fetchOrderHistory ❌ Invalid response type")
                            return nil
                        }
                        if httpResponse.statusCode != 200 {
                            if httpResponse.statusCode == 401 && retry {
                                AppLogger.shared.warning("fetchOrderHistory === retrying fetchOrderHistory after refreshing access token ===")
                                self.refreshAccessToken()
                                // Note: We can't recursively call async function from within task group
                                // The retry will be handled by the caller
                                return nil
                            }

                            AppLogger.shared.error("fetchOrderHistory ❌ HTTP \(httpResponse.statusCode) for status \(status.rawValue)")
                            if let serviceError: ServiceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                                // print data as string
                                AppLogger.shared.error("fetchOrderHistory ---- data: \(String(data: data, encoding: .utf8) ?? "N/A")")
                                serviceError.printErrors(prefix: "fetchOrderHistory ")
                            }
                            return nil
                        }

                        // Try to decode, but if it fails, print the raw JSON
                        do {
                            let decoder: JSONDecoder = JSONDecoder()
                            let orders: [Order] = try decoder.decode([Order].self, from: data)
                            AppLogger.shared.info("fetchOrderHistory ✅ Received \(orders.count) orders for status \(status.rawValue)")
                            return orders
                        } catch {
                            AppLogger.shared.error("fetchOrderHistory ❌ Decoding error for status \(status.rawValue): \(error.localizedDescription)")
                            AppLogger.shared.error("fetchOrderHistory   detail:  \(error)")
                            AppLogger.shared.error("fetchOrderHistory ❌ Raw JSON data received:")
                            AppLogger.shared.error("fetchOrderHistory \(String(data: data, encoding: .utf8) ?? "Could not decode as UTF-8")")
                            return nil
                        }
                    } catch {
                        AppLogger.shared.error("fetchOrderHistory ❌ Network error for status \(status.rawValue): \(error.localizedDescription)")
                        return nil
                    }
                } // addTask
            } // for all orderStatus values

            // Collect results from all tasks
            var totalOrdersReceived: Int = 0
            for await orders: [Order]? in group {
                if let orders: [Order] = orders {
                    totalOrdersReceived += orders.count
                    AppLogger.shared.info("fetchOrderHistory 📦 Adding \(orders.count) orders from query (total so far: \(totalOrdersReceived))")
                    m_orderList.append(contentsOf: orders)
                }
            } // append orders
        } // await

        AppLogger.shared.info("fetchOrderHistory 📊 Fetched \(m_orderList.count) orders for all accounts")

        // Deduplicate orders by orderId
        var seenOrderIds: Set<Int64> = []
        var uniqueOrders: [Order] = []
        
        for order in m_orderList {
            if let orderId = order.orderId {
                if !seenOrderIds.contains(orderId) {
                    seenOrderIds.insert(orderId)
                    uniqueOrders.append(order)
                }
            }
        }
        
        m_orderList = uniqueOrders
        
        AppLogger.shared.info("fetchOrderHistory 📊 After deduplication: \(m_orderList.count) unique orders")
        updateSymbolsWithOrders()
    }
    
    private func updateSymbolsWithOrders() {
        AppLogger.shared.info("🔍 === updateSymbolsWithOrders ===")
        // Clear existing symbols with orders
        m_symbolsWithOrders.removeAll(keepingCapacity: true)
        
        AppLogger.shared.info("🔍 Processing \(m_orderList.count) orders to categorize by symbol...")
        
        // update the m_symbolsWithOrders dictionary with each symbol in the orderList with orders that are in awaiting states
        for (_, order) in m_orderList.enumerated() {            
            if let activeStatus: ActiveOrderStatus = ActiveOrderStatus(from: order.status ?? .unknown, order: order) {
                if( ( order.orderStrategyType == .SINGLE )
                    || ( order.orderStrategyType == .TRIGGER ) ) {
                    for (legIndex, leg) in (order.orderLegCollection ?? []).enumerated() {
                        if let symbol = leg.instrument?.symbol {
                            if m_symbolsWithOrders[symbol] == nil {
                                m_symbolsWithOrders[symbol] = []
                            }
                            if !m_symbolsWithOrders[symbol]!.contains(activeStatus) {
                                m_symbolsWithOrders[symbol]!.append(activeStatus)
                            }
                        } else {
                            AppLogger.shared.warning("    ⚠️ Leg \(legIndex + 1): No symbol found")
                        }
                    }
                }
                if ( order.orderStrategyType == .OCO ) {
                    for (_, childOrder) in (order.childOrderStrategies ?? []).enumerated() {
                        if let childActiveStatus = ActiveOrderStatus(from: childOrder.status ?? .unknown, order: childOrder) {
                            for (legIndex, leg) in (childOrder.orderLegCollection ?? []).enumerated() {
                                if let symbol = leg.instrument?.symbol {
                                    if m_symbolsWithOrders[symbol] == nil {
                                        m_symbolsWithOrders[symbol] = []
                                    }
                                    if !m_symbolsWithOrders[symbol]!.contains(childActiveStatus) {
                                        m_symbolsWithOrders[symbol]!.append(childActiveStatus)
                                    }
                                } else {
                                    AppLogger.shared.warning("        ⚠️ Child Leg \(legIndex + 1): No symbol found")
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
                AppLogger.shared.warning("  ❌ Order NOT in awaiting states: \(order.status ?? OrderStatus.unknown)")
            } else {
                AppLogger.shared.debug("  ❌ Order is completed/cancelled: \(order.status?.rawValue ?? "nil")")
            }
        }
        AppLogger.shared.info("🔍 === END updateSymbolsWithOrders ===")
    }

    // cancel select order 
    public func cancelOrders( orderIds: [Int64] ) async -> (success: Bool, errorMessage: String?) {
        AppLogger.shared.info("=== cancelOrders ===")
        AppLogger.shared.debug("🎯 Cancelling \(orderIds.count) orders: \(orderIds)")
        AppLogger.shared.debug("📋 Order IDs to cancel: \(orderIds.map { String($0) }.joined(separator: ", "))")
        
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
                    AppLogger.shared.debug("🔍 DELETE REQUEST VERIFICATION:")
                    AppLogger.shared.debug("  📍 URL: \(cancelOrderUrl)")
                    AppLogger.shared.debug("  🆔 Order ID: \(orderId)")
                    AppLogger.shared.debug("  🔑 Account Hash: \(hashValue)")
                    AppLogger.shared.debug("  🏷️  HTTP Method: \(request.httpMethod ?? "nil")")
                    AppLogger.shared.debug("  📋 Headers:")
                    AppLogger.shared.debug("    Authorization: Bearer \(String(self.m_secrets.accessToken.prefix(20)))...")
                    AppLogger.shared.debug("    Accept: \(request.value(forHTTPHeaderField: "Accept") ?? "nil")")
                    AppLogger.shared.debug("  ⏱️  Timeout: \(request.timeoutInterval) seconds")
                    AppLogger.shared.debug("  📊 Request would delete order \(orderId) from account \(orderAccountNumber) (hash: \(hashValue))")
                    AppLogger.shared.debug("  ✅ Request verification complete - ready to execute DELETE")
                    
                    
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        
                        guard let httpResponse = response as? HTTPURLResponse else {
                            return (orderId: orderId, success: false, errorMessage: "Invalid response type")
                        }
                        
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                            AppLogger.shared.warning("✅ Successfully cancelled order \(orderId)")
                            return (orderId: orderId, success: true, errorMessage: nil)
                        } else {
                            // Try to decode error response
                            let errorMessage: String
                            if let responseString = String(data: data, encoding: .utf8) {
                                errorMessage = "HTTP \(httpResponse.statusCode): \(responseString)"
                            } else {
                                errorMessage = "HTTP \(httpResponse.statusCode): Unknown error"
                            }
                            
                            AppLogger.shared.error("❌ Failed to cancel order \(orderId): \(errorMessage)")
                            return (orderId: orderId, success: false, errorMessage: errorMessage)
                        }
                    } catch {
                        let errorMessage = "Network error: \(error.localizedDescription)"
                        AppLogger.shared.error("❌ Error cancelling order \(orderId): \(errorMessage)")
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
            
            AppLogger.shared.warning("✅ SUCCESS: Cancelled all \(orderIds.count) orders successfully")
            AppLogger.shared.warning("📊 Final Results:")
            AppLogger.shared.warning("  🎯 Total orders requested: \(orderIds.count)")
            AppLogger.shared.warning("  ✅ Successfully cancelled: \(orderIds.count)")
            AppLogger.shared.error("  ❌ Failed to cancel: 0")
            return (success: true, errorMessage: nil)
        } else {
            // Some orders failed to cancel
            let errorMessage = "Failed to cancel \(failedOrders.count) orders:\n" + errorMessages.joined(separator: "\n")
            AppLogger.shared.warning("❌ FAILURE: Cancellation failed")
            AppLogger.shared.warning("📊 Final Results:")
            AppLogger.shared.warning("  🎯 Total orders requested: \(orderIds.count)")
            AppLogger.shared.warning("  ✅ Successfully cancelled: \(orderIds.count - failedOrders.count)")
            AppLogger.shared.error("  ❌ Failed to cancel: \(failedOrders.count)")
            AppLogger.shared.warning("  📝 Error details: \(errorMessage)")
            return (success: false, errorMessage: errorMessage)
        }
    }

    // place an order
    public func placeOrder( order: Order ) async -> (success: Bool, errorMessage: String?) {
        AppLogger.shared.debug("📤 [PLACE-ORDER] === placeOrder  ===")
        
        // Get the account hash for the order's account number
        guard let orderAccountNumber = order.accountNumber else {
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ Order does not have account number")
            return (false, "Order does not have account number")
        }
        
        guard let accountNumberHash = m_secrets.acountNumberHash.first(where: { 
            $0.accountNumber == String(orderAccountNumber) 
        }) else {
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ Account hash not found for account number \(orderAccountNumber)")
            return (false, "Account hash not found for account number \(orderAccountNumber)")
        }
        
        guard let hashValue = accountNumberHash.hashValue else {
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ Invalid account hash value")
            return (false, "Invalid account hash value")
        }
        
        let placeOrderUrl = "\(accountWeb)/\(hashValue)/orders"
        
        guard let url = URL(string: placeOrderUrl) else {
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ Invalid URL for order placement")
            return (false, "Invalid URL for order placement")
        }
        
        // Create JSON encoder with proper date formatting
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(DateFormatter.schwabDateFormatter)
        
        do {
            let jsonData = try encoder.encode(order)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            AppLogger.shared.debug("📤 [PLACE-ORDER] 📤 POST REQUEST VERIFICATION:")
            AppLogger.shared.debug("📤 [PLACE-ORDER]   📋 JSON Body:")
            
            // Sanitize the JSON before logging to hide sensitive account information
            let sanitizedJson = JSONSanitizer.sanitizeAccountNumbers(in: jsonString)
            AppLogger.shared.debug("📤 [PLACE-ORDER] \(sanitizedJson)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.httpBody = jsonData
            request.timeoutInterval = requestTimeout
            
            // Execute the request
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if let responseString = String(data: data, encoding: .utf8) {
                        AppLogger.shared.debug("📤 [PLACE-ORDER]   📄 Response Body: \(responseString)")
                    }
                    
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        AppLogger.shared.debug("📤 [PLACE-ORDER] ✅ Order placed successfully")
                        // Refresh orders list
                        await fetchOrderHistory()
                        return (true, nil)
                    } else {
                        AppLogger.shared.debug("📤 [PLACE-ORDER] 📥 RESPONSE:")
                        AppLogger.shared.debug("📤 [PLACE-ORDER]   📊 Status Code: \(httpResponse.statusCode)")
                        AppLogger.shared.debug("📤 [PLACE-ORDER]   📋 Headers: \(httpResponse.allHeaderFields)")
                        AppLogger.shared.debug(" [PLACE-ORDER]  \(httpResponse.description)")
                        AppLogger.shared.debug(" [PLACE-ORDER]  \(httpResponse.debugDescription)")

                        // Try to extract error message from response body
                        var errorMessage = "Order placement failed with status code: \(httpResponse.statusCode)"
                        
                        if let responseString = String(data: data, encoding: .utf8) {
                            // Try to parse JSON response for error message
                            if let jsonData = responseString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let apiMessage = json["message"] as? String {
                                errorMessage = "API Error: \(apiMessage)"
                            } else {
                                // If not JSON, use the raw response
                                errorMessage = "API Error: \(responseString)"
                            }
                        }
                        
                        AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ \(errorMessage)")
                        return (false, errorMessage)
                    }
                } else {
                    let errorMessage = "Invalid response type"
                    AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ \(errorMessage)")
                    return (false, errorMessage)
                }
            } catch {
                let errorMessage = "Error placing order: \(error.localizedDescription)"
                AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ \(errorMessage)")
                return (false, errorMessage)
            }
            
        } catch {
            let errorMessage = "Error encoding order to JSON: \(error.localizedDescription)"
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ \(errorMessage)")
            return (false, errorMessage)
        }
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
    public func getPrimaryOrderStatus(for symbol: String) -> ActiveOrderStatus? {
        guard let statuses = m_symbolsWithOrders[symbol], !statuses.isEmpty else {
            // AppLogger.shared.debug("🔍 No active orders found for symbol: \(symbol)")
            return nil
        }
        // Sort by priority and return the highest priority status
        let sortedStatuses = statuses.sorted { $0.priority < $1.priority }
        let primaryStatus = sortedStatuses.first
        return primaryStatus
    }
    
    /**
     * getOrderList - return all orders
     */
    public func getOrderList() -> [Order]
    {
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
        AppLogger.shared.debug("=== handleMergedRenamedSecurities - processing \(taxLots.count) tax lots ===")
        
        guard !taxLots.isEmpty else {
            AppLogger.shared.debug("  --- No tax lots to process")
            return taxLots
        }
        
        // Sort by date (oldest first) to find the earliest transaction
        let sortedLots = taxLots.sorted { $0.openDate < $1.openDate }
        let earliestLot = sortedLots.first!
        
        // Check if the earliest transaction has cost = 0 (indicating a merge/rename)
        if earliestLot.costPerShare == 0.0 && earliestLot.quantity > 0 {
            AppLogger.shared.debug("  --- Found potential merged/renamed security: \(earliestLot.openDate), shares: \(earliestLot.quantity), cost: \(earliestLot.costPerShare)")
            
            // Get current share count from position
            let currentShareCount = getShareCount(symbol: symbol)
            AppLogger.shared.debug("  --- Current share count: \(currentShareCount)")
            
            // Check if the earliest transaction matches the current share count
            if abs(earliestLot.quantity - currentShareCount) < 0.01 {
                AppLogger.shared.debug("  --- Earliest transaction matches current share count - computing cost-per-share")
                
                // Calculate sum of later tax lots costs
                let laterTaxLots = sortedLots.dropFirst()
                let sumOfLaterTaxLotsCosts = laterTaxLots.reduce(0.0) { $0 + $1.costBasis }
                AppLogger.shared.debug("  --- Sum of later tax lots costs: $\(sumOfLaterTaxLotsCosts)")
                
                // Get average price from position
                let averagePrice = getAveragePrice(symbol: symbol)
                AppLogger.shared.debug("  --- Average price from position: $\(averagePrice)")
                
                // Compute the cost-per-share using the formula from README
                let receivedCostPerShare = ((averagePrice * earliestLot.quantity) - sumOfLaterTaxLotsCosts) / currentShareCount
                AppLogger.shared.debug("  --- Computed cost-per-share: $\(receivedCostPerShare)")
                
                // Update the earliest lot with the computed cost
                var updatedLots = taxLots
                if let index = updatedLots.firstIndex(where: { $0.id == earliestLot.id }) {
                    updatedLots[index].costPerShare = receivedCostPerShare
                    updatedLots[index].costBasis = receivedCostPerShare * earliestLot.quantity
                    // Gain/loss will be recalculated at the end
                    updatedLots[index].gainLossDollar = 0.0
                    updatedLots[index].gainLossPct = 0.0
                    
                    AppLogger.shared.debug("  --- Updated earliest lot with computed cost: $\(receivedCostPerShare)")
                }
                
                return updatedLots
            } else {
                AppLogger.shared.debug("  --- Earliest transaction does not match current share count - skipping")
            }
        } else {
            AppLogger.shared.debug("  --- No merged/renamed security detected")
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
        AppLogger.shared.debug("=== adjustForStockSplits - processing \(taxLots.count) tax lots ===")
        
        // Sort by date (oldest first)
        let sortedLots = taxLots.sorted { $0.openDate < $1.openDate }
        var adjustedLots: [SalesCalcPositionsRecord] = []
        var i = 0
        
        while i < sortedLots.count {
            let currentLot = sortedLots[i]
            
            // Check if this is a zero-cost transaction (potential split)
            if currentLot.costPerShare == 0.0 && currentLot.quantity > 0 {
                AppLogger.shared.debug("  --- Found potential split transaction: \(currentLot.openDate), shares: \(currentLot.quantity), cost: \(currentLot.costPerShare)")
                
                // Calculate total shares before this split
                let sharesBeforeSplit = adjustedLots.reduce(0.0) { $0 + $1.quantity }
                let sharesFromSplit = currentLot.quantity
                let totalSharesAfterSplit = sharesBeforeSplit + sharesFromSplit
                
                if sharesBeforeSplit > 0 {
                    // Calculate split ratio
                    let splitRatio = totalSharesAfterSplit / sharesBeforeSplit
                    AppLogger.shared.debug("  --- Split calculation:")
                    AppLogger.shared.debug("    Shares before split: \(sharesBeforeSplit)")
                    AppLogger.shared.debug("    Shares from split: \(sharesFromSplit)")
                    AppLogger.shared.debug("    Total shares after split: \(totalSharesAfterSplit)")
                    AppLogger.shared.debug("    Split ratio: \(splitRatio)")
                    
                    // Adjust all prior holdings by the split ratio
                    for j in 0..<adjustedLots.count {
                        adjustedLots[j].quantity *= splitRatio
                        adjustedLots[j].costPerShare /= splitRatio
                        adjustedLots[j].marketValue = adjustedLots[j].quantity * adjustedLots[j].price
                        adjustedLots[j].costBasis = adjustedLots[j].quantity * adjustedLots[j].costPerShare
                        // Gain/loss will be recalculated at the end
                        adjustedLots[j].gainLossDollar = 0.0
                        adjustedLots[j].gainLossPct = 0.0
                        
                        adjustedLots[j].splitMultiple *= splitRatio
                        
                        AppLogger.shared.debug("    Adjusted lot \(j): \(adjustedLots[j].openDate), shares: \(adjustedLots[j].quantity), cost: \(adjustedLots[j].costPerShare), basis: \(adjustedLots[j].costBasis), multiple: \(adjustedLots[j].splitMultiple)")
                    }
                    
                    AppLogger.shared.debug("  --- Removed split transaction and adjusted \(adjustedLots.count) prior lots")
                } else {
                    AppLogger.shared.debug("  --- No prior shares to adjust, skipping split transaction")
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
        
        AppLogger.shared.debug("=== adjustForStockSplits - returning \(adjustedLots.count) adjusted lots ===")
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
//        if debug { AppLogger.shared.debug("🔍 computeTaxLots - Setting loading to TRUE") }
        loadingDelegate?.setLoading(true)
        defer {
//            if debug { AppLogger.shared.debug("🔍 computeTaxLots - Setting loading to FALSE") }
            loadingDelegate?.setLoading(false)
        }

        AppLogger.shared.debug("=== computeTaxLots \(symbol) ===")

        // Return cached results if available
        if symbol == m_lastFilteredTaxLotSymbol {
            AppLogger.shared.debug("=== computeTaxLots \(symbol) - returning \(m_lastFilteredPositionRecords.count) cached ===")
            return m_lastFilteredPositionRecords
        }
        m_lastFilteredTaxLotSymbol = symbol

        AppLogger.shared.debug( " --- computeTaxLots() - seeking zero ---" )

        var fetchAttempts = 0
        let maxFetchAttempts = 5  // Limit fetch attempts to prevent infinite loops
        var totalTransactionsFound = 0
        var totalSharesFound = 0.0
        
        // Process transactions until we find zero shares or reach max quarters
        while fetchAttempts < maxFetchAttempts {
            fetchAttempts += 1
            AppLogger.shared.debug("  --- computeTaxLots iteration \(fetchAttempts)/\(maxFetchAttempts) ---")

            // Clear previous results
            m_lastFilteredPositionRecords.removeAll(keepingCapacity: true)

            // Get current share count
            var currentShareCount : Double = getShareCount(symbol: symbol)
            // Get quarter delta safely for logging
            let quarterDeltaForLogging = m_quarterDeltaLock.withLock {
                return m_quarterDelta
            }
            AppLogger.shared.debug("  --- computeTaxLots -- \(symbol) -- computeTaxLots() currentShareCount: \(currentShareCount) quarterDelta: \(quarterDeltaForLogging) --")

            // get last price for this security - use real-time quote data if available, fallback to price history
            let lastPrice: Double
            if let currentPrice = currentPrice {
                lastPrice = currentPrice
            } else if let quote = fetchQuote(symbol: symbol)?.quote?.lastPrice {
                lastPrice = quote
            } else if let extended = fetchQuote(symbol: symbol)?.extended?.lastPrice {
                lastPrice = extended
            } else if let regular = fetchQuote(symbol: symbol)?.regular?.regularMarketLastPrice {
                lastPrice = regular
            } else {
                lastPrice = fetchPriceHistory(symbol: symbol)?.candles.last?.close ?? 0.0
            }
            showIncompleteDataWarning = true
            // Process all trade transactions - only process again if the number of transactions changes
            AppLogger.shared.debug( "  --- computeTaxLots  - calling getTransactionsFor(symbol: \(symbol))" )
            for transaction in self.getTransactionsFor(symbol: symbol)
            where ( (transaction.type == .trade) || (transaction.type == .receiveAndDeliver))
            {
                totalTransactionsFound += 1
                AppLogger.shared.debug("  --- Processing transaction \(totalTransactionsFound): \(transaction.tradeDate ?? "unknown"), type: \(transaction.type?.rawValue ?? "n/a"), activity: \(transaction.activityType ?? .UNKNOWN)")
                
                for transferItem in transaction.transferItems {
                    // find transferItems where the shares, value, and cost are not 0
                    guard let numberOfShares = transferItem.amount,
                          numberOfShares != 0.0,
                          transferItem.instrument?.symbol == symbol
                    else {
                        AppLogger.shared.debug("  --- Skipping transferItem: shares=\(transferItem.amount ?? 0), cost=\(transferItem.price ?? 0), symbol=\(transferItem.instrument?.symbol ?? "nil")")
                        continue
                    }
                    
                    totalSharesFound += numberOfShares
                    AppLogger.shared.debug("  --- Found transferItem: \(numberOfShares) shares at $\(transferItem.price ?? 0) on \(transaction.tradeDate ?? "unknown")")
                    
                    // Don't calculate gain/loss here - it will be calculated after adjustments
                    let gainLossDollar = 0.0  // Will be recalculated after adjustments
                    let gainLossPct = 0.0     // Will be recalculated after adjustments
                    
                    // Parse trade date
                    guard let tradeDate : String = try? Date(transaction.tradeDate ?? "1970-01-01T00:00:00+0000",
                                                  strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false)).dateString() else {
                        AppLogger.shared.error( " -- Failed to parse date in trade.  transferItem: \(transferItem.dump())")
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
                    AppLogger.shared.debug("  --- Balance after transaction: \(numberOfShares) shares -> currentShareCount: \(currentShareCount)")
                    
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
                    AppLogger.shared.debug( "  -- computeTaxLots:  -- Found zero -- " )
                    AppLogger.shared.debug( "  -- computeTaxLots:  -- SUCCESS: Zero point found at iteration \(fetchAttempts) -- " )
                    break
                }
                // Don't break on negative share count - continue processing to find all buy transactions
                // The negative share count indicates we've encountered more sell transactions than buy transactions
                // but we need to continue to find all the buy transactions that account for our current position

            } // for transaction
            
            // Break if we've found zero shares or reached max quarters
            if ( isNearZero(currentShareCount) ) {
                AppLogger.shared.debug( "  -- computeTaxLots:  -- found near zero --  currentShareCount = \(currentShareCount)" )
                AppLogger.shared.debug( "  -- computeTaxLots:  -- SUCCESS: Zero point found after processing all transactions -- " )
                showIncompleteDataWarning = false
                break
            }
            // Don't break on negative share count - continue processing to find all buy transactions
            // The negative share count indicates we've encountered more sell transactions than buy transactions
            // but we need to continue to find all the buy transactions that account for our current position
            else if  ( self.maxQuarterDelta <= quarterDeltaForLogging )  {
//                showIncompleteDataWarning = true
                AppLogger.shared.debug( " -- Reached max quarter delta --" )
                AppLogger.shared.debug( " -- WARNING: Incomplete data - reached max quarter delta. Setting showIncompleteDataWarning = true --" )
                break
            }
            else if fetchAttempts >= maxFetchAttempts {
//                showIncompleteDataWarning = true
                AppLogger.shared.debug( " -- Reached max fetch attempts --" )
                AppLogger.shared.debug( " -- WARNING: Incomplete data - reached max fetch attempts. Setting showIncompleteDataWarning = true --" )
                break
            }
            else
            {
                AppLogger.shared.debug( " -- Fetching more records (attempt \(fetchAttempts)) --" )
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
                    AppLogger.shared.debug("   !!! fetch attempt \(fetchAttempts) timed out after \(m_fetchTimeout) seconds")
                }
            }
            
        }
        
        if fetchAttempts >= maxFetchAttempts {
            AppLogger.shared.debug("Warning: computeTaxLots reached maximum fetch attempts for symbol: \(symbol)")
            // invalid or incomplete warning
        }
        
        // Sort records by date (oldest first) and cost (highest first for same date)
        m_lastFilteredPositionRecords.sort { ($0.openDate < $1.openDate) || ($0.openDate == $1.openDate && ( ($0.costPerShare > $1.costPerShare) || ($0.quantity > $1.quantity) ) ) }
        
        // Match sells with buys using highest price up to that point
        var remainingRecords: [SalesCalcPositionsRecord] = []
        var buyQueue: [SalesCalcPositionsRecord] = []
//        if debug {  AppLogger.shared.debug( "  -- computeTaxLots:  -- removing sold shares -- " ) }
        for record : SalesCalcPositionsRecord in m_lastFilteredPositionRecords {
            // collect buy records until you find a sell trade record.
            if record.quantity > 0 {
//                if debug {  AppLogger.shared.debug( "  -- computeTaxLots:     ++++   adding buy to queue: \t\(record.openDate), \tquantity: \(record.quantity), \tcostPerShare: \(record.costPerShare)" ) }
                // Add buy record to queue
                buyQueue.append(record)
            } else {
//                if debug {  AppLogger.shared.debug( "  -- computeTaxLots:     ----   processing sell.  buy queue size: \(buyQueue.count),  sell: \t\(record.openDate), \tquantity: \(record.quantity), \tcostPerShare: \(record.costPerShare),  marketValue: \(record.marketValue)" ) }
                // If this is a .trade record, sort the buy queue by high price.  On trades, the cost-per-share will not be zero
                buyQueue.sort { ( ( 0.0 == $0.costPerShare) || ($0.costPerShare > $1.costPerShare) )}

//                // AppLogger.shared.debug the buy queue for debugging
//                if debug
//                {
//                    // AppLogger.shared.debug each record in the buy queue
//                    for buyRecord in buyQueue
//                    {
//                        AppLogger.shared.debug( "  -- computeTaxLots:         !         buyRecord: \t\(buyRecord.openDate), \t\(buyRecord.quantity), \t\(buyRecord.costPerShare)")
//                    }
//                }


                // Process sell record
                var remainingSellQuantity = abs(record.quantity)

                // Match sell with buys
                while remainingSellQuantity > 0 && !buyQueue.isEmpty {
                    var buyRecord = buyQueue.removeFirst()
                    let buyQuantity = buyRecord.quantity

//                    if debug {  AppLogger.shared.debug( "  -- computeTaxLots:         remainingSellQuantity: \(remainingSellQuantity),  buyQuantity: \(buyQuantity),  queue size: \(buyQueue.count)" ) }
//                    if debug {  AppLogger.shared.debug( "  -- computeTaxLots:         !         buyRecord: \t\(buyRecord.openDate), \t\(buyRecord.quantity), \t\(buyRecord.costPerShare)") }
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

        AppLogger.shared.debug("=== computeTaxLots Summary for \(symbol) ===")
        AppLogger.shared.debug("Total transactions processed: \(totalTransactionsFound)")
        AppLogger.shared.debug("Total shares found in transactions: \(totalSharesFound)")
        AppLogger.shared.debug("Current share count from position: \(getShareCount(symbol: symbol))")
        AppLogger.shared.debug("Final tax lots created: \(remainingRecords.count)")
        for (index, record) in remainingRecords.enumerated() {
            AppLogger.shared.debug("  Lot \(index): \(record.quantity) shares at $\(record.costPerShare) on \(record.openDate)")
        }
        AppLogger.shared.debug("=== End computeTaxLots Summary ===")

        m_lastFilteredPositionRecords = remainingRecords
        
        // Apply stock split adjustments
        m_lastFilteredPositionRecords = adjustForStockSplits(m_lastFilteredPositionRecords)
        
        // Calculate gain/loss for each tax lot based on current price and remaining shares
        let finalPrice = currentPrice ?? fetchPriceHistory(symbol: symbol)?.candles.last?.close ?? 0.0
        
        for i in 0..<m_lastFilteredPositionRecords.count {
            let lot = m_lastFilteredPositionRecords[i]
            let remainingShares = lot.quantity
            let costPerShare = lot.costPerShare
            let costBasis = remainingShares * costPerShare
            let marketValue = remainingShares * finalPrice
            let gainLossDollar = marketValue - costBasis
            let gainLossPct = costBasis != 0 ? ((finalPrice - costPerShare) / costPerShare) * 100.0 : 0.0
            
            m_lastFilteredPositionRecords[i].gainLossDollar = gainLossDollar
            m_lastFilteredPositionRecords[i].gainLossPct = gainLossPct
            m_lastFilteredPositionRecords[i].marketValue = marketValue
            m_lastFilteredPositionRecords[i].costBasis = costBasis
            m_lastFilteredPositionRecords[i].price = finalPrice
        }
        
//        if debug { AppLogger.shared.debug("  -- computeTaxLots: returning \(m_lastFilteredPositionRecords.count) records for symbol \(symbol)") }
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
        AppLogger.shared.debug("=== fetchTransactionHistoryReduced - quarters: \(quarters) ===")
        //AppLogger.shared.debug("🔍 fetchTransactionHistoryReduced - Setting loading to TRUE")
        loadingDelegate?.setLoading(true)
        defer {
            //AppLogger.shared.debug("🔍 fetchTransactionHistoryReduced - Setting loading to FALSE")
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
                    
                    AppLogger.shared.debug("  -- processing quarter: \(quarter)")
                    
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
                                        AppLogger.shared.error("fetchTransactionHistoryReduced. Invalid URL")
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
                                            AppLogger.shared.error("Invalid response type")
                                            return nil
                                        }
                                        
                                        if httpResponse.statusCode != 200 {
                                            AppLogger.shared.error("response code: \(httpResponse.statusCode)")
                                            // print data as a string
                                            AppLogger.shared.error( "response data: \(String(data: data, encoding: .utf8) ?? "N/A")" )
                                            if let serviceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                                                serviceError.printErrors(prefix: "  fetchTransactionHistoryReduced ")
                                            }
                                            return nil
                                        }
                                        
                                        let decoder = JSONDecoder()
                                        let transactions = try decoder.decode([Transaction].self, from: data)
                                        return transactions
                                    } catch {
                                        AppLogger.shared.error("fetchTransactionHistoryReduced Error: \(error.localizedDescription)")
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
        
        AppLogger.shared.debug("Fetched \(m_transactionList.count - initialSize) transactions in \(quarters) quarters")
        
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
        let summary: SymbolContractSummary? = m_symbolsWithContracts[symbol]
        AppLogger.shared.debug("🔍 getContractsForSymbol: Symbol '\(symbol)' has \(summary?.contractCount ?? 0) contracts")
        if let summary: SymbolContractSummary = summary {
            AppLogger.shared.debug("  📋 Summary: \(summary.contractCount) contracts, min DTE: \(summary.minimumDTE ?? -1), total quantity: \(summary.totalQuantity)")
        }
        // Since we no longer store individual positions, return nil
        return nil
    }

    /**
     * get the number of contracts for the given symbol
     */
    public func getContractCountForSymbol(_ symbol: String) -> Double {
        guard let summary: SymbolContractSummary = m_symbolsWithContracts[symbol] else {
            return 0.0
        }
        return summary.totalQuantity
    }

    /**
     * getMinimumDTEForSymbol - return the minimum DTE for a given underlying symbol
     */
    public func getMinimumDTEForSymbol(_ symbol: String) -> Int? {
        guard let summary: SymbolContractSummary = m_symbolsWithContracts[symbol], summary.contractCount > 0 else {
            return nil
        }
        return summary.minimumDTE
    }

    /**
     * getMinimumStrikeForSymbol - return the minimum Strike Price for a given underlying symbol
     */
    public func getMinimumStrikeForSymbol(_ symbol: String) -> Double? {
        guard let summary: SymbolContractSummary = m_symbolsWithContracts[symbol], summary.contractCount > 0 else {
            return nil
        }
        return summary.minimumStrike
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
            AppLogger.shared.debug("  -- Removed \(newTransactions.count - uniqueNewTransactions.count) duplicate transactions")
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

    // MARK: - OCO Order Creation Methods
    
    /**
     * Create an OCO order from selected buy and sell orders
       [OCO-SUBMIT] JSON preview : {
       "enteredTime" : "2025-07-26T13:45:59Z",
       "editable" : false,
       "cancelable" : true,
       "releaseTime" : "2025-07-27T13:30:00Z",
       "status" : "AWAITING_PARENT_ORDER",
       "orderStrategyType" : "OCO",
       "accountNumber" : 00000767,
       "childOrderStrategies" : [
         {
           "remainingQuantity" : 37,
           "priceLinkType" : "PERCENT",
           "releaseTime" : "2025-07-27T13:30:00Z",
           "stopType" : "BID",
           "cancelable" : true,
           "requestedDestination" : "AUTO",
           "priceOffset" : 0.02,
           "quantity" : 37,
           "filledQuantity" : 0,
           "priceLinkBasis" : "LAST",
           "enteredTime" : "2025-07-27T13:30:00Z",
           "destinationLinkName" : "AutoRoute",
           "orderLegCollection" : [
             {
               "instruction" : "BUY",
               "orderLegType" : "EQUITY",
               "positionEffect" : "OPENING",
               "instrument" : {
                 "assetType" : "EQUITY",
                 "symbol" : "PBI"
               },
               "legId" : 1,
               "quantity" : 37
             }
           ],
           "editable" : false,
           "accountNumber" : 00000767,
           "orderStrategyType" : "SINGLE",
           "orderId" : 0,
           "status" : "AWAITING_RELEASE_TIME",
           "tag" : "API_TOS:CHART"
         }
       ]
     }
     */
    public func createOrder(
        symbol: String,
        accountNumber: Int64,
        selectedOrders: [(String, Any)],
        releaseTime: String
    ) -> Order? {
        AppLogger.shared.debug("=== createOrder ===")
        AppLogger.shared.debug("Symbol: \(symbol)")
        AppLogger.shared.debug("Selected Orders Count: \(selectedOrders.count)")
        AppLogger.shared.debug("Release Time: \(releaseTime)")
        
        // Get the actual current market price for the symbol
        let currentPrice: Double
        if let quote = fetchQuote(symbol: symbol)?.quote?.lastPrice {
            currentPrice = quote
            AppLogger.shared.debug("📊 Using real-time quote price: $\(currentPrice)")
        } else if let extended = fetchQuote(symbol: symbol)?.extended?.lastPrice {
            currentPrice = extended
            AppLogger.shared.debug("📊 Using extended hours quote price: $\(currentPrice)")
        } else if let regular = fetchQuote(symbol: symbol)?.regular?.regularMarketLastPrice {
            currentPrice = regular
            AppLogger.shared.debug("📊 Using regular market quote price: $\(currentPrice)")
        } else {
            // Fallback to a reasonable default if no quote data available
            currentPrice = 50.0
            AppLogger.shared.debug("⚠️ No quote data available, using fallback current price: $\(currentPrice)")
        }
        
        // If there's only one order, return it directly without OCO wrapper
        if selectedOrders.count == 1 {
            AppLogger.shared.debug("📝 Single order detected - creating direct order without OCO wrapper")
            
            let (orderType, order) = selectedOrders[0]
            if let singleOrder = createSimplifiedChildOrder(
                symbol: symbol,
                accountNumber: accountNumber,
                orderType: orderType,
                order: order,
                legId: 1,
                currentPrice: currentPrice
            ) {
                AppLogger.shared.debug("✅ Created single order directly")
                return singleOrder
            } else {
                AppLogger.shared.error("❌ Failed to create single order")
                return nil
            }
        }
        
        // For multiple orders, create OCO structure
        AppLogger.shared.debug("📝 Multiple orders detected - creating OCO structure")
        
        // Create child order strategies based on the working sample_order7.py pattern
        var childOrderStrategies: [Order] = []
        
        for (index, (orderType, order)) in selectedOrders.enumerated() {
            // Use the same current market price for all orders to ensure consistency
            AppLogger.shared.debug("📊 Order \(index + 1) (\(orderType)): Using current market price: $\(currentPrice)")
            
            if let childOrder = createSimplifiedChildOrder(
                symbol: symbol,
                accountNumber: accountNumber,
                orderType: orderType,
                order: order,
                legId: index + 1,
                currentPrice: currentPrice
            ) {
                childOrderStrategies.append(childOrder)
                AppLogger.shared.debug("✅ Created simplified child order \(index + 1): \(orderType)")
            } else {
                AppLogger.shared.error("❌ Failed to create simplified child order \(index + 1): \(orderType)")
            }
        }
        
        guard !childOrderStrategies.isEmpty else {
            AppLogger.shared.warning("❌ No valid child orders created")
            return nil
        }
        
        // If any selected BUY order prefers DAY duration, force all child orders to use DAY for consistency
        let forceDayDuration: Bool = selectedOrders.contains { (orderType, order) in
            if orderType == "BUY", let buy = order as? BuyOrderRecord { return buy.preferDayDuration }
            return false
        }

        if forceDayDuration {
            for child in childOrderStrategies {
                child.duration = .DAY
            }
        }

        // Create the parent OCO order (simplified - no timing constraints)
        let ocoOrder = Order(
            orderStrategyType: .OCO,
            accountNumber: accountNumber,
            childOrderStrategies: childOrderStrategies,
            statusDescription: forceDayDuration ? "Simplified OCO order (DAY)" : "Simplified OCO order"
        )
        
        AppLogger.shared.debug("✅ Created simplified OCO order with \(childOrderStrategies.count) child orders")
        return ocoOrder
    }
    
    /**
     * Create a sequence order with nested child orders (each order contains the next as a child)
     */
    public func createSequenceOrder(
        symbol: String,
        accountNumber: Int64,
        selectedOrders: [BuySequenceOrder]
    ) -> Order? {
        AppLogger.shared.debug("=== createSequenceOrder ===")
        AppLogger.shared.debug("Symbol: \(symbol)")
        AppLogger.shared.debug("Selected Orders Count: \(selectedOrders.count)")
        
        guard !selectedOrders.isEmpty else {
            AppLogger.shared.warning("❌ No sequence orders provided")
            return nil
        }
        
        // Sort orders by order index to ensure proper sequence (lowest price first)
        let sortedOrders = selectedOrders.sorted { $0.orderIndex < $1.orderIndex }
        
        // Create nested structure: each order contains the next as a child
        // Start with the lowest-priced order (first in sequence) and work forwards
        var currentOrder: Order? = nil
        
        for (index, sequenceOrder) in sortedOrders.enumerated() {
            if let childOrder = createSequenceChildOrder(
                symbol: symbol,
                accountNumber: accountNumber,
                sequenceOrder: sequenceOrder,
                legId: index + 1,
                childOrder: currentOrder
            ) {
                currentOrder = childOrder
                AppLogger.shared.debug("✅ Created nested sequence order \(index + 1): shares=\(sequenceOrder.shares), target=\(sequenceOrder.targetPrice)")
            } else {
                AppLogger.shared.warning("❌ Failed to create sequence order \(index + 1)")
                return nil
            }
        }
        
        guard let finalOrder = currentOrder else {
            AppLogger.shared.warning("❌ No valid sequence order created")
            return nil
        }
        
        AppLogger.shared.debug("✅ Created nested sequence order structure")
        return finalOrder
    }
    
    /**
     * Create a sequence child order with optional nested child order
     */
    private func createSequenceChildOrder(
        symbol: String,
        accountNumber: Int64,
        sequenceOrder: BuySequenceOrder,
        legId: Int,
        childOrder: Order? = nil
    ) -> Order? {
        
        // Create the instrument
        let instrument = AccountsInstrument(
            assetType: .EQUITY,
            symbol: symbol
        )
        
        AppLogger.shared.debug("=== createSequenceChildOrder: Creating sequence BUY order:")
        AppLogger.shared.debug("  Shares: \(sequenceOrder.shares)")
        AppLogger.shared.debug("  Target: \(sequenceOrder.targetPrice)")
        AppLogger.shared.debug("  Entry: \(sequenceOrder.entryPrice)")
        AppLogger.shared.debug("  Trailing Stop: \(sequenceOrder.trailingStop)%")
        
        // Create the order leg collection for BUY
        let orderLeg = OrderLegCollection(
            orderLegType: .EQUITY,
            legId: Int64(legId),
            instrument: instrument,
            instruction: .BUY,
            quantity: sequenceOrder.shares
        )
        
        // Round prices and percentages to the penny (2 decimal places)
        let roundedTargetPrice = round(sequenceOrder.targetPrice * 100) / 100
        let roundedTrailingStopPercent = round(sequenceOrder.trailingStop * 100) / 100
        
        AppLogger.shared.debug("  📊 Rounded Values:")
        AppLogger.shared.debug("    Rounded Target Price: \(roundedTargetPrice)")
        AppLogger.shared.debug("    Rounded Trailing Stop %: \(roundedTrailingStopPercent)")
        
        // Create sequence BUY order
        AppLogger.shared.debug("  🏗️ Creating Order with parameters:")
        AppLogger.shared.debug("    session: .NORMAL")
        AppLogger.shared.debug("    duration: .GOOD_TILL_CANCEL")
        AppLogger.shared.debug("    orderType: .TRAILING_STOP_LIMIT")
        AppLogger.shared.debug("    complexOrderStrategyType: .NONE")
        AppLogger.shared.debug("    quantity: \(sequenceOrder.shares)")
        AppLogger.shared.debug("    destinationLinkName: AutoRoute")
        AppLogger.shared.debug("    stopPriceLinkBasis: .BID")
        AppLogger.shared.debug("    stopPriceLinkType: .PERCENT")
        AppLogger.shared.debug("    stopPriceOffset: \(roundedTrailingStopPercent)")
        AppLogger.shared.debug("    stopType: .BID")
        AppLogger.shared.debug("    priceLinkBasis: .MANUAL")
        AppLogger.shared.debug("    price: \(roundedTargetPrice)")
        AppLogger.shared.debug("    orderLegCollection: [orderLeg]")
        AppLogger.shared.debug("    orderStrategyType: .SINGLE")
        AppLogger.shared.debug("    cancelable: true")
        AppLogger.shared.debug("    editable: false")
        
        // Determine order strategy type and child orders
        let orderStrategyType: OrderStrategyType
        let childOrderStrategies: [Order]?
        
        if let childOrder = childOrder {
            // This order has a child, so it's a TRIGGER order
            orderStrategyType = .TRIGGER
            childOrderStrategies = [childOrder]
            AppLogger.shared.debug("  🔗 Creating TRIGGER order with child order")
        } else {
            // This is the final order (highest price), so it's a SINGLE order
            orderStrategyType = .SINGLE
            childOrderStrategies = nil
            AppLogger.shared.debug("  🎯 Creating SINGLE order (final in sequence)")
        }
        
        let childOrder = Order(
            session: .NORMAL,
            duration: .GOOD_TILL_CANCEL,
            orderType: .TRAILING_STOP_LIMIT,
            complexOrderStrategyType: .NONE,
            quantity: sequenceOrder.shares,
            destinationLinkName: "AutoRoute",
            stopPriceLinkBasis: .BID,
            stopPriceLinkType: .PERCENT,
            stopPriceOffset: roundedTrailingStopPercent,
            stopType: .BID,
            priceLinkBasis: .MANUAL,
            price: roundedTargetPrice, // Use rounded target price as limit price
            orderLegCollection: [orderLeg],
            orderStrategyType: orderStrategyType,
            cancelable: true,
            editable: false,
            accountNumber: accountNumber,
            childOrderStrategies: childOrderStrategies
        )
        
        AppLogger.shared.debug("  ✅ Order created successfully")
        return childOrder
    }
    
    /**
     * Create a simplified child order that matches the working sample_order7.py pattern
     */
    private func createSimplifiedChildOrder(
        symbol: String,
        accountNumber: Int64,
        orderType: String,
        order: Any,
        legId: Int,
        currentPrice: Double
    ) -> Order? {
        
        // Create the instrument
        let instrument = AccountsInstrument(
            assetType: .EQUITY,
            symbol: symbol
        )
        
        if orderType == "SELL" {
            guard let sellOrder = order as? SalesCalcResultsRecord else {
                AppLogger.shared.warning("❌ Invalid sell order type")
                return nil
            }
            
            AppLogger.shared.debug("=== createSimplifiedChildOrder:  Creating simplified SELL order:")
            AppLogger.shared.debug("  Shares: \(sellOrder.sharesToSell)")
            AppLogger.shared.debug("  Target: \(sellOrder.target)")
            AppLogger.shared.debug("  Entry: \(sellOrder.entry)")
            AppLogger.shared.debug("  Cancel: \(sellOrder.cancel)")
            
            // Create the order leg collection for SELL
            // Round down fractional shares for sell orders since quantity cannot be fractional
            let roundedQuantity = floor(sellOrder.sharesToSell)
            
            // Log if rounding was necessary
            if roundedQuantity != sellOrder.sharesToSell {
                AppLogger.shared.info("📊 SELL Order: Rounded quantity from \(sellOrder.sharesToSell) to \(roundedQuantity) shares")
            }
            
            let orderLeg = OrderLegCollection(
                orderLegType: .EQUITY,
                legId: Int64(legId),
                instrument: instrument,
                instruction: .SELL,
                quantity: roundedQuantity
            )
            
            // Use the trailing stop percentage from the sell order record (already calculated correctly)
            let trailingStopPercent: Double = sellOrder.trailingStop
            AppLogger.shared.debug("=== createSimplifiedChildOrder:  trailingStopPercent: \(trailingStopPercent) from sell order record")

            // Round prices and percentages to the penny (2 decimal places)
            let roundedTargetPrice = round(sellOrder.target * 100) / 100
            let roundedTrailingStopPercent = round(trailingStopPercent * 100) / 100
            
            AppLogger.shared.debug("  📊 Rounded Values:")
            AppLogger.shared.debug("    Rounded Target Price: \(roundedTargetPrice)")
            AppLogger.shared.debug("    Rounded Trailing Stop %: \(roundedTrailingStopPercent)")
            
            // Create simplified SELL order matching sample_order7.py pattern
            let childOrder = Order(
                session: .NORMAL,
                duration: .GOOD_TILL_CANCEL,
                orderType: .TRAILING_STOP_LIMIT,
                complexOrderStrategyType: .NONE,
                quantity: roundedQuantity,
                destinationLinkName: "AutoRoute",
                stopPriceLinkBasis: .ASK,
                stopPriceLinkType: .PERCENT,
                stopPriceOffset: roundedTrailingStopPercent,
                stopType: .ASK,
                priceLinkBasis: .MANUAL,
                price: roundedTargetPrice, // Use rounded target price as limit price
                orderLegCollection: [orderLeg],
                orderStrategyType: .SINGLE,
                cancelable: true,
                editable: false,
                accountNumber: accountNumber
            )
            
            return childOrder
            
        } else if orderType == "BUY" {
            guard let buyOrder = order as? BuyOrderRecord else {
                AppLogger.shared.warning("❌ Invalid buy order type")
                return nil
            }
            
            AppLogger.shared.debug("Creating simplified BUY order:")
            AppLogger.shared.debug("  Shares: \(buyOrder.sharesToBuy)")
            AppLogger.shared.debug("  Target: \(buyOrder.targetBuyPrice)")
            AppLogger.shared.debug("  Entry: \(buyOrder.entryPrice)")
            
            // Create the order leg collection for BUY
            let orderLeg = OrderLegCollection(
                orderLegType: .EQUITY,
                legId: Int64(legId),
                instrument: instrument,
                instruction: .BUY,
                quantity: buyOrder.sharesToBuy
            )
            
            // For buy orders, trailing stop should be above current price to trigger the order
            // Use the trailing stop value from the buy order record (already calculated correctly)
            let trailingStopPercent: Double = buyOrder.trailingStop
            AppLogger.shared.debug("=== createSimplifiedChildOrder:  Trailing Stop Percent: \(trailingStopPercent) from buy order record")

            // Round prices and percentages to the penny (2 decimal places)
            let roundedTargetPrice = round(buyOrder.targetBuyPrice * 100) / 100
            let roundedTrailingStopPercent = round(trailingStopPercent * 100) / 100
            
            AppLogger.shared.debug("  📊 Rounded Values:")
            AppLogger.shared.debug("    Rounded Target Price: \(roundedTargetPrice)")
            AppLogger.shared.debug("    Rounded Trailing Stop %: \(roundedTrailingStopPercent)")
            
            // Create simplified BUY order matching sample_order7.py pattern
            let childOrder = Order(
                session: .NORMAL,
                duration: buyOrder.preferDayDuration ? .DAY : .GOOD_TILL_CANCEL,
                orderType: .TRAILING_STOP_LIMIT,
                complexOrderStrategyType: .NONE,
                quantity: buyOrder.sharesToBuy,
                destinationLinkName: "AutoRoute",
                stopPriceLinkBasis: .BID,
                stopPriceLinkType: .PERCENT,
                stopPriceOffset: roundedTrailingStopPercent,
                stopType: .BID,
                priceLinkBasis: .MANUAL,
                price: roundedTargetPrice, // Use rounded target price as limit price
                orderLegCollection: [orderLeg],
                orderStrategyType: .SINGLE,
                cancelable: true,
                editable: false,
                accountNumber: accountNumber
            )
            
            return childOrder
        }
        
        AppLogger.shared.warning("❌ Unknown order type: \(orderType)")
        return nil
    }

    // MARK: - Optimized Tax Lot Calculation
    public func computeTaxLotsOptimized(symbol: String, currentPrice: Double? = nil) -> [SalesCalcPositionsRecord] {
        startPerformanceTimer("computeTaxLotsOptimized_\(symbol)")
        
        AppLogger.shared.debug("=== computeTaxLotsOptimized \(symbol) ===")
        
        // Check cache first - this is the key performance improvement
        if let cachedTaxLots = getCachedTaxLots(for: symbol) {
            AppLogger.shared.debug("=== computeTaxLotsOptimized \(symbol) - returning \(cachedTaxLots.count) cached ===")
            logPerformance("computeTaxLotsOptimized_\(symbol)")
            return cachedTaxLots
        }
        
        // Get current share count and determine optimal time range
        let currentShareCount = getShareCount(symbol: symbol)
        let optimalQuarters = calculateOptimalTimeRange(for: symbol, currentShares: currentShareCount)
        
        AppLogger.shared.debug("=== computeTaxLotsOptimized \(symbol) - using optimal range: \(optimalQuarters) quarters ===")
        
        // Ensure we have enough transaction history for this calculation
        let currentQuarterDelta = m_quarterDeltaLock.withLock { return m_quarterDelta }
        if currentQuarterDelta < optimalQuarters {
            AppLogger.shared.debug("=== computeTaxLotsOptimized \(symbol) - expanding transaction history to \(optimalQuarters) quarters ===")
            
            // Use DispatchGroup to wait for the async operation with timeout
            let group = DispatchGroup()
            group.enter()
            
            // Start the fetch operation
            Task {
                // Fetch all needed quarters at once instead of incrementally
                for _ in currentQuarterDelta..<optimalQuarters {
                    await self.fetchTransactionHistory()
                }
                group.leave()
            }
            
            // Wait for completion or timeout
            let result = group.wait(timeout: .now() + m_fetchTimeout)
            if result == .timedOut {
                AppLogger.shared.warning("!!! computeTaxLotsOptimized \(symbol) timed out after \(m_fetchTimeout) seconds")
            }
        }
        
        // Clear previous results
        m_lastFilteredPositionRecords.removeAll(keepingCapacity: true)
        
        // Get last price for this security
        let lastPrice: Double
        if let currentPrice = currentPrice {
            lastPrice = currentPrice
        } else if let quote = fetchQuote(symbol: symbol)?.quote?.lastPrice {
            lastPrice = quote
        } else if let extended = fetchQuote(symbol: symbol)?.extended?.lastPrice {
            lastPrice = extended
        } else if let regular = fetchQuote(symbol: symbol)?.regular?.regularMarketLastPrice {
            lastPrice = regular
        } else {
            lastPrice = fetchPriceHistory(symbol: symbol)?.candles.last?.close ?? 0.0
        }
        
        // Use optimized transaction fetching with caching
        let transactions = getTransactionsForOptimized(symbol: symbol)
        AppLogger.shared.debug("=== computeTaxLotsOptimized \(symbol) - processing \(transactions.count) transactions ===")
        
        var totalTransactionsFound = 0
        var totalSharesFound = 0.0
        var workingShareCount = currentShareCount
        
        // Process all trade transactions in a single pass
        for transaction in transactions
        where (transaction.type == .trade) || (transaction.type == .receiveAndDeliver) {
            totalTransactionsFound += 1
            
            for transferItem in transaction.transferItems {
                // Find transferItems where the shares, value, and cost are not 0
                guard let numberOfShares = transferItem.amount,
                      numberOfShares != 0.0,
                      transferItem.instrument?.symbol == symbol
                else {
                    continue
                }
                
                totalSharesFound += numberOfShares
                
                // Don't calculate gain/loss here - it will be calculated after adjustments
                let gainLossDollar = 0.0
                let gainLossPct = 0.0
                
                // Parse trade date
                guard let tradeDate: String = try? Date(transaction.tradeDate ?? "1970-01-01T00:00:00+0000",
                                              strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false)).dateString() else {
                    AppLogger.shared.error("-- Failed to parse date in trade. transferItem: \(transferItem.dump())")
                    continue
                }
                
                // Update share count (working backwards)
                if numberOfShares > 0 {
                    // BUY transaction - subtract shares
                    workingShareCount = ((workingShareCount - numberOfShares) * 100000).rounded() / 100000
                } else {
                    // SELL transaction - add back shares
                    workingShareCount = ((workingShareCount + abs(numberOfShares)) * 100000).rounded() / 100000
                }
                
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
                        splitMultiple: 1.0
                    )
                )
                
                // Break if we find zero shares
                if isNearZero(workingShareCount) {
                    showIncompleteDataWarning = false
                    AppLogger.shared.debug("-- computeTaxLotsOptimized: -- Found zero -- SUCCESS: Zero point found")
                    break
                }
            }
            
            // Break if we found zero shares
            if isNearZero(workingShareCount) {
                break
            }
        }
        
        // Set warning if we didn't find zero
        if !isNearZero(workingShareCount) {
            showIncompleteDataWarning = true
            AppLogger.shared.warning("Warning: computeTaxLotsOptimized could not find zero point for symbol: \(symbol)")
        }
        
        // Sort records by date (oldest first) and cost (highest first for same date)
        m_lastFilteredPositionRecords.sort { ($0.openDate < $1.openDate) || ($0.openDate == $1.openDate && ( ($0.costPerShare > $1.costPerShare) || ($0.quantity > $1.quantity) ) ) }
        
        // Match sells with buys using highest price up to that point
        var remainingRecords: [SalesCalcPositionsRecord] = []
        var buyQueue: [SalesCalcPositionsRecord] = []
        
        for record: SalesCalcPositionsRecord in m_lastFilteredPositionRecords {
            // collect buy records until you find a sell trade record.
            if record.quantity > 0 {
                // Add buy record to queue
                buyQueue.append(record)
            } else {
                // If this is a .trade record, sort the buy queue by high price. On trades, the cost-per-share will not be zero
                buyQueue.sort { ( ( 0.0 == $0.costPerShare) || ($0.costPerShare > $1.costPerShare) )}
                
                // Process sell record
                var remainingSellQuantity = abs(record.quantity)
                
                // Match sell with buys
                while remainingSellQuantity > 0 && !buyQueue.isEmpty {
                    var buyRecord = buyQueue.removeFirst()
                    let buyQuantity = buyRecord.quantity
                    
                    if buyQuantity <= remainingSellQuantity {
                        // Buy record fully matches sell
                        remainingSellQuantity -= buyQuantity
                    } else {
                        // Buy record partially matches sell - put it at the head of the queue if it is at least $0.01
                        if( 0.01 <= round( buyRecord.quantity * 100.0 ) / 100.0 ) {
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
        
        AppLogger.shared.debug("=== computeTaxLotsOptimized Summary for \(symbol) ===")
        AppLogger.shared.debug("Total transactions processed: \(totalTransactionsFound)")
        AppLogger.shared.debug("Total shares found in transactions: \(totalSharesFound)")
        AppLogger.shared.debug("Current share count from position: \(getShareCount(symbol: symbol))")
        AppLogger.shared.debug("Final tax lots created: \(remainingRecords.count)")
        for (index, record) in remainingRecords.enumerated() {
            AppLogger.shared.debug("  Lot \(index): \(record.quantity) shares at $\(record.costPerShare) on \(record.openDate)")
        }
        AppLogger.shared.debug("=== End computeTaxLotsOptimized Summary ===")
        
        m_lastFilteredPositionRecords = remainingRecords
        
        // Apply stock split adjustments
        m_lastFilteredPositionRecords = adjustForStockSplits(m_lastFilteredPositionRecords)
        
        // Calculate gain/loss for each tax lot based on current price and remaining shares
        let finalPrice = currentPrice ?? fetchPriceHistory(symbol: symbol)?.candles.last?.close ?? 0.0
        
        for i in 0..<m_lastFilteredPositionRecords.count {
            let lot = m_lastFilteredPositionRecords[i]
            let remainingShares = lot.quantity
            let costPerShare = lot.costPerShare
            let costBasis = remainingShares * costPerShare
            let marketValue = remainingShares * finalPrice
            let gainLossDollar = marketValue - costBasis
            let gainLossPct = costBasis != 0 ? ((finalPrice - costPerShare) / costPerShare) * 100.0 : 0.0
            
            m_lastFilteredPositionRecords[i].gainLossDollar = gainLossDollar
            m_lastFilteredPositionRecords[i].gainLossPct = gainLossPct
            m_lastFilteredPositionRecords[i].marketValue = marketValue
            m_lastFilteredPositionRecords[i].costBasis = costBasis
            m_lastFilteredPositionRecords[i].price = finalPrice
        }
        
        // Cache the results for future use
        cacheTaxLots(m_lastFilteredPositionRecords, for: symbol)
        
        // Log performance metrics
        logPerformance("computeTaxLotsOptimized_\(symbol)")
        
        return m_lastFilteredPositionRecords
    }



} // SchwabClient


