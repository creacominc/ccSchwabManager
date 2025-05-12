
import Foundation
import CryptoKit
import SwiftUI

class Secrets: Codable, Identifiable
{
    public var appId               : String
    public var appSecret           : String
    public var redirectUrl         : String
    public var code                : String
    public var session             : String
    public var accessToken         : String
    public var refreshToken        : String
    public var acountNumberHash    : [AccountNumberHash]

    enum CodingKeys: String, CodingKey {
        case appId              = "appId"
        case appSecret           = "appSecret"
        case redirectUrl         = "redirectUrl"
        case code               = "code"
        case session             = "session"
        case accessToken        = "accessToken"
        case refreshToken        = "refreshToken"
        case acountNumberHash    = "acountNumberHash"
    }

    public init()
    {
        self.appId               = ""
        self.appSecret           = ""
        self.redirectUrl         = ""
        self.code                = ""
        self.session             = ""
        self.accessToken         = ""
        self.refreshToken        = ""
        self.acountNumberHash  = []
    }

    public init(appId: String, appSecret: String,
                redirectUrl: String, code: String,
                session: String, accessToken: String,
                refreshToken: String,
                acountNumberHash: [AccountNumberHash])
    {
        self.appId = appId
        self.appSecret = appSecret
        self.redirectUrl = redirectUrl
        self.code = code
        self.session = session
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.acountNumberHash = acountNumberHash
    }



//    init( copyFrom source: inout Secrets )
//    {
//        self.appId          = source.appId
//        self.appSecret      = source.appSecret
//        self.redirectUrl    = source.redirectUrl
//        self.code           = source.code
//        self.session        = source.session
//        self.accessToken    = source.accessToken
//        self.refreshToken   = source.refreshToken
//        self.acountNumberHash    = source.acountNumberHash
//    }

//    init(from decoder: any Decoder) throws
//    {
//        let container       = try decoder.container(keyedBy: CodingKeys.self)
//        
//        self.appId          = try container.decode(String.self, forKey: .appId)
//        self.appSecret      = try container.decode(String.self, forKey: .appSecret)
//        self.redirectUrl    = try container.decode(String.self, forKey: .redirectUrl)
//        
//        do
//        {
//            self.code           = try container.decode(String.self, forKey: .code)
//        }
//        catch
//        {
//            print("Secrets - Error decoding code: \(error)")
//            self.code           = "UNINITIALIZED"
//        }
//        do
//        {
//            self.session        = try container.decode(String.self, forKey: .session)
//        }
//        catch
//        {
//            print("Secrets - Error decoding session: \(error)")
//            self.session        = "UNINITIALIZED"
//        }
//        do
//        {
//            self.accessToken    = try container.decode(String.self, forKey: .accessToken)
//        }
//        catch
//        {
//            print("Secrets - Error decoding accessToken: \(error)")
//            self.accessToken    = "UNINITIALIZED"
//        }
//        do
//        {
//            self.refreshToken   = try container.decode(String.self, forKey: .refreshToken)
//        }
//        catch
//        {
//            print("Secrets - Error decoding refreshToken: \(error)")
//            self.refreshToken   = "UNINITIALIZED"
//        }
//        do
//        {
//            self.acountNumberHash = try container.decode([AccountNumberHash].self, forKey: .acountNumberHash)
//        }
//        catch
//        {
//            print("Secrets - Error decoding acountNumberHash: \(error)")
//            self.acountNumberHash = []
//        }
//    }


    public func encodeToString() -> String?
    {
        do
        {
            let encoder : JSONEncoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(self)
            return String(data: jsonData, encoding: .utf8)
        }
        catch
        {
            print("encodeToString - Error encoding Secrets object to JSON string: \(error)")
            return nil
        }
    }
    
    public func dump() -> String
    {
        var retStr : String =
        "Secret = appId: \(self.appId),  appSecret: \(self.appSecret),  redirectUrl: \(self.redirectUrl), code: \(self.code),  session: \(self.session),  accessToken: \(self.accessToken),  refreshToken: \(self.refreshToken),  acountNumberHash: ["
        self.acountNumberHash.forEach
        { hash in
            retStr += "\n\t\t\t\t\t\t\t\(hash.hashValue ?? "no hash")"
        }
        retStr += "\n\t\t\t\t\t\t]"
        return retStr
    }

    public func getAppId() -> String
    {
        appId
    }
    
//    public func getAppSecret() -> String
//    {
//        appSecret
//    }
//    
//    public func getRedirectUrl() -> String
//    {
//        redirectUrl
//    }
//    
//    public func getCode() -> String
//    {
//        code
//    }
//    
//    public func getSession() -> String
//    {
//        session
//    }
//    
//    public func getAccessToken() -> String
//    {
//        accessToken
//    }
//    
//    public func getRefreshToken() -> String
//    {
//        refreshToken
//    }
//    
//    public func getAccountNumberHash() -> [AccountNumberHash]
//    {
//        acountNumberHash
//    }
//
//    public func setAppId(_ appId: String)
//    {
//        self.appId = appId
//    }
//    
//    public func setAppSecret(_ appSecret: String)
//    {
//        self.appSecret = appSecret
//    }
//    
//    public func setRedirectUrl(_ redirectUrl: String)
//    {
//        self.redirectUrl = redirectUrl
//    }
//    
//    public func setCode(_ code: String)
//    {
//        self.code = code
//    }
//    
//    public func setSession(_ session: String)
//    {
//        self.session = session
//    }
//    
//    public func setAccessToken(_ accessToken: String)
//    {
//        self.accessToken = accessToken
//    }
//    
//    public func setRefreshToken(_ refreshToken: String)
//    {
//        self.refreshToken = refreshToken
//    }
//    
//    public func clearAccountNumberHashes()
//    {
//        acountNumberHash.removeAll()
//    }
//    
//    public func setAccountNumberHash(_ acountNumberHash: [AccountNumberHash] )
//    {
//        self.acountNumberHash = acountNumberHash
//    }

    public func getAccountNumbers() -> [String]
    {
        return acountNumberHash.map( { $0.accountNumber ?? "N/A" } )
    }

    public static func removeSmartQuotes( secretStr: inout String)
    {
        secretStr = secretStr
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
    }


}


