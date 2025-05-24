//
//  OrderExecutionLeg.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 ExecutionLeg{
 legId    integer($int64)
 price    number($double)
 quantity    number($double)
 mismarkedQuantity    number($double)
 instrumentId    integer($int64)
 time    string($date-time)
 }
 */

class OrderExecutionLeg: Codable, Identifiable {
    var legId: Int64?
    var price: Double?
    var quantity: Double?
    var mismarkedQuantity: Double?
    var instrumentId: Int64?
    var time: String?
    
    enum CodingKeys: String, CodingKey {
        case legId = "legId"
        case price = "price"
        case quantity = "quantity"
        case mismarkedQuantity = "mismarkedQuantity"
        case instrumentId = "instrumentId"
        case time = "time"
    }

    init(legId: Int64? = nil, price: Double? = nil, quantity: Double? = nil, mismarkedQuantity: Double? = nil, instrumentId: Int64? = nil, time: String? = nil) {
        self.legId = legId
        self.price = price
        self.quantity = quantity
        self.mismarkedQuantity = mismarkedQuantity
        self.instrumentId = instrumentId
        self.time = time
    }
}
