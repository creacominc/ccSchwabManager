//
//  OrderLegType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 orderLegType    string
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]

 */

public enum OrderLegType: String, Codable, CaseIterable {
    case EQUITY = "EQUITY"
    case OPTION = "OPTION"
    case INDEX = "INDEX"
    case MUTUAL_FUND = "MUTUAL_FUND"
    case CASH_EQUIVALENT = "CASH_EQUIVALENT"
    case FIXED_INCOME = "FIXED_INCOME"
    case CURRENCY = "CURRENCY"
    case COLLECTIVE_INVESTMENT = "COLLECTIVE_INVESTMENT"
}
