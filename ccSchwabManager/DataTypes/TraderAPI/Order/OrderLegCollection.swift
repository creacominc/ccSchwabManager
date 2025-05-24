//
//  OrderLegCollection.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 orderLegCollection    [
 xml: OrderedMap { "name": "orderLegCollection", "wrapped": true }
 OrderLegCollection{
 orderLegType    [...]
 legId    [...]
 instrument    AccountsInstrument{...}
 instruction    instruction[...]
 positionEffect    [...]
 quantity    [...]
 quantityType    [...]
 divCapGains    [...]
 toSymbol    [...]
 }]

 */

class OrderLegCollection: Codable, Identifiable {
    var orderLegType: OrderLegType?
    var legId: Int64?
    var instrument: AccountsInstrument?
    var instruction: OrderInstructionType?
    var positionEffect: PositionEffectType?
    var quantity: Double?
    var quantityType: QuantityType?
    var divCapGains: DivCapGains?
    var toSymbol: String?
    
    enum CodingKeys : String, CodingKey {
        case orderLegType
        case legId
        case instrument
        case instruction
        case positionEffect
        case quantity
        case quantityType
        case divCapGains
        case toSymbol
    }

    init(orderLegType: OrderLegType? = nil, legId: Int64? = nil, instrument: AccountsInstrument? = nil, instruction: OrderInstructionType? = nil, positionEffect: PositionEffectType? = nil, quantity: Double? = nil, quantityType: QuantityType? = nil, divCapGains: DivCapGains? = nil, toSymbol: String? = nil) {
        self.orderLegType = orderLegType
        self.legId = legId
        self.instrument = instrument
        self.instruction = instruction
        self.positionEffect = positionEffect
        self.quantity = quantity
        self.quantityType = quantityType
        self.divCapGains = divCapGains
        self.toSymbol = toSymbol
    }
    
}


