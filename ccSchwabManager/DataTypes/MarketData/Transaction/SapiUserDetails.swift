//
//  SapiUserDetails.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

import Foundation
import SwiftData


public struct SapiUserDetails : Codable
{
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
    
    var cdDomainId: String
    var login: String
    var type: SapiUserType
    var userId: Int64
    var  systemUserName: String
    var firstName: String
    var lastName: String
    var brokerRepCode: String

}

