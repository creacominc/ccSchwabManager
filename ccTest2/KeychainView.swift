//
//  KeychainView.swift
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Security


struct KeychainView: View
{
    @State var token: String = "Default ccSchwaabManager Token"
    @State var pressed: Bool = false
    @State var firstPass: Bool = true
    let keychainManager = KeychainManager()


    init()
    {
        if( firstPass )
        {
            self.token = keychainManager.readToken( prefix: "init/firstPass" ) ?? "unset"
            firstPass = false
        }
    }

    var body: some View
    {
        VStack
        {
            TextField( "Token:", text: $token )
                .padding()
            Button( "Read" )
            {
                self.token = keychainManager.readToken( prefix: "init/firstPass" ) ?? "still naught"
            }
            Button( "Test" )
            {
                print( "\(keychainManager.saveToken(token: "\(token)") ? "Saved" : "Not saved")" )
                print( "\(keychainManager.readToken( prefix: "onButtonPress" ) ?? "Not found")" )
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



class KeychainManager
{
    var credential: Credentials = Credentials(username: "", password: "")
    
    func saveToken(token: String) -> Bool
    {
        print( "Saving token: \(token)" )
        credential.username = "ccSchwabManager"
        credential.password = token

        let tokenData = token.data(using: .utf8)
        if( nil == tokenData )
        {
            print( "Error converting token to data." )
            return false
        }
        else
        {
            print( "Token data length: \(tokenData!.count)" )
        }
        let keychainItem = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credential.username,
            kSecAttrService as String: "ccSchwabManager",
            kSecAttrSynchronizable as String:  kCFBooleanTrue!,
            kSecValueData as String: tokenData!
        ] as CFDictionary
        let status = SecItemAdd(keychainItem, nil)
        let errorString : String = SecCopyErrorMessageString( status, nil )! as String
        print( "Initial status: \(status),  \(errorString)" )
        // update if it exists
        if( errSecDuplicateItem == status )
        {
            let attributes: [String: Any] = [ kSecValueData as String: tokenData! ]
            let status = SecItemUpdate( keychainItem as CFDictionary, attributes as CFDictionary)
            let errorString : String = SecCopyErrorMessageString( status, nil )! as String
            print( "update status: \(status),  \(errorString)" )
        }
        return status == errSecSuccess
    }

    func readToken(  prefix: String ) -> String?
    {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credential.username,
            kSecAttrService as String: "ccSchwabManager",
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as
            CFDictionary, &result)
        let errorString : String = SecCopyErrorMessageString( status, nil )! as String
        print( "\(prefix) - readToken status: \(status),  \(errorString)" )

        if( status == errSecSuccess )
        {
            let tokenData = result as? Data
            if( nil == tokenData )
            {
                print( "\(prefix) - No token data found" )
            }
            else
            {
                let token = String(data:  tokenData!, encoding: .utf8)
                print( "\(prefix) - token: \(token ?? "Not found")" )

                let keyValue = NSString(data: tokenData!,
                                        encoding: String.Encoding.utf8.rawValue) as? String
                print( "\(prefix)  -  keyValue: \(keyValue ?? "Not found")" )

                return token
            }
        }

        return nil

    }
    
    
}



#Preview {
    KeychainView()
}
