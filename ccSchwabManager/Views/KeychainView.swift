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
    let m_schwabClient : SchwabClient // = SchwabClient()

    private var m_secrets: Secrets = Secrets()

    @State private var authenticateButtonUrl: URL = URL( string: "https://localhost" )!
    @State private var authenticateButtonEnabled: Bool = false
    @State private var authenticateButtonTitle: String = "Click to Authorize"


    init( secrets: Secrets )
    {
        m_secrets = secrets
        m_schwabClient = SchwabClient( secrets: m_secrets )
        // m_secrets =  self.keychainManager.readSecrets( prefix: "init/firstPass" ) ?? Secrets()
        self.secretsStr = m_secrets.encodeToString() ?? "init Failed to Encode Secrets to secretsStr"
        // print( "Initializing KeychainView \(m_secrets.getAppId())" )
    }

    var body: some View
    {
        VStack
        {
            TextField( "Secrets:", text: $secretsStr )
                .padding()
                .onAppear()
            {
                // the assignment of secretsStr in init does not appear to populate the textfield...
                self.secretsStr = self.m_secrets.encodeToString() ?? "Failed to Encode Secrets for Display"
                // print( "display secrets \(self.m_secrets.dump())" )
            }
            Button( "Read" )
            {
                let secrets: Secrets = KeychainManager.readSecrets( prefix: "init/firstPass" ) ?? Secrets()
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
                //print( "\(KeychainManager.saveSecrets( secrets: secrets ) ? "Saved" : "Not saved")" )
                //print( "\( (KeychainManager.readSecrets( prefix: "onButtonPress" ) ?? Secrets()).dump() )" )
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
                m_schwabClient.getAuthenticationUrl
                { (result : Result< URL, ErrorCodes>) in
                    switch result
                    {
                    case .success( let url ):
                        //print( "Authentication URL: \(url.absoluteString)" )
                        authenticateButtonEnabled = true
                        authenticateButtonUrl = url
                    case .failure(let error):
                        print("Authentication failed: \(error)")
                    }
                    
                }
            } // Link
        }
        
    }

}




