//
//  SapiTransactionActivityType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

import Foundation

public enum SapiTransactionActivityType: String, Codable, CaseIterable
{
    case ACTIVITY_CORRECTION
    case EXECUTION
    case ORDER_ACTION
    case TRANSFER
    case UNKNOWN
}
