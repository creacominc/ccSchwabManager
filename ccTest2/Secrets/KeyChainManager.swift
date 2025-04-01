
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

    func saveSecrets( secrets: Secrets ) -> Bool
    {
        print( "Saving token: \(secrets)" )
        //credential.password = secrets.encode( to:  )

        let tokenData = credential.password.data(using: .utf8)
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
        else
        {
            let errorString : String = SecCopyErrorMessageString( status, nil )! as String
            print( "\(prefix) - readToken status: \(status),  \(errorString)" )
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
