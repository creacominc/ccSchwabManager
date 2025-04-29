//
//  SapiForex.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation


/**
 SapiForex{
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    SapiForexType
 baseCurrency    SapiCurrency
 counterCurrency    SapiCurrency
 }
 */

public struct SapiForex: Decodable
{
    var assetType: AssetType
    var cusip: String
    var symbol: String
    var description: String
    var instrumentId: Int64
    var netChange: Double
    var type: SapiForexType
    var baseCurrency: SapiCurrency
    var counterCurrency: SapiCurrency
}
