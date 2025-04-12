
//import SwiftUI
import Foundation
//import Security

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif


struct KeychainManager
{

    static let userName : String =  "ccSchwabManager"

    static func saveSecrets( secrets: Secrets? ) -> Bool
    {
        if( nil == secrets )
        {
            print( "No secrets to save." )
            return false
        }

        // print( "Saving secrets: \(secrets!.dump())" )
        let password : String = secrets!.encodeToString() ?? "Error encoding Secrete"

        let secretsData = password.data(using: .utf8)
        if( nil == secretsData )
        {
            print( "Error converting secrets to data." )
            return false
        }
        else
        {
            print( "Secrets data length: \(secretsData!.count)" )
        }
        let keychainItem = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userName,
            kSecAttrService as String: userName,
            kSecAttrSynchronizable as String:  kCFBooleanTrue!,
            kSecValueData as String: secretsData!
        ] as CFDictionary
        var status = SecItemAdd(keychainItem, nil)
        let errorString : String = SecCopyErrorMessageString( status, nil )! as String
        print( "Initial status: \(status),  \(errorString)" )
        // update if it exists
        if( errSecDuplicateItem == status )
        {
            let attributes: [String: Any] = [ kSecValueData as String: secretsData! ]
            status = SecItemUpdate( keychainItem as CFDictionary, attributes as CFDictionary)
            let errorString : String = SecCopyErrorMessageString( status, nil )! as String
            print( "update status: \(status),  \(errorString)" )
        }
        return status == errSecSuccess
    }

    static func readSecrets(  prefix: String ) -> Secrets?
    {
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
                // String(data:  secretsData!, encoding: .utf8)
                //print( "\(prefix) - secrets: \(secrets?.dump() ?? "Not found")" )

                let keyValue = NSString(data: secretsData!,
                                        encoding: String.Encoding.utf8.rawValue) as? String
                //print( "\(prefix)  -  keyValue: \(keyValue ?? "Not found")" )

                return secrets
            }
        }
        else
        {
            let errorString : String = SecCopyErrorMessageString( status, nil )! as String
            print( "\(prefix) - readSecrets status: \(status),  \(errorString)" )
        }

        return nil

    }
    
    
}


