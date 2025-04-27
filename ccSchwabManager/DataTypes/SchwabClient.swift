
import Foundation
import AuthenticationServices
import Compression

let schwabWeb           : String = "https://api.schwabapi.com"
let authorizationWeb    : String = "\(schwabWeb)/v1/oauth/authorize"
let accessTokenWeb      : String = "\(schwabWeb)/v1/oauth/token"


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
    private var m_secrets : Secrets
    private var m_selectedAccountName : String = "All"
    private var m_accounts : [SapiAccountContent] = []
    
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
    
    init( secrets: inout Secrets )
    {
        self.m_secrets = secrets
        // start thread to refresh the access token
        self.refreshAccessToken()
    }

    public func hasAccounts() -> Bool
    {
        return self.m_accounts.count > 0
    }

    public func getAccounts() -> [SapiAccountContent]
    {
        return self.m_accounts
    }

    public func hasSymbols() -> Bool
    {
        var symbolCount : Int = 0
        for account in self.m_accounts
        {
            symbolCount += account.securitiesAccount.positions.count
        }
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
        // provide the URL for authentication.
        let AUTHORIZE_URL : String  = "\(authorizationWeb)?client_id=\( self.m_secrets.getAppId() )&redirect_uri=\( self.m_secrets.getRedirectUrl() )"
        guard let url = URL( string: AUTHORIZE_URL ) else {
            completion(.failure(.invalidResponse))
            return
        }
        completion( .success( url ) )
        return
    }
    
    public func extractCodeFromURL( from url: String, completion: @escaping (Result<Void, ErrorCodes>) -> Void )
    {
        print( "extractCodeFromURL from \(url)")
        // extract the code and session from the URL
        let urlComponents = URLComponents(string: url )!
        let queryItems = urlComponents.queryItems
        self.m_secrets.setCode( queryItems?.first(where: { $0.name == "code" })?.value ?? "" )
        self.m_secrets.setSession( queryItems?.first(where: { $0.name == "session" })?.value ?? "" )
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
        let url = URL( string: "\(accessTokenWeb)" )!
        print( "accessTokenUrl: \(url)" )
        var accessTokenRequest = URLRequest( url: url )
        accessTokenRequest.httpMethod = "POST"
        // headers
        let authStringUnencoded = String("\( self.m_secrets.getAppId() ):\( self.m_secrets.getAppSecret() )")
        let authStringEncoded = authStringUnencoded.data(using: .utf8)!.base64EncodedString()
        
        accessTokenRequest.setValue( "Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization" )
        accessTokenRequest.setValue( "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type" )
        // body
        accessTokenRequest.httpBody = String("grant_type=authorization_code&code=\( self.m_secrets.getCode() )&redirect_uri=\( self.m_secrets.getRedirectUrl() )").data(using: .utf8)!
        print( "Posting access token request:  \(accessTokenRequest)" )
        
        
        let cmdline : String = """
            curl -X POST https://api.schwabapi.com/v1/oauth/token \ 
            -H 'Authorization: Basic \(authStringEncoded)' \ 
            -H 'Content-Type: application/x-www-form-urlencoded' \ 
            -d 'grant_type=authorization_code&code=\( self.m_secrets.getCode() )&redirect_uri=\( self.m_secrets.getRedirectUrl() )' 
            """
        print( "cmdline: \(cmdline)" )
        
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
                    self.m_secrets.setAccessToken( tokenDict["access_token"] as? String ?? "" )
                    self.m_secrets.setRefreshToken( tokenDict["refresh_token"] as? String ?? "" )
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
    func refreshAccessToken() {
        // 15 minute interval (in seconds)
        let interval: TimeInterval = 15 * 60

        // Create a background thread
        DispatchQueue.global(qos: .background).async {
            while true {
                print("Refreshing access token...")

                // Access Token Refresh Request
                guard let url = URL(string: "\(accessTokenWeb)") else {
                    print("Invalid URL for refreshing access token")
                    return
                }

                var refreshTokenRequest = URLRequest(url: url)
                refreshTokenRequest.httpMethod = "POST"

                // Headers
                let authStringUnencoded = "\(self.m_secrets.getAppId()):\(self.m_secrets.getAppSecret())"
                let authStringEncoded = authStringUnencoded.data(using: .utf8)!.base64EncodedString()
                refreshTokenRequest.setValue("Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization")
                refreshTokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

                // Body
                refreshTokenRequest.httpBody = "grant_type=refresh_token&refresh_token=\(self.m_secrets.getRefreshToken())".data(using: .utf8)!

                let semaphore = DispatchSemaphore(value: 0)

                URLSession.shared.dataTask(with: refreshTokenRequest) { data, response, error in
                    defer { semaphore.signal() }

                    guard let data = data, error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        print("Failed to refresh access token. Error: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }

                    // Parse the response
                    if let tokenDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        self.m_secrets.setAccessToken(tokenDict["access_token"] as? String ?? "")
                        self.m_secrets.setRefreshToken(tokenDict["refresh_token"] as? String ?? "")

                        if KeychainManager.saveSecrets(secrets: &self.m_secrets) {
                            print("Successfully refreshed and saved access token.")
                        } else {
                            print("Failed to save refreshed tokens.")
                        }
                    } else {
                        print("Failed to parse token response.")
                    }
                }.resume()

                // Wait for the request to finish before sleeping
                semaphore.wait()

                // Sleep for the specified interval
                Thread.sleep(forTimeInterval: interval)
            }
            print( "Done with dispatch queue." )
        }
    }


    /**
     * fetch account numbers and hashes from schwab
     */
    func fetchAccountNumbers() async
    {
        print("In fetchAccountNumbers.")
        guard let url = URL(string: "\(schwabWeb)/trader/v1/accounts/accountNumbers") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.getAccessToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to fetch account numbers.")
                return
            }

            let decoder = JSONDecoder()
            let accountNumberHashes = try decoder.decode([SapiAccountNumberHash].self, from: data)
            print("accountNumberHashes: \(accountNumberHashes.count)")

            if !accountNumberHashes.isEmpty {
                await MainActor.run {
                    self.m_secrets.setAccountNumberHash(accountNumberHashes)
                    if KeychainManager.saveSecrets(secrets: &self.m_secrets) {
                        print("Save account numbers")
                    } else {
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
    func fetchAccounts() async
    {
        print("=== fetchAccounts: selected: \(self.m_selectedAccountName) ===")
        var accountUrl = "\(schwabWeb)/trader/v1/accounts"
        if self.m_selectedAccountName != "All" {
            accountUrl += "/\(self.m_selectedAccountName)"
        }
        accountUrl += "?fields=positions"

        guard let url = URL(string: accountUrl) else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.getAccessToken())", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to fetch accounts.")
                return
            }

            let decoder = JSONDecoder()
            m_accounts  = try decoder.decode([SapiAccountContent].self, from: data)
            return
        } catch {
            print("Error: \(error.localizedDescription)")
            return
        }
    }


    /**
     * fettchPriceHistory  get the history of prices for all securities
     */
    func fetchPriceHistory( symbol : String ) async -> SapiCandleList?
    {
        print("=== fetchPriceHistory  ===")

        var priceHistoryUrl = "\(schwabWeb)/marketdata/v1/pricehistory"
        priceHistoryUrl += "?symbol=\(symbol)"

        /**
         * The chart period being requested.
         * Available values : day, month, year, ytd
         */
        priceHistoryUrl += "&periodType=month"

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
        priceHistoryUrl += "&frequency=1"

        /**
         *  Need previous close price/date
         */
        priceHistoryUrl += "&needPreviousClose=true"

        print( "fetchPriceHistory. priceHistoryUrl: \(priceHistoryUrl)" )

        guard let url = URL( string: priceHistoryUrl ) else {
            print("fetchPriceHistory. Invalid URL")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.getAccessToken())", forHTTPHeaderField: "Authorization")

        request.setValue("application/json", forHTTPHeaderField: "accept")

        print( "fetchPriceHistory. request: \(request)" )

        do {
            let ( data, response ) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("fetchPriceHistory. Failed to fetch price history.  code != 200.  \(response)")
                return nil
            }
            //let encodingOptions : Data.Base64EncodingOptions = []
            //let data : Data = rdata // .base64EncodedData(options: encodingOptions)
            try data.write(to: URL(fileURLWithPath: "priceHistory.gzip"))

            // Check if the data is GZIP-compressed
            // do not trust the header.
            // let isGzipEncoded = httpResponse.value(forHTTPHeaderField: "Content-Encoding")?.lowercased() == "gzip"
            let isGzipEncoded = ( (data[0] == 0x1f) && (data[1] == 0x8b) )
            // if the data is compressed, call gunzip
            print( "isGzipEncoded: \(isGzipEncoded)" )

            // check for the gzip magic number:  1f 8b
            // String( data[0], radix: 16, uppercase: false)
            print( " Magic:  \(String( data[0], radix: 16, uppercase: false)) \(String( data[1], radix: 16, uppercase: false))" )

            let decompressedData : Data = (isGzipEncoded ? decompressGzip( data: data ) : data) ?? Data()

//            // verify that data is utf8 encoded.
//            if let decompressedString : String = String(data: decompressedData, encoding: .utf8)
//            {
//                // print the first and last 100 characters
//                print( "data: ( \(decompressedString.count) ) " )
//                print( "start:   \(decompressedString[decompressedString.index(decompressedString.startIndex, offsetBy: 0)..<decompressedString.index(decompressedString.startIndex, offsetBy: 100)])" )
//                print( "end:     \(decompressedString[decompressedString.index(decompressedString.endIndex, offsetBy: -100)..<decompressedString.index(decompressedString.endIndex, offsetBy: 0)])" )
//            }
//            else
//            {
//                print("Data is not valid UTF-8.")
//            }

            let decoder = JSONDecoder()
            // data is gzip encoded, uncompress before passing to decode.
            let candleList : SapiCandleList  = try decoder.decode( SapiCandleList.self, from: decompressedData )
            print( "Fetched \(candleList.candles.count) candles for \(symbol)" )
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
        guard let priceHistory : SapiCandleList  =  await self.fetchPriceHistory( symbol: symbol ) else {
            print("computeATR Failed to fetch price history.")
            return 0.0
        }
        var close : Double  = priceHistory.previousClose
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
                let candle : SapiCandle  = priceHistory.candles[position]
                let prevClose : Double  = if (0 == position) {priceHistory.previousClose} else {priceHistory.candles[position-1].close}
                let tr : Double = max( abs( candle.high - candle.low ), abs( candle.high - prevClose ), abs( candle.low - prevClose ) )
                close = priceHistory.candles[position].close
                atr = ( (atr * Double(indx)) + tr ) / Double(indx+1)

//                // Example EPOCH time in milliseconds
//                let epochMilliseconds: Int64 = candle.datetime
//                // Convert milliseconds to seconds
//                let epochSeconds = TimeInterval(epochMilliseconds) / 1000
//                // Create a Date object
//                let date = Date(timeIntervalSince1970: epochSeconds)
//                // Format the Date to ISO 8601
//                let dateFormatter = ISO8601DateFormatter()
//                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//                let iso8601String = dateFormatter.string(from: date)
//                print( "indx: \(indx), date: \(candle.datetime),  candle.high: \(candle.high), candle.low: \(candle.low), prevClose: \(prevClose), tr: \(tr)" )
//                print( "( (atr: \(atr) * Double(indx-1): \(indx-1) + tr: \(tr) ) / Double(indx: \(indx))     date: \(candle.datetime), atr: \(atr),  ISO 8601 Format: \(iso8601String)" )
            }
        }
        // return the ATR as a percent.
        // return (atr * 0.78  / close * 100.0)
        return (atr * 0.89  / close * 100.0)
    }

}
