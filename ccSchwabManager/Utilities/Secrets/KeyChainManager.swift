
//import SwiftUI
import Foundation
//import Security

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


@MainActor
struct KeychainManager
{
    static let userName : String =  "ccSchwabManager"

    static func saveSecrets( secrets: inout Secrets ) -> Bool
    {
        guard let password = secrets.encodeToString(),
              let secretsData = password.data(using: .utf8) else {
            print( "Error converting secrets to data." )
            return false
        }
        let keychainItem = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userName,
            kSecAttrService as String: userName,
            kSecAttrSynchronizable as String:  kCFBooleanTrue!,
            kSecValueData as String: secretsData
        ] as CFDictionary
        var status = SecItemAdd(keychainItem, nil)
        // update if it exists
        if( errSecDuplicateItem == status )
        {
            let attributes: [String: Any] = [ kSecValueData as String: secretsData ]
            status = SecItemUpdate( keychainItem as CFDictionary, attributes as CFDictionary)
        }
        if status != errSecSuccess {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            print("Unable to save credentials (Keychain status \(status)): \(message)")
        }
        return status == errSecSuccess
    }

    static func readSecrets(  prefix: String ) -> Secrets?
    {
        print( "\(prefix) - Reading secrets" )
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userName,
            kSecAttrService as String: userName,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as
            CFDictionary, &result)

        if( status == errSecSuccess )
        {
            let secretsData = result as? Data
            if( nil == secretsData )
            {
                print( "\(prefix) - No token data found" )
            }
            else
            {
                let secrets : Secrets?
                do
                {
                    secrets = try JSONDecoder().decode(Secrets.self, from: secretsData!)
                }
                catch
                {
                    print("readSecrets - \(prefix) - Error parsing JSON: \(error)")
                    return nil
                }

                return secrets
            }
        }
        else if status != errSecItemNotFound {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            print("\(prefix) - Unable to read credentials (Keychain status \(status)): \(message)")
        }

        return nil

    }
    
    
}
