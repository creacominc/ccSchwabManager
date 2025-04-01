
//import SwiftUI
import Foundation
//import Security

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class KeychainManager
{
    var credential: Credentials = Credentials(username: "ccSchwabManager", password: "")

    func saveSecrets( secrets: Secrets? ) -> Bool
    {
        if( nil == secrets )
        {
            print( "No secrets to save." )
            return false
        }

        print( "Saving secrets: \(secrets!.dump())" )
        credential.password = secrets!.encodeToString() ?? "Error encoding Secrete"

        let secretsData = credential.password.data(using: .utf8)
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
            kSecAttrAccount as String: credential.username,
            kSecAttrService as String: "ccSchwabManager",
            kSecAttrSynchronizable as String:  kCFBooleanTrue!,
            kSecValueData as String: secretsData!
        ] as CFDictionary
        let status = SecItemAdd(keychainItem, nil)
        let errorString : String = SecCopyErrorMessageString( status, nil )! as String
        print( "Initial status: \(status),  \(errorString)" )
        // update if it exists
        if( errSecDuplicateItem == status )
        {
            let attributes: [String: Any] = [ kSecValueData as String: secretsData! ]
            let status = SecItemUpdate( keychainItem as CFDictionary, attributes as CFDictionary)
            let errorString : String = SecCopyErrorMessageString( status, nil )! as String
            print( "update status: \(status),  \(errorString)" )
        }
        return status == errSecSuccess
    }

    func readSecrets(  prefix: String ) -> Secrets?
    {
        print( "username: \(credential.username)" )

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
                    print("Error parsing JSON: \(error)")
                    return nil
                }
                // String(data:  secretsData!, encoding: .utf8)
                print( "\(prefix) - secrets: \(secrets?.dump() ?? "Not found")" )

                let keyValue = NSString(data: secretsData!,
                                        encoding: String.Encoding.utf8.rawValue) as? String
                print( "\(prefix)  -  keyValue: \(keyValue ?? "Not found")" )

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




//class KeyChain
//{
//
//    private static let serviceName: String = "com.creacominc.ccSchwabManager"
//    private static let appSecretKey: String = "ccSchwabManager"
//
//
//    class func save( data: Data) -> OSStatus
//    {
//        let query = [
//            kSecClass as String       : kSecClassGenericPassword as String,
//            kSecAttrAccount as String : appSecretKey,
//            kSecValueData as String   : data ] as [String : Any]
//        return SecItemAdd(query as CFDictionary, nil)
//    }
//
//    class func load() -> Data?
//    {
//        let query = [
//            kSecClass as String       : kSecClassGenericPassword as String,
//            kSecAttrAccount as String : appSecretKey,
//            kSecReturnData as String  : kCFBooleanTrue!,
//            kSecMatchLimit as String  : kSecMatchLimitOne ] as [String : Any]
//        var dataTypeRef: AnyObject? = nil
//        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
//        if status == noErr {
//            // print( "keyChain got data: \(dataTypeRef.debugDescription)")
//            return dataTypeRef as! Data?
//        } else {
//            return nil
//        }
//    }
//
//    class func delete(data: Data) -> OSStatus
//    {
//        let query = [
//            kSecClass as String       : kSecClassGenericPassword as String,
//            kSecAttrAccount as String : appSecretKey,
//            kSecValueData as String   : data ] as [String : Any]
//        let status: OSStatus = SecItemDelete(query as CFDictionary)
//        if status == noErr
//        {
//            print( "keyChain deleted ok" )
//        }
//        return status
//    }
//
//    
//}
//
//extension Data
//{
//    init<T>(from value: T)
//    {
//        var value = value
//        self.init( buffer: UnsafeBufferPointer(start: &value, count: 1) )
//    }
//
//    func to<T>(type: T.Type) -> T
//    {
//        return self.withUnsafeBytes { $0.load(as: T.self) }
//    }
//}
