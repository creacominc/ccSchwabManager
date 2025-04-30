//
//  SapiTransactionStatus.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

import Foundation

public enum SapiTransactionStatus: String, Codable, CaseIterable
{
    case VALID    = "VALID"
    case INVALID  = "INVALID"
    case PENDING  = "PENDING"
    case UNKNOWN  = "UNKNOWN"
}
