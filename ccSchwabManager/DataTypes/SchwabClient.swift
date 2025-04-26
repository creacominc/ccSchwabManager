
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
        // print( "SchwabClient init" )
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
     *  getRefreshToken - create a stream to get the refresh token every 10 minutes.
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
    public func getRefreshToken()
    {
        // 10 minute interval
        let interval : Int = 10 * 60 * 60

        // create thread which gets refresh token every 10 minutes.


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
            return // []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.getAccessToken())", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to fetch accounts.")
                return // []
            }

            let decoder = JSONDecoder()
            m_accounts  = try decoder.decode([SapiAccountContent].self, from: data)
            // let symbols : [String] = accounts.flatMap { $0.securitiesAccount.positions.map { $0?.instrument?.symbol ?? "" } }
            return // symbols
        } catch {
            print("Error: \(error.localizedDescription)")
            return // []
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
//        priceHistoryUrl += "&periodType=month"
//        priceHistoryUrl += "&period=1"
//        priceHistoryUrl += "&frequencyType=daily"
//        priceHistoryUrl += "&frequency=1"
//        priceHistoryUrl += "&needPreviousClose=true"

        print( "fetchPriceHistory. priceHistoryUrl: \(priceHistoryUrl)" )
        // priceHistoryUrl = "https://api.schwabapi.com/marketdata/v1/pricehistory?symbol=AAPL&periodType=month&needPreviousClose=true"

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
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("fetchPriceHistory. Failed to fetch price history.  code != 200.  \(response)")
                return nil
            }
            
            // Check if the data is GZIP-compressed
            let isGzipEncoded = httpResponse.value(forHTTPHeaderField: "Content-Encoding")?.lowercased() == "gzip"
            //let decompressedData = isGzipEncoded ? decompressGzipData(data: data) : data
            //let decompressedData = isGzipEncoded ? data.decompressGzipData(data: <#T##Data#>)

            // decompress the data from the data variable to decompressedData
            //let decompressedData = isGzipEncoded ? data.base64EncodedData(options: .lineLength64Characters) : data
//            let decompressedData : Data? = isGzipEncoded ? try? (data as NSData).decompressed(using: .zlib) as Data : data

            // if the data is compressed, call gunzip
            print( "isGzipEncoded: \(isGzipEncoded)" )
            let decompressedData : Data? = isGzipEncoded ? gunzip( data: data ) : data

//
//            guard let validData = decompressedData else {
//                print("Failed to decompress data.")
//                return nil
//            }
            
            print( "response = \(response)" )
//            print( "data = \(decompressedData)" )
////            print( "validData = \(validData)" )
//            // print the first 128 characters of the decompressedData
//            print( "decompressedData = \(decompressedData?.base64EncodedString() ?? "<empty>")" )

            // Convert the decompressed Data to a String
            if( nil == decompressedData )
            {
                print( "Failed to decmopress data" )
                return nil
            }

            let decompressedString : String = String(data: decompressedData!, encoding: .utf8)!
            print( "data: \(decompressedString)" )


            let decoder = JSONDecoder()
            // data is gzip encoded, uncompress before passing to decode.
            
            let candleList : SapiCandleList  = try decoder.decode(SapiCandleList.self, from: decompressedData!)
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
        var atr : Double  = 0.0
        print("=== computeATR  ===")
        guard let priceHistory : SapiCandleList  =  await self.fetchPriceHistory( symbol: symbol ) else {
            print("computeATR Failed to fetch price history.")
            return 0.0
        }
        /*
         * Compute the ATR as the average of the True Range.
         * The True Range is the maximum of absolute values of the High - Low, High - previous Close, and Low - previous Close
         */
        if priceHistory.candles.count > 1
        {
            let length : Int  =  min( priceHistory.candles.count - 1, 14 )
            for i in 1..<length
            {
                let candle : SapiCandle  = priceHistory.candles[i]
                let prevClose : Double  = priceHistory.candles[i+1].close
                let tr : Double = max( abs( candle.high - candle.low ), abs( candle.high - prevClose ), abs( candle.low - prevClose ) )
                atr = ( (atr * Double(i-1)) + tr ) / Double(i)
                print( "date: \(candle.datetimeISO8601), atr: \(atr)")
            }
        }
        return atr
    }

}
