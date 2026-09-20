//
//  TransferItem.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

import Foundation

/**
 *  transfer items are held in a collection in the transactions response as follows:
 *
 *     "transferItems": [
 *     {
 *         "instrument": {
 *             "assetType": "EQUITY",
 *             "status": "ACTIVE",
 *             "symbol": "SFM",
 *             "instrumentId": 1806651,
 *             "closingPrice": 169.76,
 *             "type": "COMMON_STOCK"
 *         },
 *         "amount": 3.0,
 *         "cost": -501.9,
 *         "price": 167.3,
 *         "positionEffect": "OPENING"
 *     }
 *    ]
 *
 */


struct TransferItem: Codable, Identifiable, Hashable, Sendable
{
    var id: String {
        let symbol = instrument?.symbol ?? ""
        let amount = amount.map { String($0) } ?? ""
        let cost = cost.map { String($0) } ?? ""
        let price = price.map { String($0) } ?? ""
        return "\(symbol)|\(amount)|\(cost)|\(price)"
    }

    static func == (lhs: TransferItem, rhs: TransferItem) -> Bool {
        return (
        lhs.instrument?.symbol == rhs.instrument?.symbol
        && lhs.amount == rhs.amount
        && lhs.cost == rhs.cost
        && lhs.price == rhs.price
        )
    }
    
    public let instrument: Instrument?
    public let amount: Double?
    public let cost: Double?
    public let price: Double?
    public let feeType: FeeType? = nil
    public let positionEffect: PositionEffectType?

    enum CodingKeys: String, CodingKey
    {
        case instrument = "instrument"
        case amount = "amount"
        case cost = "cost"
        case price = "price"
        case positionEffect = "positionEffect"
    }

    public init(
        instrument: Instrument? = nil,
        amount: Double? = nil,
        cost: Double? = nil,
        price: Double? = nil,
        positionEffect: PositionEffectType? = nil
    )
    {
        self.instrument = instrument
        self.amount = amount
        self.cost = cost
        self.price = price
        self.positionEffect = positionEffect
    }


    // print the contents of the transfer item
    public func dump()
    {
        print( "                       ----------------------")
        print("     TransferItem Details:")
        if let instrumentSymbol = instrument?.symbol { print("      instrument.symbol: \(instrumentSymbol)") }
        if let amount = amount { print("      amount: \(amount)") }
        if let cost = cost { print("      cost: \(cost)") }
        if let price = price { print("      price: \(price)") }
        if let positionEffect = positionEffect { print("      positionEffect: \(positionEffect)") }
    }

}
