//
//

import Foundation


/**
 "extended": {
    "askPrice": 0,
    "askSize": 0,
    "bidPrice": 0,
    "bidSize": 0,
    "lastPrice": 125,
    "lastSize": 9,
    "mark": 0,
    "quoteTime": 1736499595000,
    "totalVolume": 0,
    "tradeTime": 1736235303000
 },
 */


class ExtendedMarket : Codable, Identifiable
{
    public var askPrice: Double?
    public var askSize: Int?
    public var bidPrice: Double?
    public var bidSize: Int?
    public var lastPrice: Double?
    public var lastSize: Int?
    public var mark: Double?
    public var quoteTime: Int?
    public var totalVolume: Int?
    public var tradeTime: Int?
    

    enum CodingKeys : String, CodingKey
    {
        case askPrice = "askPrice"
        case askSize = "askSize"
        case bidPrice = "bidPrice"
        case bidSize = "bidSize"
        case lastPrice = "lastPrice"
        case lastSize = "lastSize"
        case mark = "mark"
        case quoteTime = "quoteTime"
        case totalVolume = "totalVolume"
        case tradeTime = "tradeTime"
    }

    public init(askPrice: Double? = nil, askSize: Int? = nil, bidPrice: Double? = nil, bidSize: Int? = nil, lastPrice: Double? = nil, lastSize: Int? = nil, mark: Double? = nil, quoteTime: Int? = nil, totalVolume: Int? = nil, tradeTime: Int? = nil)
    {
        self.askPrice = askPrice
        self.askSize = askSize
        self.bidPrice = bidPrice
        self.bidSize = bidSize
        self.lastPrice = lastPrice
        self.lastSize = lastSize
        self.mark = mark
        self.quoteTime = quoteTime
        self.totalVolume = totalVolume
        self.tradeTime = tradeTime
    }

    
}


