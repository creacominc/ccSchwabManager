//
//  SapiTransactionEquity.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 SapiTransactionEquity{
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    SapiTransactionEquityType
  }
 */

public struct SapiTransactionEquity: Codable
{
    var assetType: AssetType
    var cusip: String
    var symbol: String
    var description: String
    var instrumentId: Int64
    var netChange: Double
    var type: SapiTransactionEquityType
}

