//
//  Order.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-21.
//

import Foundation



/**
 * 
 Order{
 session    session[...]
 duration    duration[...]
 orderType    orderType[...]
 cancelTime    [...]
 complexOrderStrategyType    complexOrderStrategyType[...]
 quantity    [...]
 filledQuantity    [...]
 remainingQuantity    [...]
 requestedDestination    requestedDestination[...]
 destinationLinkName    [...]
 releaseTime    [...]
 stopPrice    [...]
 stopPriceLinkBasis    stopPriceLinkBasis[...]
 stopPriceLinkType    stopPriceLinkType[...]
 stopPriceOffset    [...]
 stopType    stopType[...]
 priceLinkBasis    priceLinkBasis[...]
 priceLinkType    priceLinkType[...]
 price    [...]
 taxLotMethod    taxLotMethod[...]
 orderLegCollection    [...]
 activationPrice    [...]
 specialInstruction    specialInstruction[...]
 orderStrategyType    orderStrategyType[...]
 orderId    [...]
 cancelable    [...]
 editable    [...]
 status    status[...]
 enteredTime    [...]
 closeTime    [...]
 tag    [...]
 accountNumber    [...]
 orderActivityCollection    [...]
 replacingOrderCollection    [...]
 childOrderStrategies    [...]
 statusDescription    [...]
 }
 */


class Order: Codable, Identifiable
{
    
    //    session    session[...]
    public var session: SessionType?
    //    duration    duration[...]
    public var duration: DurationType?
    //    orderType    orderType[...]
    public var orderType: OrderType?
    //    cancelTime    [...]
    public var cancelTime: Date?
    //    complexOrderStrategyType    complexOrderStrategyType[...]
    public var complexOrderStrategyType: ComplexOrderStrategyType?
    //    quantity    [...]
    public var quantity: Double?
    //    filledQuantity    [...]
    public var filledQuantity: Double?
    //    remainingQuantity    [...]
    public var remainingQuantity: Double?
    //    requestedDestination    requestedDestination[...]
    public var requestedDestination: RequestedDestinationType?
    //    destinationLinkName    [...]
    public var destinationLinkName: String?
    //    releaseTime    [...]
    public var releaseTime: String?
    //    stopPrice    [...]
    public var stopPrice: Double?
    //    stopPriceLinkBasis    stopPriceLinkBasis[...]
    public var stopPriceLinkBasis: PriceLinkBasis?
    //    stopPriceLinkType    stopPriceLinkType[...]
    public var stopPriceLinkType: PriceLinkType?
    //    stopPriceOffset    [...]
    public var stopPriceOffset: Double?
    //    stopType    stopType[...]
    public var stopType: StopType?
    //    priceLinkBasis    priceLinkBasis[...]
    public var priceLinkBasis: PriceLinkBasis?
    //    priceLinkType    priceLinkType[...]
    public var priceLinkType: PriceLinkType?
    //    price    [...]
    public var price: Double?
    //    taxLotMethod    taxLotMethod[...]
    public var taxLotMethod: TaxLotMethod?
    //    orderLegCollection    [...]
    public var orderLegCollection: [OrderLegCollection]?
    //    activationPrice    [...]
    public var activationPrice: Double?
    //    specialInstruction    specialInstruction[...]
    public var specialInstruction: SpecialInstruction?
    //    orderStrategyType    orderStrategyType[...]
    public var orderStrategyType: OrderStrategyType?
    //    orderId    [...]
    public var orderId: Int64?
    //    cancelable    [...]
    public var cancelable: Bool?
    //    editable    [...]
    public var editable: Bool?
    //    status    status[...]
    public var status: OrderStatus?
    //    enteredTime    [...]
    public var enteredTime: String?
    //    closeTime    [...]
    public var closeTime: String?
    //    tag    [...]
    public var tag: String?
    //    accountNumber    [...]
    public var accountNumber: Int64?
    //    orderActivityCollection    [...]
    public var orderActivityCollection: [OrderActivity]?
    //    replacingOrderCollection    [...]
    //    childOrderStrategies    [...]
    //    statusDescription    [...]
    public var statusDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case quantity
        case filledQuantity
        case remainingQuantity
        case requestedDestination
        case destinationLinkName
        case releaseTime
        case stopPrice
        case stopPriceLinkBasis
        case stopPriceLinkType
        case stopPriceOffset
        case stopType
        case priceLinkBasis
        case priceLinkType
        case price
        case taxLotMethod
        case orderLegCollection
        case activationPrice
        case specialInstruction
        case orderStrategyType
        case orderId
        case cancelable
        case editable
        case status
        case enteredTime
        case closeTime
        case tag
        case accountNumber
        case orderActivityCollection
        //case replacingOrderCollection
        case statusDescription
    }
    

    public init(session: SessionType? = nil, duration: DurationType? = nil, orderType: OrderType? = nil, cancelTime: Date? = nil, complexOrderStrategyType: ComplexOrderStrategyType? = nil, quantity: Double? = nil, filledQuantity: Double? = nil, remainingQuantity: Double? = nil, requestedDestination: RequestedDestinationType? = nil, destinationLinkName: String? = nil, releaseTime: String? = nil, stopPrice: Double? = nil, stopPriceLinkBasis: PriceLinkBasis? = nil, stopPriceLinkType: PriceLinkType? = nil, stopPriceOffset: Double? = nil, stopType: StopType? = nil, priceLinkBasis: PriceLinkBasis? = nil, priceLinkType: PriceLinkType? = nil, price: Double? = nil, taxLotMethod: TaxLotMethod? = nil, orderLegCollection: [OrderLegCollection]? = nil, activationPrice: Double? = nil, specialInstruction: SpecialInstruction? = nil, orderStrategyType: OrderStrategyType? = nil, orderId: Int64? = nil, cancelable: Bool? = nil, editable: Bool? = nil, status: OrderStatus? = nil, enteredTime: String? = nil, closeTime: String? = nil, tag: String? = nil, accountNumber: Int64? = nil, orderActivityCollection: [OrderActivity]? = nil, statusDescription: String? = nil) {
        self.session = session
        self.duration = duration
        self.orderType = orderType
        self.cancelTime = cancelTime
        self.complexOrderStrategyType = complexOrderStrategyType
        self.quantity = quantity
        self.filledQuantity = filledQuantity
        self.remainingQuantity = remainingQuantity
        self.requestedDestination = requestedDestination
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
        self.tag = tag
        self.accountNumber = accountNumber
        self.orderActivityCollection = orderActivityCollection
        self.statusDescription = statusDescription
    }
    
}

