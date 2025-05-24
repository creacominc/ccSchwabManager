//
//  OrderActivity.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 OrderActivity{
 activityType    string
 Enum:
 [ EXECUTION, ORDER_ACTION ]
 executionType    string
 Enum:
 [ FILL ]
 quantity    number($double)
 orderRemainingQuantity    number($double)
 executionLegs    [
 xml: OrderedMap { "name": "executionLegs", "wrapped": true }
 ExecutionLeg{...}]
 }
 */

class OrderActivity: Codable, Identifiable {
    var activityType: OrderActivityType?
    var executionType: OrderExecutionType?
    var quantity: Double?
    var orderRemainingQuantity: Double?
    var executionLegs: [OrderExecutionLeg]?
    
    enum CodingKeys: String, CodingKey {
        case activityType = "activityType"
        case executionType = "executionType"
        case quantity = "quantity"
        case orderRemainingQuantity = "orderRemainingQuantity"
        case executionLegs = "executionLegs"
    }
    
    init(activityType: OrderActivityType? = nil, executionType: OrderExecutionType? = nil, quantity: Double? = nil, orderRemainingQuantity: Double? = nil, executionLegs: [OrderExecutionLeg]? = nil) {
        self.activityType = activityType
        self.executionType = executionType
        self.quantity = quantity
        self.orderRemainingQuantity = orderRemainingQuantity
        self.executionLegs = executionLegs
    }
}
