
import Foundation
import AuthenticationServices

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
    //private var m_accounts : [SapiAccountNumberHash] = []
    private var m_selectedAccountName : String = "All"
    private var m_accounts : [SapiAccountContent] = [] // !!!!!

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
     * fetch account numbers and hashes from schwab
     */
    func fetchAccountNumbers()
    {
        guard !self.m_secrets.getAccessToken().isEmpty else { return }
        print( "In fetchAccountNumbers. " )
        var request = URLRequest(url: URL(string: "\(schwabWeb)/trader/v1/accounts/accountNumbers")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.getAccessToken())", forHTTPHeaderField: "Authorization")
        request.setValue( "application/json", forHTTPHeaderField: "Accept" )
        // print( "AccessToken: \(self.m_secrets.getAccessToken())" )
        URLSession.shared.dataTask(with: request)
        { data, response, error in
            guard let data = data, ( (error == nil) && ( response != nil ) )
            else
            {
                print( "Error: \( error?.localizedDescription ?? "Unknown error" )" )
                return
            }

            let httpResponse : HTTPURLResponse = response as! HTTPURLResponse
            if( httpResponse.statusCode == 200 )
            {
                do
                {
                    let decoder = JSONDecoder()
                    do
                    {
                        let accountNumberHashes = try decoder.decode([SapiAccountNumberHash].self, from: data)
                        print( "accountNumberHashes: \(accountNumberHashes.count)" )
                        if( !accountNumberHashes.isEmpty )
                        {
                            DispatchQueue.main.async
                            {
                                self.m_secrets.setAccountNumberHash( accountNumberHashes )
                                if( KeychainManager.saveSecrets( secrets: &self.m_secrets ) )
                                {
                                    print( "Save account numbers" )
                                }
                                else
                                {
                                    print( "Error saving account numbers" )
                                }
                            }
                        }
                        else
                        {
                            print( "No account numbers returned" )
                        }
                    } catch {
                        print("fetchAccountNumbers - Error parsing JSON: \(error)")
                    }
                }
            }
            else
            {
                print( "Failed to fetch account numbers.   error: \(httpResponse.statusCode). \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))" )
            }
        }.resume()
    }

    /** 
     * fetchAccounts - get the account numbers and balances.
     */
    func fetchAccounts( ) -> [String]
    {
        print( "=== fetchAccounts:  selected: \(self.m_selectedAccountName) ===" )
        var accountUrl : String = "\(schwabWeb)/trader/v1/accounts"
        var symbols : [String] = []
        // !!!!! var accounts : [SapiAccountContent] = []

        // add account number to URL if selected
        if( self.m_selectedAccountName != "All" )
        {
            accountUrl += "/\(self.m_selectedAccountName)"
        }
        accountUrl += "?fields=positions"
        // print( "fetchAccounts - url = \(accountUrl)" )
        var request = URLRequest(url: URL(string: accountUrl )!)

        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.getAccessToken())", forHTTPHeaderField: "Authorization")
        //request.httpBody = String("fields=positions").data(using: .utf8)
        
        //print( "AccessToken: \(self.m_secrets.getAccessToken())" )
        URLSession.shared.dataTask(with: request)
        { data, response, error in
            guard let data = data, ( (error == nil) && ( response != nil ) )
            else
            {
                print( "\n\nERROR fetchAccounts:" )
                print( "error: \( error?.localizedDescription ?? "Unknown error" )" )
                print( "data: \(String(describing: data) )" )
                print( "response: \(String(describing: response))" )
                print( "\n" )
                return
            }
            // successful data fetch
            let httpResponse : HTTPURLResponse = response as! HTTPURLResponse
            if( httpResponse.statusCode == 200 )
            {
                // print( "accounts positions http response:  \(httpResponse.statusCode) " )
                // print( String(data: data, encoding: .utf8) ?? "no data" )
                let decoder = JSONDecoder()
                do
                {
                    self.m_accounts = try decoder.decode( [SapiAccountContent].self, from: data )
                    print( "\n\n\nfetchAccounts parsed \(self.m_accounts.count) accounts\n\n\n" )
//                    // print all account content
//                    for account in self.m_accounts
//                    {
//                        print( "Account dump: \(account.dump())" )
//                    }
                    // copy all symbols from instruments in m_accounts to symbols
                    for account in self.m_accounts
                    {
                        for position in account.securitiesAccount.positions
                        {
                            symbols.append( position?.instrument?.symbol ?? "N/A" )
                            print( "Adding symbol: \(position?.instrument?.symbol ?? "N/A" )" )
                        }
                    }
                }
                catch
                {
                    print( "fetchAccounts - Error parsing JSON: \(error)")
                }
            }
            else
            {
                print( "Failed to fetch account positions.   error: \(httpResponse.statusCode). \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))" )
            }
        }
        .resume()
        for position in symbols
        {
            print( "Checking symbol: \(position )" )
        }
        return  symbols // accounts
    }

}
