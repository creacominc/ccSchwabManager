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
    let m_schwabClient : SchwabClient

    private var m_secrets: Secrets

    @State private var authorizationButtonUrl: URL = URL( string: "https://localhost" )!
    @State private var authenticateButtonEnabled: Bool = false
//    @State private var authorizationButtonTitle: String = "Click to Authorize"

    @State private var resultantUrl : String = ""
//    @State private var extractCodeEnabled : Bool = false

    @State private var m_allSymbols : [String] = []
    @State private var m_selectedSymbol : String = ""
    @State private var m_enableSymbolList : Bool = false

    @State private var m_atr : Double = 0.0

    @State private var m_gotCode : Bool = false

    init( secrets: inout Secrets )
    {
        m_secrets = secrets
        m_schwabClient = SchwabClient( secrets: &m_secrets )
        self.secretsStr = m_secrets.encodeToString() ?? "init Failed to Encode Secrets to secretsStr"
    }

    var body: some View
    {
        VStack
        {
            SecretsEditorView(
                secretsStr: $secretsStr,
                onRead: {
                    let secrets: Secrets = KeychainManager.readSecrets(prefix: "init/firstPass") ?? Secrets()
                    self.secretsStr = secrets.encodeToString() ?? "Failed to Encode Secrets for Read"
                },
                onSave: {
                    var secrets: Secrets
                    do {
                        Secrets.removeSmartQuotes(secretStr: &self.secretsStr)
                        secrets = try JSONDecoder().decode(
                            Secrets.self,
                            from: self.secretsStr.data(using: .utf8)!
                        )
                    } catch {
                        print("Error decoding JSON: \(error)")
                        return
                    }
                    print("\(KeychainManager.saveSecrets(secrets: &secrets) ? "Saved" : "Not saved")")
                    pressed = true
                }
            )
            .onAppear()
            {
                // the assignment of secretsStr in init does not appear to populate the textfield...
                self.secretsStr = self.m_secrets.encodeToString() ?? "Failed to Encode Secrets for Display"
                // print( "display secrets \(self.m_secrets.dump())" )
            }
            


            // Authorization View Integration
            AuthorizationView(
                authorizationButtonUrl: $authorizationButtonUrl,
                authenticateButtonEnabled: $authenticateButtonEnabled,
                resultantUrl: $resultantUrl
            ) { url in
                self.m_schwabClient.extractCodeFromURL(from: url) { (result: Result<Void, ErrorCodes>) in
                    switch result {
                    case .success():
                        print("Got code.")
                        self.secretsStr = self.m_secrets.encodeToString() ?? "Failed to Encode Secrets with Code"
                        m_gotCode = (!self.m_secrets.getCode( ).isEmpty && !self.m_secrets.getSession().isEmpty)
                    case .failure(let error):
                        print("extractCodeFromURL failed - error: \(error)")
                    }
                }
            }
            .onAppear {
                m_schwabClient.getAuthorizationUrl { (result: Result<URL, ErrorCodes>) in
                    switch result {
                    case .success(let url):
                        authenticateButtonEnabled = true
                        authorizationButtonUrl = url
                    case .failure(let error):
                        print("Authentication failed: \(error)")
                    }
                }
            }
//            .onExtractCode
//            {
//                print("Extract Code Called")
//            }


//            // authorization link
//            Link( authorizationButtonTitle
//                  , destination: authorizationButtonUrl )
//            .disabled( !authenticateButtonEnabled )
//            .opacity( !authenticateButtonEnabled ? 0 : 1 )
//            .onAppear
//            {
//                m_schwabClient.getAuthorizationUrl
//                { (result : Result< URL, ErrorCodes>) in
//                    switch result
//                    {
//                    case .success( let url ):
//                        authenticateButtonEnabled = true
//                        authorizationButtonUrl = url
//                    case .failure(let error):
//                        print("Authentication failed: \(error)")
//                    }
//                    
//                }
//            } // Link



//            // Authorization TextField
//            TextField( "After authorization, paste URL here.", text: $resultantUrl )
//                .autocorrectionDisabled()
//                .selectionDisabled( false )
//                .onChange( of: resultantUrl )
//            {
//                print( "OnChange URL: \( resultantUrl )" )
//                extractCodeEnabled = true
//            }
//            .padding( 10 )
//
//            // Authorization Button
//            Button( "Extract Code From URL" )
//            {
//                self.m_schwabClient.extractCodeFromURL( from: resultantUrl )
//                { ( result : Result< Void, ErrorCodes > ) in
//                    switch result
//                    {
//                    case .success():
//                        print( "Got code." )
//                        self.secretsStr = self.m_secrets.encodeToString() ?? "Failed to Encode Secrets with Code"
//                    case .failure(let error):
//                        print("extractCodeFromURL  failed - error: \(error)")
//                        print("extractCodeFromURL  failed - localized error: \(error.localizedDescription)")
//                        extractCodeEnabled = false
//                    }
//                }
//            }
//            .disabled( !extractCodeEnabled )
//            .buttonStyle( .bordered )

            Button( "Get Access Token" )
            {
                self.m_schwabClient.getAccessToken( )
                { (result : Result< Void, ErrorCodes>) in
                    switch result
                    {
                    case .success():
                        Task
                        {
                            await self.m_schwabClient.fetchAccountNumbers()
                            self.secretsStr = self.m_secrets.encodeToString() ?? "Failed to Encode Secrets with Access Token"
                        }
                    case .failure(let error):
                        print("getAccessToken authorization failed - error: \(error)")
                        print("getAccessToken localized error: \(error.localizedDescription)")
                    }
                }
            } // Get Access Token Button
            .disabled( m_gotCode == false )
            .buttonStyle( .bordered )


            Button("Fetch Account Numbers") {
                Task {
                    await self.m_schwabClient.fetchAccountNumbers()
                    self.secretsStr = self.m_secrets.encodeToString() ?? "Failed to Encode Secrets with Account Numbers"
                }
            }

            Button("Fetch Accounts") {
                Task {
                    self.m_allSymbols = await self.m_schwabClient.fetchAccounts()
                    print("fetch Account pressed \(m_allSymbols.count)")
//                    for symbol in m_allSymbols {
//                        print("Symbol: \(symbol)")
//                    }
                    m_enableSymbolList = !m_allSymbols.isEmpty
                }
            }



            HStack
            {
                // picker for allSymbols
                Picker( "All Symbols", selection: $m_selectedSymbol )
                {
                    Text( "Populating with \(m_allSymbols.count) symbols..." )
                    ForEach( m_allSymbols.sorted(), id: \.self )
                    { symbol in
                        Text( symbol )
                    }
                }
                .pickerStyle( .menu )
                .padding()
                .disabled( !m_enableSymbolList )
                
                Text( "ATR for \(m_selectedSymbol)" )
                    .padding()
            }
            .padding()



        }
        
    }


    private func getATR( forSymbol: String ) -> Double
    {
        var retVal: Double = 0.0
        
        return retVal
    }


}




