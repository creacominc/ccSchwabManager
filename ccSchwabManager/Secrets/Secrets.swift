
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
    private var acountNumberHash    : [SapiAccountNumberHash]

    init()
    {
        appId               = "UNINITIALIZED"
        appSecret           = "UNINITIALIZED"
        redirectUrl         = "UNINITIALIZED"
        code                = "UNINITIALIZED"
        session             = "UNINITIALIZED"
        accessToken         = "UNINITIALIZED"
        refreshToken        = "UNINITIALIZED"
        acountNumberHash    = []
    }

    required init(from decoder: any Decoder) throws
    {
        let container       = try decoder.container(keyedBy: CodingKeys.self)

        self.appId          = try container.decode(String.self, forKey: .appId)
        self.appSecret      = try container.decode(String.self, forKey: .appSecret)
        self.redirectUrl    = try container.decode(String.self, forKey: .redirectUrl)

        do
        {
            self.code           = try container.decode(String.self, forKey: .code)
        }
        catch
        {
            print("Secrets - Error decoding code: \(error)")
            self.code           = "UNINITIALIZED"
        }
        do
        {
            self.session        = try container.decode(String.self, forKey: .session)
        }
        catch
        {
            print("Secrets - Error decoding session: \(error)")
            self.session        = "UNINITIALIZED"
        }
        do
        {
            self.accessToken    = try container.decode(String.self, forKey: .accessToken)
        }
        catch
        {
            print("Secrets - Error decoding accessToken: \(error)")
            self.accessToken    = "UNINITIALIZED"
        }
        do
        {
            self.refreshToken   = try container.decode(String.self, forKey: .refreshToken)
        }
        catch
        {
            print("Secrets - Error decoding refreshToken: \(error)")
            self.refreshToken   = "UNINITIALIZED"
        }
        do
        {
            self.acountNumberHash = try container.decode([SapiAccountNumberHash].self, forKey: .acountNumberHash)
        }
        catch
        {
            print("Secrets - Error decoding acountNumberHash: \(error)")
            self.acountNumberHash = []
        }
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
            retStr += "\n\t\t\t\t\t\t\t\(hash.dump())"
        }
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

    public func getAccountNumberHash() -> [SapiAccountNumberHash]
    {
        acountNumberHash
    }


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

    public func clearAccountNumberHashes()
    {
        acountNumberHash.removeAll()
    }

    public func setAccountNumberHash(_ acountNumberHash: [SapiAccountNumberHash] )
    {
        self.acountNumberHash = acountNumberHash
    }

    public func getAccountNumbers() -> [String]
    {
        return acountNumberHash.map( { $0.getAccountNumber() } )
    }

}


