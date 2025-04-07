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
    let keychainManager = KeychainManager()
    //var secrets: Secrets = Secrets()


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
