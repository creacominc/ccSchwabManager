//
//  SapiTransactionAPIOptionDeliverable.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-29.
//

import Foundation

/**
 TransactionAPIOptionDeliverable{
     rootSymbol    string
     strikePercent    integer($int64)
     deliverableNumber    integer($int64)
     deliverableUnits    number($double)
     deliverable    {}
     assetType    AssetType
 }
 */

public struct SapiTransactionAPIOptionDeliverable: Codable
{
    var rootSymbol: String
    var strikePercent: Int64
    var deliverableNumber: Int64
    var deliverableUnits: Double
    //var deliverable: Any
    var assetType: AssetType
}
