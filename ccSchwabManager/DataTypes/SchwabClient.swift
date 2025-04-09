
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
        - getAuthenticationUrl : Executes the completion with the URL for logging into and authenticating the connection.
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

    init(  )
    {
        self.m_secrets = Secrets()
        print( "SchwabClient init" )
//        self.m_secrets.loadSecrets()
//        print( "SchwabClient init loaded secrets: \(dump())" )
    }

    public func getSecrets() -> Secrets
    {
        return self.m_secrets
    }

    public func setSecrets( secrets: Secrets )
    {
        print( "client setting secrets to: \(secrets.dump())")
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
     * getAuthenticationUrl : Executes the completion with the URL for logging into and authenticating the connection.
     */
    func getAuthenticationUrl(completion: @escaping (Result<URL, ErrorCodes>) -> Void)
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
    
    /**
     * getAccessToken : given the URL returned by the authentication process, extract the code and get the access token.
     */
    func getAccessToken( from url: String, completion: @escaping (Result<Void, ErrorCodes>) -> Void )
    {
        print( "getAccessToken from \(url)")
        // extract the code and session from the URL
        let urlComponents = URLComponents(string: url )!
        let queryItems = urlComponents.queryItems
        
        self.m_secrets.setCode( queryItems?.first(where: { $0.name == "code" })?.value ?? "" )
        self.m_secrets.setSession( queryItems?.first(where: { $0.name == "session" })?.value ?? "" )

        print( "getAccessToken upated secrets to \(self.m_secrets.dump())" )

        // Access Token Request
        let url = URL( string: "\(accessTokenWeb)" )!
                print( "accessTokenUrl: \(url)" )
        var accessTokenRequest = URLRequest( url: url )
        accessTokenRequest.httpMethod = "POST"
        // headers
        let authStringUnencoded = String("\( self.m_secrets.getAppId() ):\( self.m_secrets.getAppSecret() )")
        print( "authString: \(authStringUnencoded)" )
        let authStringEncoded = authStringUnencoded.data(using: .utf8)!.base64EncodedString()
        accessTokenRequest.setValue( "Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization" )
        accessTokenRequest.setValue( "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type" )
        // body
        accessTokenRequest.httpBody = String("grant_type=authorization_code&code=\( self.m_secrets.getCode() )&redirect_uri=\( self.m_secrets.getRedirectUrl() )").data(using: .utf8)!
        print( "Posting access token request:  \(accessTokenRequest)" )
        
        URLSession.shared.dataTask(with: accessTokenRequest)
        { data, response, error in
            guard let data = data, error == nil else {
                print( "Error: \( error?.localizedDescription ?? "Unknown error" )" )
                completion(.failure(ErrorCodes.notAuthenticated))
                return
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            {
                if let tokenDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                {
                    self.m_secrets.setAccessToken( tokenDict["access_token"] as? String ?? "" )
                    self.m_secrets.setRefreshToken( tokenDict["refresh_token"] as? String ?? "" )
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
                print( "Failed to get token.  HTTPS response: \(String(describing: response))" )
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
        print( "In fetchAccountNumbers.  client = \(dump())" )
        var request = URLRequest(url: URL(string: "\(schwabWeb)/trader/v1/accounts/accountNumbers")!)
        request.setValue("Bearer \(self.m_secrets.getAccessToken())", forHTTPHeaderField: "Authorization")
        print( "AccessToken: \(self.m_secrets.getAccessToken())" )
        URLSession.shared.dataTask(with: request)
        { data, response, error in
            guard let data = data, error == nil else
            {
                print( "error: \(String(describing: error))" )
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            {
                do
                {
                    let decoder = JSONDecoder()
                    do
                    {
                        let accountNumberHashes = try decoder.decode([SapiAccountNumberHash].self, from: data)
                        if( !accountNumberHashes.isEmpty )
                        {
                            DispatchQueue.main.async
                            {
                                self.m_secrets.setAccountNumberHash( accountNumberHashes )
//                                self.m_secrets.storeSecrets()
                            }
                        }
                    } catch {
                        print("Error parsing JSON: \(error)")
                    }
                }
            }
            else
            {
                print( "Failed to fetch account numbers" )
            }
        }.resume()
    }

    /** 
     * fetchAccounts - get the account numbers and balances.
     */
    func fetchAccounts() -> Void // !!!!! [SapiAccountContent]
    {
        print( "=== fetchAccounts:  selected: \(self.m_selectedAccountName) ===" )
        var accountUrl : String = "\(schwabWeb)/trader/v1/accounts"
        // !!!!! var accounts : [SapiAccountContent] = []

        // add account number to URL if selected
        if( self.m_selectedAccountName != "All" )
        {
            accountUrl += "/\(self.m_selectedAccountName)"
        }
        accountUrl += "?fields=positions"
        print( "fetchAccounts - url = \(accountUrl)" )
        var request = URLRequest(url: URL(string: accountUrl )!)

        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.getAccessToken())", forHTTPHeaderField: "Authorization")
        //request.httpBody = String("fields=positions").data(using: .utf8)
        
        //print( "AccessToken: \(self.m_secrets.getAccessToken())" )
        URLSession.shared.dataTask(with: request)
        { data, response, error in
            guard let data = data, error == nil else
            {
                print( "\n\nERROR fetchAccounts:" )
                print( "error: \(String(describing: error))" )
                print( "data: \(String(describing: data) ?? "no data")" )
                print( "response: \(String(describing: response))" )
                print( "\n" )
                return
            }
            // successful data fetch
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            {
                print( "accounts positions http response:  \(httpResponse.statusCode) " )
                print( String(data: data, encoding: .utf8) ?? "no data" )
                let decoder = JSONDecoder()
                do
                {
                    self.m_accounts = try decoder.decode([SapiAccountContent].self, from: data)
                    print( "\n\n\nfetchAccounts parsed \(self.m_accounts.count) accounts\n\n\n" )
                }
                catch
                {
                    print( "Error parsing JSON: \(error)")
                }
            }
            else
            {
                print( "Failed to get accounts positions.  HTTPS response: \(String(describing: response))" )
            }
        }
        .resume()
        return  // accounts
    }

}

//import SwiftUI
//
//#Preview
//{
//    struct myView: View
//    {
//        @Binding var schwabClient : SchwabClient
//
//        init( schwabClient: Binding<SchwabClient> )
//        {
//            self._schwabClient = schwabClient
//        }
//
//        var body: some View
//        {
//            Text("SchwabClient Preview")
//                .onAppear()
//            {
//                print( "onAppear" )
//            }
//        }
//
//
//    }
//
//
//    @Previewable @State  var schwabClient : SchwabClient = SchwabClient()
//    var accountNumberHash : [SapiAccountNumberHash] = [
//                SapiAccountNumberHash( accountNumber: "1234567890", hasValue: "1234567890" ),
//                SapiAccountNumberHash(accountNumber: "1234567890", hasValue: "12345612345" )
//    ]
//    schwabClient.getSecrets().setAccountNumberHash( accountNumberHash )
//    return myView( schwabClient: $schwabClient )
//}
