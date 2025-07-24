//
//  Order.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-21.
//

import Foundation


/**
*

OrderRequest{
session	Enum: [ NORMAL, AM, PM, SEAMLESS ]
duration	Enum: [ DAY, GTC, GTD ]
orderType	Enum: [ MARKET, LIMIT, STOP, STOP_LIMIT, TRAILING_STOP, TRAILING_STOP_LIMIT, OCO, OTO, OTO_LIMIT, OTO_STOP, OTO_STOP_LIMIT, OTO_TRAILING_STOP, OTO_TRAILING_STOP_LIMIT ]
cancelTime	date-time
complexOrderStrategyType	Enum: [ NONE, OCO, OTO ]
quantity	int64
filledQuantity	int64
remainingQuantity	int64
destinationLinkName	string
releaseTime	date-time
stopPrice	int64
stopPriceLinkBasis	Enum: [ MANUAL, MARKET, LAST, BID, ASK, BID_PLUS_TAX, ASK_PLUS_TAX ]
stopPriceLinkType	Enum: [ VALUE, PERCENTAGE ]
stopPriceOffset	int64
stopType	Enum: [ STANDARD, STOP_LIMIT ]
priceLinkBasis	Enum: [ MANUAL, MARKET, LAST, BID, ASK, BID_PLUS_TAX, ASK_PLUS_TAX ]
priceLinkType	Enum: [ VALUE, PERCENTAGE ]
price	int64
taxLotMethod	Enum: [ FIFO, LIFO, HIFO, AVG_COST ]
orderLegCollection	[...]
activationPrice	int64
specialInstruction	Enum: [ ALL_OR_NONE, DO_NOT_INCREASE, DO_NOT_REDUCE ]
orderStrategyType	Enum: [ SINGLE, OCO, OTO ]
orderId	int64
cancelable	bool
editable	bool
status	Enum: [ AWAITING_PARENT_ORDER, AWAITING_CONDITION, AWAITING_SUBMISSION, AWAITING_CANCEL_CONFIRMATION, AWAITING_CANCEL_REJECTION, AWAITING_REISSUE, AWAITING_REISSUE_CONFIRMATION, AWAITING_REISSUE_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_REISSUE_CANCEL_CONFIRMATION, AWAITING_REISSUE_CANCEL_REJECTION, AWAITING_CANCEL_CONFIRMATION, AWAITING_CANCEL_REJECTION, AWAITING_SUBMISSION, AWAITING_CONDITION, AWAITING_PARENT_ORDER ]
enteredTime	date-time
closeTime	date-time
accountNumber	int64
orderActivityCollection	[...]
replacingOrderCollection	[...]
childOrderStrategies	[...]
statusDescription	string  
}
*/


class OrderRequest: Codable, Identifiable
{
    public var session: String
    public var duration: String
    public var orderType: String
    public var cancelTime: Date
    public var complexOrderStrategyType: String
    public var quantity: Int64
    public var filledQuantity: Int64
    public var remainingQuantity: Int64
    public var destinationLinkName: String
    public var releaseTime: Date
    public var stopPrice: Int64
    public var stopPriceLinkBasis: String
    public var stopPriceLinkType: String
    public var stopPriceOffset: Int64
    public var stopType: String
    public var priceLinkBasis: String
    public var priceLinkType: String
    public var price: Int64
    public var taxLotMethod: String
    public var orderLegCollection: [OrderLegCollection]
    public var activationPrice: Int64
    public var specialInstruction: String
    public var orderStrategyType: String
    public var orderId: Int64
    public var cancelable: Bool
    public var editable: Bool
    public var status: String
    public var enteredTime: Date
    public var closeTime: Date
    public var accountNumber: Int64
    public var orderActivityCollection: [OrderActivity]
    public var replacingOrderCollection: [Order]
    public var childOrderStrategies: [Order]
    public var statusDescription: String

