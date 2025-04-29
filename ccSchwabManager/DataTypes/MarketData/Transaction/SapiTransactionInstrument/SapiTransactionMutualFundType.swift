//
//  SapiTransactionMutualFundType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 string
 Enum:
 [ NOT_APPLICABLE, OPEN_END_NON_TAXABLE, OPEN_END_TAXABLE, NO_LOAD_NON_TAXABLE, NO_LOAD_TAXABLE, UNKNOWN ]
 */


public enum SapiTransactionMutualFundType: String, Codable, CaseIterable
{
    case NOT_APPLICABLE = "NOT_APPLICABLE"
    case OPEN_END_NON_TAXABLE = "OPEN_END_NON_TAXABLE"
    case OPEN_END_TAXABLE = "OPEN_END_TAXABLE"
}
