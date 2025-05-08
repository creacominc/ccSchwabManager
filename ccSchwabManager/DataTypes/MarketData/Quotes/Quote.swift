//
//  Quote.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-11.
//

import Foundation



/**
 "quote": {
   "52WeekHigh": 128.05,
   "52WeekLow": 93.97,
   "askMICId": "ARCX",
   "askPrice": 127,
   "askSize": 1,
   "askTime": 1736557200182,
   "bidMICId": "ARCX",
   "bidPrice": 82.27,
   "bidSize": 1,
   "bidTime": 1736546065711,
   "closePrice": 121.67,
   "highPrice": 121.04,
   "lastMICId": "XNYS",
   "lastPrice": 118.09,
   "lastSize": 1,
   "lowPrice": 118.04,
   "mark": 118.42,
   "markChange": -3.25,
   "markPercentChange": -2.67115969,
   "netChange": -3.58,
   "netPercentChange": -2.94238514,
   "openPrice": 121,
   "postMarketChange": -0.33,
   "postMarketPercentChange": -0.27866914,
   "quoteTime": 1736557200182,
   "securityStatus": "Normal",
   "totalVolume": 731188,
   "tradeTime": 1736553588366
 },
 */



class Quote : Codable, Identifiable
{
    public var m52WeekHigh: Double?
    public var m52WeekLow: Double?
    public var askMICId: String?
    public var askPrice: Double?
    public var askSize: Int?
    public var askTime: Int?
    public var bidMICId: String?
    public var bidPrice: Double?
    public var bidSize: Int?
    public var bidTime: Int?
    public var closePrice: Double?
    public var highPrice: Double?
    public var lastMICId: String?
    public var lastPrice: Double?
    public var lastSize: Int?
    public var lowPrice: Double?
    public var mark: Double?
    public var markChange: Double?
    public var markPercentChange: Double?
    public var netChange: Double?
    public var netPercentChange: Double?
    public var openPrice: Double?
    public var postMarketChange: Double?
    public var postMarketPercentChange: Double?
    public var quoteTime: Int?
    public var securityStatus: String?
    public var totalVolume: Int?
    public var tradeTime: Int?
    public var volatility: Double?
    
    enum CodingKeys: String, CodingKey
    {
        case m52WeekHigh = "52WeekHigh"
        case m52WeekLow = "52WeekLow"
        case askMICId = "askMICId"
        case askPrice = "askPrice"
        case askSize = "askSize"
        case askTime = "askTime"
        case bidMICId = "bidMICId"
        case bidPrice = "bidPrice"
        case bidSize = "bidSize"
        case bidTime = "bidTime"
        case closePrice = "closePrice"
        case highPrice = "highPrice"
        case lastMICId = "lastMICId"
        case lastPrice = "lastPrice"
        case lastSize = "lastSize"
        case lowPrice = "lowPrice"
        case mark = "mark"
        case markChange = "markChange"
        case markPercentChange = "markPercentChange"
        case netChange = "netChange"
        case netPercentChange = "netPercentChange"
        case openPrice = "openPrice"
        case postMarketChange = "postMarketChange"
        case postMarketPercentChange = "postMarketPercentChange"
        case quoteTime = "quoteTime"
        case securityStatus = "securityStatus"
        case totalVolume = "totalVolume"
        case tradeTime = "tradeTime"
        case volatility = "volatility"
    }


    public init(m52WeekHigh: Double? = nil, m52WeekLow: Double? = nil, askMICId: String? = nil, askPrice: Double? = nil, askSize: Int? = nil, askTime: Int? = nil, bidMICId: String? = nil, bidPrice: Double? = nil, bidSize: Int? = nil, bidTime: Int? = nil, closePrice: Double? = nil, highPrice: Double? = nil, lastMICId: String? = nil, lastPrice: Double? = nil, lastSize: Int? = nil, lowPrice: Double? = nil, mark: Double? = nil, markChange: Double? = nil, markPercentChange: Double? = nil, netChange: Double? = nil, netPercentChange: Double? = nil, openPrice: Double? = nil, postMarketChange: Double? = nil, postMarketPercentChange: Double? = nil, quoteTime: Int? = nil, securityStatus: String? = nil, totalVolume: Int? = nil, tradeTime: Int? = nil, volatility: Double? = nil)
    {
        self.m52WeekHigh = m52WeekHigh
        self.m52WeekLow = m52WeekLow
        self.askMICId = askMICId
        self.askPrice = askPrice
        self.askSize = askSize
        self.askTime = askTime
        self.bidMICId = bidMICId
        self.bidPrice = bidPrice
        self.bidSize = bidSize
        self.bidTime = bidTime
        self.closePrice = closePrice
        self.highPrice = highPrice
        self.lastMICId = lastMICId
        self.lastPrice = lastPrice
        self.lastSize = lastSize
        self.lowPrice = lowPrice
        self.mark = mark
        self.markChange = markChange
        self.markPercentChange = markPercentChange
        self.netChange = netChange
        self.netPercentChange = netPercentChange
        self.openPrice = openPrice
        self.postMarketChange = postMarketChange
        self.postMarketPercentChange = postMarketPercentChange
        self.quoteTime = quoteTime
        self.securityStatus = securityStatus
        self.totalVolume = totalVolume
        self.tradeTime = tradeTime
        self.volatility = volatility
    }

}



