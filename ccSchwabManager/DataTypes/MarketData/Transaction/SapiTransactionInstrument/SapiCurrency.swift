//
//  SapiCurrency.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 SapiCurrency{
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 }
 */

public struct SapiCurrency: Codable
{
    public var assetType: AssetType
    public var cusip: String
    public var symbol: String
    public var description: String
    public var instrumentId: Int64
    public var netChange: Double
}
