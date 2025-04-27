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

    @State private var m_selectedSymbol : String = ""
    @State private var m_enableSymbolList : Bool = false

    @State private var m_atr : Double = 0.0

    @State private var m_gotCode : Bool = false

    init( secrets: inout Secrets )
    {
        m_secrets = secrets
        m_schwabClient = SchwabClient( secrets: &m_secrets )
        updateSecretsString( errorMsg: "init Failed to Encode Secrets to secretsStr" )
    }

    var body: some View
    {
        VStack
        {
            SecretsEditorView(
                secretsStr: $secretsStr,
                onRead: {
                    updateSecretsString( errorMsg: "Failed to Encode Secrets for Read" )
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
                updateSecretsString( errorMsg: "Failed to Encode Secrets for Display" )
                // print( "display secrets \(self.m_secrets.dump())" )
            }
            


            // Authorization View Integration
            AuthorizationView(
                authorizationButtonUrl: $authorizationButtonUrl,
                authenticateButtonEnabled: $authenticateButtonEnabled,
                resultantUrl: $resultantUrl,
                onAuthorize: handleAuthorization
            )
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
                            updateSecretsString( errorMsg: "Failed to Encode Secrets with Access Token" )
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
                    updateSecretsString( errorMsg: "Failed to Encode Secrets with Account Numbers" )
                }
            }

            Button("Fetch Accounts") {
                Task {
                    await self.m_schwabClient.fetchAccounts()
                    m_enableSymbolList = self.m_schwabClient.hasSymbols()
                }
            }

            HStack
            {
                // picker for allSymbols
                Picker("All Symbols", selection: $m_selectedSymbol) {
                    ForEach(getSymbols(from: self.m_schwabClient.getAccounts()), id: \.self) { symbol in
                        Text(symbol)
                    }
                }
                .pickerStyle( .menu )
                .padding()
                .disabled( !m_enableSymbolList )
                .onChange(of: m_selectedSymbol)
                { newValue in
                    Task
                    {
                        m_atr = await self.m_schwabClient.computeATR(symbol: newValue)
                    }
                }

                Text( "Symbol \(m_selectedSymbol)" )
                    .padding()
                Text( "ATR: \(m_atr)" )
            }
            .padding()


//            // add button to test decompressGzipData using response_1745203291125.json.gz from the Resourses folder
//            Button(  "Test Gunzip" )
//            {
//                print("Test Gunzip pressed")
//                let fileManager = FileManager.default
//                let bundlePath = Bundle.main.bundlePath
//                let resourcesPath = (bundlePath as NSString).appendingPathComponent("Contents/Resources")
//                do {
//                    let data = try Data(contentsOf: URL(fileURLWithPath: resourcesPath + "/response_1745203291125.json.gz"))
//                    // print size of data
//                    print( "Data Size: \(data.count)" )
//                    let decompressedData : Data? = decompressGzip(data: data)
//                    let uncompressedString : String? = String(data: decompressedData ?? Data(), encoding: .utf8)
//                    // print the uncompressed data as a string
//                    if( nil == uncompressedString )
//                    {
//                        print( "No Uncompressed Data" )
//                    }
//                    else
//                    {
//                        print( "Uncompressed Data: \(uncompressedString ?? "No Data" )" )
//                    }
//                }
//                catch
//                {
//                    print("Error: Failed to decompress. \(error)")
//                }
//            }


        }
    }

    func getSymbols(from accounts: [SapiAccountContent]) -> [String] {
        var symbols: [String] = []
        for account in accounts {
            for position in account.securitiesAccount.positions {
                symbols.append( position?.instrument?.symbol ?? "No Position" )
            }
        }
        return symbols.sorted(by: <)
    }

    func handleAuthorization(url: String) {
        self.m_schwabClient.extractCodeFromURL(from: url) { (result: Result<Void, ErrorCodes>) in
            switch result {
            case .success():
                print("Got code.")
                updateSecretsString( errorMsg: "Failed to Encode Secrets with Code" )
                m_gotCode = (!self.m_secrets.getCode().isEmpty && !self.m_secrets.getSession().isEmpty)
            case .failure(let error):
                print("extractCodeFromURL failed - error: \(error)")
            }
        }
    }

    func updateSecretsString( errorMsg : String ) {
        self.secretsStr = self.m_secrets.encodeToString() ?? errorMsg
    }




//    private func getATR( forSymbol: String ) -> Double
//    {
//        var retVal: Double = 0.0
//        
//        return retVal
//    }


}




