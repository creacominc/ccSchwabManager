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


class TransferItem: Codable, Identifiable, Hashable
{
    static func == (lhs: TransferItem, rhs: TransferItem) -> Bool {
        return (
        lhs.instrument?.symbol == rhs.instrument?.symbol
        && lhs.amount == rhs.amount
        && lhs.cost == rhs.cost
        && lhs.price == rhs.price
        )
    }
    
    public var instrument: Instrument?
    public var amount: Double?
    public var cost: Double?
    public var price: Double?
    public var feeType: FeeType?
    public var positionEffect: PositionEffectType?


    public func hash(into hasher: inout Hasher)
    {
        hasher.combine(ObjectIdentifier(self))
    }

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


}
