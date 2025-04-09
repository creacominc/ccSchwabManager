//
//  KeychainView.swift
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import Security


struct KeychainView: View
{
    @State var secretsStr: String = Secrets().encodeToString() ?? "Failed to Encode Secrets"
    @State var pressed: Bool = false
    @State var firstPass: Bool = true
    let keychainManager : KeychainManager = KeychainManager()
    let schwabClient : SchwabClient = SchwabClient()

    private var m_secrets: Secrets = Secrets()

    @State private var authenticateButtonUrl: URL = URL( string: "https://localhost" )!
    @State private var authenticateButtonEnabled: Bool = false
    @State private var authenticateButtonTitle: String = "Click to Authorize"
    
    
    var body: some View
    {
        VStack
        {
            TextField( "Secrets:", text: $secretsStr )
                .padding()
                .onAppear()
            {
                let secrets: Secrets =  self.keychainManager.readSecrets( prefix: "init/firstPass" ) ?? Secrets()
                self.secretsStr = secrets.encodeToString() ?? "Failed to Encode Secrets for Display"
                // print( "display secrets \(self.secretsStr)" )
            }
            Button( "Read" )
            {
                let secrets: Secrets = keychainManager.readSecrets( prefix: "init/firstPass" ) ?? Secrets()
                self.secretsStr = secrets.encodeToString() ?? "Failed to Encode Secrets for Read"
                // print( "read secrets: \(self.secretsStr)" )
            }
            Button( "Test" )
            {
                
                var secrets: Secrets?
                do
                {
                    secrets = try JSONDecoder().decode( Secrets.self, from: self.secretsStr.data( using: .utf8 )!)
                }
                catch
                {
                    print( "Error decoding JSON: \(error)" )
                    return
                }
                print( "\(keychainManager.saveSecrets( secrets: secrets ) ? "Saved" : "Not saved")" )
                print( "\( (keychainManager.readSecrets( prefix: "onButtonPress" ) ?? Secrets()).dump() )" )
                pressed = true
                
            }
            .buttonStyle( .borderedProminent )
            
            // authorize
            Link( authenticateButtonTitle
                  , destination: authenticateButtonUrl )
            .disabled( !authenticateButtonEnabled )
            .opacity( !authenticateButtonEnabled ? 0 : 1 )
            .onAppear
            {
                schwabClient.getAuthenticationUrl
                { (result : Result< URL, ErrorCodes>) in
                    switch result
                    {
                    case .success( let url ):
                        print( "Authentication URL: \(url.absoluteString)" )
                        authenticateButtonEnabled = true
                        authenticateButtonUrl = url
                    case .failure(let error):
                        print("Authentication failed: \(error)")
                    }
                    
                }
            } // Link
        }
        
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

}




struct Credentials {
    var username: String
    var password: String
}

enum KeychainError: Error {
    case noPassword
    case unexpectedPasswordData
    case unhandledError(status: OSStatus)
}





#Preview {
    KeychainView()
}
