//
//  SapiTransactionOption.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 SapiTransactionOption{
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 expirationDate    string($date-time)
 optionDeliverables    [SapiTransactionAPIOptionDeliverable]
 optionPremiumMultiplier    integer($int64)
 putCall    SapiPutCallType
 strikePrice    number($double)
 type    SapiAccountOptionType
 underlyingSymbol    string
 underlyingCusip    string
 deliverable    { }
 }
 */

public struct SapiTransactionOption: Decodable
{
    public let assetType: AssetType
    public let cusip: String
    public let symbol: String
    public let description: String
    public let instrumentId: Int64
    public let netChange: Double
    public let expirationDate: String
    public let optionDeliverables: [SapiTransactionAPIOptionDeliverable]
    public let optionPremiumMultiplier: Int64
    public let putCall: SapiPutCallType
    public let strikePrice: Double
    public let type: SapiAccountOptionType
    public let underlyingSymbol: String
    public let underlyingCusip: String
    //public let deliverable: Empty
}
