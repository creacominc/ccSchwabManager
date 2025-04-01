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
    @State var token: String = "Default ccSchwaabManager Token"
    @State var pressed: Bool = false
    @State var firstPass: Bool = true
    let keychainManager = KeychainManager()
    var secret: Secrets = Secrets()


    var body: some View
    {
        VStack
        {
            TextField( "Token:", text: $token )
                .padding()
                .onAppear()
            {
                self.token = keychainManager.readToken( prefix: "init/firstPass" ) ?? "unset"
                print( "display token \(self.token)" )
            }
            Button( "Read" )
            {
                self.token = keychainManager.readToken( prefix: "init/firstPass" ) ?? "still naught"
                print( "read token \(self.token)" )
            }
            Button( "Test" )
            {
                print( "\(keychainManager.saveSecrets(token: "\(token)") ? "Saved" : "Not saved")" )
                print( "\(keychainManager.readToken( prefix: "onButtonPress" ) ?? "Not found")" )
                pressed = true
                self.secret.setAppId(<#T##appId: String##String#>)
            }
            .buttonStyle( .borderedProminent )
        }

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
