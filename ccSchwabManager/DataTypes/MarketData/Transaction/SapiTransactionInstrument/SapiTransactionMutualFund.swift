//
//  SapiTransactionMutualFund.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 SapiTransactionMutualFund{
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 fundFamilyName    string
 fundFamilySymbol    string
 fundGroup    string
 type    SapiTransactionMutualFundType
 exchangeCutoffTime    string($date-time)
 purchaseCutoffTime    string($date-time)
 redemptionCutoffTime    string($date-time)
 }
 */

public struct SapiTransactionMutualFund: Decodable
{
    public let assetType: AssetType
    public let cusip: String
    public let symbol: String
    public let description: String
    public let instrumentId: Int64
    public let netChange: Double
    public let fundFamilyName: String
    public let fundFamilySymbol: String
    public let fundGroup: String
    public let type: SapiTransactionMutualFundType
    public let exchangeCutoffTime: String
    public let purchaseCutoffTime: String
    public let redemptionCutoffTime: String
}
