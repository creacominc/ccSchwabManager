//
//  SapiTransactionFixedIncome.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 SapiTransactionFixedIncome{
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    SapiTransactionFixedIncomeType
 maturityDate    string($date-time)
 factor    number($double)
 multiplier    number($double)
 variableRate    number($double)
 }
 */

public struct SapiTransactionFixedIncome: Codable
{
    public let assetType: AssetType
    public let cusip: String
    public let symbol: String
    public let description: String
    public let instrumentId: Int64
    public let netChange: Double
    public let type: SapiTransactionFixedIncomeType
    public let maturityDate: String
    public let factor: Double
    public let multiplier: Double
    public let variableRate: Double
}
