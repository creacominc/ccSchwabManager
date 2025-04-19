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
    @State var m_schwabClient : SchwabClient

    private var m_secrets: Secrets

    @State private var authorizationButtonUrl: URL = URL( string: "https://localhost" )!
    @State private var authenticateButtonEnabled: Bool = false

    @State private var resultantUrl : String = ""

    //@State private var m_allSymbols : [String] = []
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
                    //self.m_allSymbols =
                    await self.m_schwabClient.fetchAccounts()
                    //print("fetch Account pressed \(m_allSymbols.count)")
//                    for symbol in m_allSymbols {
//                        print("Symbol: \(symbol)")
//                    }
                    //m_enableSymbolList = !m_allSymbols.isEmpty
                    m_enableSymbolList = self.m_schwabClient.hasSymbols()
                }
            }



            HStack
            {
                // picker for allSymbols
                Picker( "All Symbols", selection: $m_selectedSymbol )
                {
                    Text( "Populating with symbols..." )
                    // for every account
                    let accounts : [SapiAccountContent] = self.m_schwabClient.getAccounts()
                    print("Accounts count: \(accounts.count)")
                    ForEach( accounts, id: \.self )
                    { account in
                        // for every symbol in the account
                        ForEach( account.securitiesAccount.positions, id: \.self )
                        { position in
                            Text( "\(account.accountNumber) \(position.instrument.symbol)" )
                        }
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


//    private func getATR( forSymbol: String ) -> Double
//    {
//        var retVal: Double = 0.0
//        
//        return retVal
//    }


}