    enum CodingKeys: String, CodingKey {
        case session = "session"
        case duration = "duration"
        case orderType = "orderType"
        case cancelTime = "cancelTime"
        case complexOrderStrategyType = "complexOrderStrategyType"
        case quantity = "quantity"
        case filledQuantity = "filledQuantity"
        case remainingQuantity = "remainingQuantity"
        case destinationLinkName = "destinationLinkName"
        case releaseTime = "releaseTime"
        case stopPrice = "stopPrice"
        case stopPriceLinkBasis = "stopPriceLinkBasis"
        case stopPriceLinkType = "stopPriceLinkType"
        case stopPriceOffset = "stopPriceOffset"
        case stopType = "stopType"
        case priceLinkBasis = "priceLinkBasis"
        case priceLinkType = "priceLinkType"
        case price = "price"
        case taxLotMethod = "taxLotMethod"
        case orderLegCollection = "orderLegCollection"
        case activationPrice = "activationPrice"
        case specialInstruction = "specialInstruction"
        case orderStrategyType = "orderStrategyType"
        case orderId = "orderId"
        case cancelable = "cancelable"
        case editable = "editable"
        case status = "status"
        case enteredTime = "enteredTime"
        case closeTime = "closeTime"
        case accountNumber = "accountNumber"
        case orderActivityCollection = "orderActivityCollection"
        case replacingOrderCollection = "replacingOrderCollection"
        case childOrderStrategies = "childOrderStrategies"
        case statusDescription = "statusDescription"
    }

    public init( session: String, duration: String, orderType: String, 
                 cancelTime: Date, complexOrderStrategyType: String, 
                 quantity: Int64, filledQuantity: Int64, remainingQuantity: Int64, 
                 destinationLinkName: String, releaseTime: Date, stopPrice: Int64, 
                 stopPriceLinkBasis: String, stopPriceLinkType: String, 
                 stopPriceOffset: Int64, stopType: String, priceLinkBasis: String, 
                 priceLinkType: String, price: Int64, taxLotMethod: String, 
                 orderLegCollection: [OrderLegCollection], activationPrice: Int64, 
                 specialInstruction: String, orderStrategyType: String, 
                 orderId: Int64, cancelable: Bool, editable: Bool, 
                 status: String, enteredTime: Date, closeTime: Date, 
                 accountNumber: Int64, orderActivityCollection: [OrderActivity], 
                 replacingOrderCollection: [Order], childOrderStrategies: [Order], 
                 statusDescription: String )
    {
        self.session = session
        self.duration = duration
        self.orderType = orderType
        self.cancelTime = cancelTime
        self.complexOrderStrategyType = complexOrderStrategyType
        self.quantity = quantity
        self.filledQuantity = filledQuantity
        self.remainingQuantity = remainingQuantity
        self.destinationLinkName = destinationLinkName
        self.releaseTime = releaseTime
        self.stopPrice = stopPrice
        self.stopPriceLinkBasis = stopPriceLinkBasis
        self.stopPriceLinkType = stopPriceLinkType
        self.stopPriceOffset = stopPriceOffset
        self.stopType = stopType
        self.priceLinkBasis = priceLinkBasis
        self.priceLinkType = priceLinkType
        self.price = price
        self.taxLotMethod = taxLotMethod
        self.orderLegCollection = orderLegCollection
        self.activationPrice = activationPrice
        self.specialInstruction = specialInstruction
        self.orderStrategyType = orderStrategyType
        self.orderId = orderId
        self.cancelable = cancelable
        self.editable = editable
        self.status = status
        self.enteredTime = enteredTime
        self.closeTime = closeTime
        self.accountNumber = accountNumber
        self.orderActivityCollection = orderActivityCollection
        self.replacingOrderCollection = replacingOrderCollection
        self.childOrderStrategies = childOrderStrategies
        self.statusDescription = statusDescription
    }


    public func toJSON() -> String  // for debugging
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try? encoder.encode(self)
        return String(data: jsonData ?? Data(), encoding: .utf8) ?? ""
    }


}

