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


public class SapiTransactionEquity: Codable
{
    public enum EquityStatus: String, Codable
    {
        case ACTIVE = "ACTIVE"
        case INACTIVE = "INACTIVE"
    }
    
    public var assetType: AssetType
    public var status: EquityStatus
    public var symbol: String
    public var instrumentId: Int
    public var closingPrice: Double
    public var type: SapiTransactionEquityType
    
    
    enum CodingKeys: String, CodingKey
    {
        case assetType = "assetType"
        case status = "status"
        case symbol = "symbol"
        case instrumentId = "instrumentId"
        case closingPrice = "closingPrice"
        case type = "type"
    }
    
    // Initializer
    public init(
        assetType: AssetType,
        status: EquityStatus,
        symbol: String,
        instrumentId: Int,
        closingPrice: Double,
        type: SapiTransactionEquityType
    )
    {
        self.assetType = assetType
        self.status = status
        self.symbol = symbol
        self.instrumentId = instrumentId
        self.closingPrice = closingPrice
        self.type = type
    }
    
}
