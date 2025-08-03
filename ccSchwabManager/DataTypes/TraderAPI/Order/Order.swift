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
    //    priceOffset    [...]
    public var priceOffset: Double?
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
    public var childOrderStrategies: [Order]?
    //    statusDescription    [...]
    public var statusDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case session
        case duration
        case orderType
        case cancelTime
        case complexOrderStrategyType
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
        case priceOffset
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
        case childOrderStrategies
        case statusDescription
    }
    

    public init(session: SessionType? = nil, duration: DurationType? = nil, orderType: OrderType? = nil, cancelTime: Date? = nil, complexOrderStrategyType: ComplexOrderStrategyType? = nil, quantity: Double? = nil, filledQuantity: Double? = nil, remainingQuantity: Double? = nil, requestedDestination: RequestedDestinationType? = nil, destinationLinkName: String? = nil, releaseTime: String? = nil, stopPrice: Double? = nil, stopPriceLinkBasis: PriceLinkBasis? = nil, stopPriceLinkType: PriceLinkType? = nil, stopPriceOffset: Double? = nil, stopType: StopType? = nil, priceLinkBasis: PriceLinkBasis? = nil, priceLinkType: PriceLinkType? = nil, priceOffset: Double? = nil, price: Double? = nil, taxLotMethod: TaxLotMethod? = nil, orderLegCollection: [OrderLegCollection]? = nil, activationPrice: Double? = nil, specialInstruction: SpecialInstruction? = nil, orderStrategyType: OrderStrategyType? = nil, orderId: Int64? = nil, cancelable: Bool? = nil, editable: Bool? = nil, status: OrderStatus? = nil, enteredTime: String? = nil, closeTime: String? = nil, tag: String? = nil, accountNumber: Int64? = nil, orderActivityCollection: [OrderActivity]? = nil, childOrderStrategies: [Order]? = nil, statusDescription: String? = nil) {
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
        self.priceOffset = priceOffset
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
        self.childOrderStrategies = childOrderStrategies
        self.statusDescription = statusDescription
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all other properties normally
        session = try container.decodeIfPresent(SessionType.self, forKey: .session)
        duration = try container.decodeIfPresent(DurationType.self, forKey: .duration)
        orderType = try container.decodeIfPresent(OrderType.self, forKey: .orderType)
        complexOrderStrategyType = try container.decodeIfPresent(ComplexOrderStrategyType.self, forKey: .complexOrderStrategyType)
        quantity = try container.decodeIfPresent(Double.self, forKey: .quantity)
        filledQuantity = try container.decodeIfPresent(Double.self, forKey: .filledQuantity)
        remainingQuantity = try container.decodeIfPresent(Double.self, forKey: .remainingQuantity)
        requestedDestination = try container.decodeIfPresent(RequestedDestinationType.self, forKey: .requestedDestination)
        destinationLinkName = try container.decodeIfPresent(String.self, forKey: .destinationLinkName)
        releaseTime = try container.decodeIfPresent(String.self, forKey: .releaseTime)
        stopPrice = try container.decodeIfPresent(Double.self, forKey: .stopPrice)
        stopPriceLinkBasis = try container.decodeIfPresent(PriceLinkBasis.self, forKey: .stopPriceLinkBasis)
        stopPriceLinkType = try container.decodeIfPresent(PriceLinkType.self, forKey: .stopPriceLinkType)
        stopPriceOffset = try container.decodeIfPresent(Double.self, forKey: .stopPriceOffset)
        stopType = try container.decodeIfPresent(StopType.self, forKey: .stopType)
        priceLinkBasis = try container.decodeIfPresent(PriceLinkBasis.self, forKey: .priceLinkBasis)
        priceLinkType = try container.decodeIfPresent(PriceLinkType.self, forKey: .priceLinkType)
        priceOffset = try container.decodeIfPresent(Double.self, forKey: .priceOffset)
        price = try container.decodeIfPresent(Double.self, forKey: .price)
        taxLotMethod = try container.decodeIfPresent(TaxLotMethod.self, forKey: .taxLotMethod)
        orderLegCollection = try container.decodeIfPresent([OrderLegCollection].self, forKey: .orderLegCollection)
        activationPrice = try container.decodeIfPresent(Double.self, forKey: .activationPrice)
        specialInstruction = try container.decodeIfPresent(SpecialInstruction.self, forKey: .specialInstruction)
        orderStrategyType = try container.decodeIfPresent(OrderStrategyType.self, forKey: .orderStrategyType)
        orderId = try container.decodeIfPresent(Int64.self, forKey: .orderId)
        cancelable = try container.decodeIfPresent(Bool.self, forKey: .cancelable)
        editable = try container.decodeIfPresent(Bool.self, forKey: .editable)
        status = try container.decodeIfPresent(OrderStatus.self, forKey: .status)
        enteredTime = try container.decodeIfPresent(String.self, forKey: .enteredTime)
        closeTime = try container.decodeIfPresent(String.self, forKey: .closeTime)
        tag = try container.decodeIfPresent(String.self, forKey: .tag)
        accountNumber = try container.decodeIfPresent(Int64.self, forKey: .accountNumber)
        orderActivityCollection = try container.decodeIfPresent([OrderActivity].self, forKey: .orderActivityCollection)
        childOrderStrategies = try container.decodeIfPresent([Order].self, forKey: .childOrderStrategies)
        statusDescription = try container.decodeIfPresent(String.self, forKey: .statusDescription)
        
        // Handle cancelTime which might be a string, null, or missing
        if let cancelTimeString = try container.decodeIfPresent(String.self, forKey: .cancelTime) {
            // Try to parse the string as a date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            
            if let date = dateFormatter.date(from: cancelTimeString) {
                cancelTime = date
            } else {
                // Try alternative format without milliseconds
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                cancelTime = dateFormatter.date(from: cancelTimeString)
            }
        } else {
            cancelTime = nil
        }
    }
    
}

