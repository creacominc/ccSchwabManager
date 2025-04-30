//
//  SapiTransactionSubAccount.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

import Foundation

public enum SapiTransactionSubAccount: String, Codable, CaseIterable
{
    case CASH
    case MARGIN
    case SHORT
    case DIV
    case INCOME
    case UNKNOWN
}
