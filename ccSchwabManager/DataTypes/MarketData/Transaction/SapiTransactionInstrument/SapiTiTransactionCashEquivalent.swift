//
//  SapiTiTransactionCashEquivalent.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 
 SapiTiTransactionCashEquivalent{
 assetType*    AssetType
  cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    SapiTransactionCashEquivalentType
  }
 
 */

public struct SapiTiTransactionCashEquivalent: Decodable
{
    public let assetType: AssetType
    public let cusip: String
    public let symbol: String
    public let description: String
    public let instrumentId: Int64
    public let netChange: Double
    public let type: SapiAccountCashEquivilantType
}
