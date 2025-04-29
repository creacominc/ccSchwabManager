//
//  SapiTransferItem.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

import Foundation

/**
 * 
 */


public struct SapiTransferItem: Decodable
{
    public let instrument: SapiTransactionInstrument
    public let amount: Double
    public let cost: Double
    public let price: Double
    public let feeType: SapiFeeType
    public let positionEffect: SapiPositionEffectType
}
