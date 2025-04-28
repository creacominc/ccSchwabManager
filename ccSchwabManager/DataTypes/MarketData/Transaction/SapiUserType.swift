//
//  SapiUserType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

import Foundation

public enum SapiUserType: String, Codable, CaseIterable
{

    case ADVISOR_USER
    case BROKER_USER
    case CLIENT_USER
    case SYSTEM_USER
    case UNKNOWN

}
