//
//  SapiUserDetails.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

import Foundation


struct UserDetails: Codable, Identifiable, Hashable, Sendable
{
    var id: Int64 { userId ?? 0 }
    /**
     cdDomainId    string
     login    string
     type    string
     Enum:
     [ ADVISOR_USER, BROKER_USER, CLIENT_USER, SYSTEM_USER, UNKNOWN ]
     userId    integer($int64)
     systemUserName    string
     firstName    string
     lastName    string
     brokerRepCode    string
     */

    let cdDomainId: String?
    let login: String?
    let type: UserType?
    let userId: Int64?
    let systemUserName: String?
    let firstName: String?
    let lastName: String?
    let brokerRepCode: String?

    // coding keys
    enum CodingKeys : String, CodingKey
    {
        case cdDomainId = "cdDomainId"
        case login = "login"
        case type = "type"
        case userId = "userId"
        case systemUserName = "systemUserName"
        case firstName = "firstName"
        case lastName = "lastName"
        case brokerRepCode = "brokerRepCode"
    }

    public init(cdDomainId: String? = nil, login: String? = nil, type: UserType? = nil, userId: Int64? = nil, systemUserName: String? = nil, firstName: String? = nil, lastName: String? = nil, brokerRepCode: String? = nil)
    {
        self.cdDomainId = cdDomainId
        self.login = login
        self.type = type
        self.userId = userId
        self.systemUserName = systemUserName
        self.firstName = firstName
        self.lastName = lastName
        self.brokerRepCode = brokerRepCode
    }
}
