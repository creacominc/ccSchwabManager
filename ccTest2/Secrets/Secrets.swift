
import Foundation
import CryptoKit
import SwiftUI

class Secrets: Codable
{

    private var appId               : String
    private var appSecret           : String
    private var redirectUrl         : String
    private var code                : String
    private var session             : String
    private var accessToken         : String
    private var refreshToken        : String
    //private var acountNumberHash    : [SapiAccountNumberHash]

    init()
    {
        appId               = ""
        appSecret           = ""
        redirectUrl         = ""
        code                = ""
        session             = ""
        accessToken         = ""
        refreshToken        = ""
        //acountNumberHash    = []
    }

    public func encodeToString() -> String? 
    {
        do 
        {
            let jsonData = try JSONEncoder().encode(self)
            return String(data: jsonData, encoding: .utf8)
        }
        catch 
        {
            print("Error encoding Secrets object to JSON string: \(error)")
            return nil
        }
    }

    public func dump() -> String
    {
        var retStr : String =
            "Secret = appId: \(self.appId),  appSecret: \(self.appSecret),  redirectUrl: \(self.redirectUrl), code: \(self.code),  session: \(self.session),  accessToken: \(self.accessToken),  refreshToken: \(self.refreshToken),  acountNumberHash: ["
//        self.acountNumberHash.forEach
//        { hash in
//            retStr += "\n\t\t\t\t\t\t\t\(hash.dump())"
//        }
        retStr += "\n\t\t\t\t\t\t]"
        return retStr
    }

    public func getAppId() -> String
    {
        appId
    }

    public func getAppSecret() -> String
    {
        appSecret
    }

    public func getRedirectUrl() -> String
    {
        redirectUrl
    }
    
    public func getCode() -> String
    {
        code
    }

    public func getSession() -> String
    {
        session
    }

    public func getAccessToken() -> String
    {
        accessToken
    }

    public func getRefreshToken() -> String
    {
        refreshToken
    }

//    public func getAccountNumberHash() -> [SapiAccountNumberHash]
//    {
//        acountNumberHash
//    }


    public func setAppId(_ appId: String)
    {
        self.appId = appId
    }

    public func setAppSecret(_ appSecret: String)
    {
        self.appSecret = appSecret
    }

    public func setRedirectUrl(_ redirectUrl: String)
    {
        self.redirectUrl = redirectUrl
    }
    
    public func setCode(_ code: String)
    {
        self.code = code
    }

    public func setSession(_ session: String)
    {
        self.session = session
    }

    public func setAccessToken(_ accessToken: String)
    {
        self.accessToken = accessToken
    }
    
    public func setRefreshToken(_ refreshToken: String)
    {
        self.refreshToken = refreshToken
    }

//    public func clearAccountNumberHashes()
//    {
//        acountNumberHash.removeAll()
//    }
//
//    public func setAccountNumberHash(_ acountNumberHash: [SapiAccountNumberHash] )
//    {
//        self.acountNumberHash = acountNumberHash
//    }
//
//    public func getAccountNumbers() -> [String]
//    {
//        return acountNumberHash.map( { $0.getAccountNumber() } )
//    }
//    
    
    func fromSecrets( from secrets: Secrets )
    {
        self.appId               = secrets.appId
        self.appSecret           = secrets.appSecret
        self.redirectUrl         = secrets.redirectUrl
        self.code                = secrets.code
        self.session             = secrets.session
        self.accessToken         = secrets.accessToken
        self.refreshToken        = secrets.refreshToken
        //self.acountNumberHash    = secrets.acountNumberHash
    }

    func loadSecrets()
    {
        do
        {
            let data = KeyChain.load()
            if( data == nil )
            {
                print( "No secret loaded from keychain." )
            }
            else
            {
                fromSecrets( from: try JSONDecoder().decode( Secrets.self, from: data ?? Data() ) )
                print( "loaded from keychain: \(dump())" )
            }
        }
        catch
        {
            print("loadSecrets: Error decoding JSON: \(error)")
        }
    }


    func storeSecrets()
    {
        print( "storeSecrets: \(dump())" )
        do
        {
            var status : OSStatus = noErr
            // delete the current data
            var data = KeyChain.load()
            if( data != nil )
            {
                status = KeyChain.delete( data: data! )
                print( "storeSecrets deleted the prior secret: \(String(describing: data.debugDescription) )" )
            }
            data  = try JSONEncoder().encode( self )
            if( data != nil )
            {
                status  =  KeyChain.save(  data: data! )
                print( "save returned status of \(status)" )
            }
        }
        catch
        {
            print("Error saving JSON: \(error)")
        }
    }


}


