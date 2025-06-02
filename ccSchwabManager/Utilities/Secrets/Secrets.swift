
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


