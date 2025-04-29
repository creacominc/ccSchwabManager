//
//  SapiTiCollectiveInvestment.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 
 SapiTiCollectiveInvestment {
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    SapiAccountCashEquivilantType
 }
 */

public struct SapiTiCollectiveInvestment: Codable
{
    public var assetType: AssetType
    public var cusip: String
    public var symbol: String
    public var description: String
    public var instrumentId: Int64
    public var netChange: Double
    public var type: SapiAccountCashEquivilantType
}


