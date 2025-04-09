//
//  Quote.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-11.
//

import Foundation
//import SwiftData

//@Model
//public class SapiQuote
public struct SapiQuote : Decodable
{

//    init(m_52WeekHigh: Double, m_52WeekLow: Double, m_askMICId: String, m_askPrice: Double, m_askSize: Int, m_askTime: Int, m_bidMICId: String, m_bidPrice: Double, m_bidSize: Int, m_bidTime: Int, m_closePrice: Double, m_highPrice: Double, m_lastMICId: String, m_lastPrice: Double, m_lastSize: Int, m_lowPrice: Double, m_mark: Double, m_markChange: Double, m_markPercentChange: Double, m_netChange: Double, m_netPercentChange: Double, m_openPrice: Double, m_postMarketChange: Double, m_postMarketPercentChange: Double, m_quoteTime: Int, m_securityStatus: String, m_totalVolume: Int, m_tradeTime: Int, m_volatility: Double)
//    {
//        self.m_52WeekHigh = m_52WeekHigh
//        self.m_52WeekLow = m_52WeekLow
//        self.m_askMICId = m_askMICId
//        self.m_askPrice = m_askPrice
//        self.m_askSize = m_askSize
//        self.m_askTime = m_askTime
//        self.m_bidMICId = m_bidMICId
//        self.m_bidPrice = m_bidPrice
//        self.m_bidSize = m_bidSize
//        self.m_bidTime = m_bidTime
//        self.m_closePrice = m_closePrice
//        self.m_highPrice = m_highPrice
//        self.m_lastMICId = m_lastMICId
//        self.m_lastPrice = m_lastPrice
//        self.m_lastSize = m_lastSize
//        self.m_lowPrice = m_lowPrice
//        self.m_mark = m_mark
//        self.m_markChange = m_markChange
//        self.m_markPercentChange = m_markPercentChange
//        self.m_netChange = m_netChange
//        self.m_netPercentChange = m_netPercentChange
//        self.m_openPrice = m_openPrice
//        self.m_postMarketChange = m_postMarketChange
//        self.m_postMarketPercentChange = m_postMarketPercentChange
//        self.m_quoteTime = m_quoteTime
//        self.m_securityStatus = m_securityStatus
//        self.m_totalVolume = m_totalVolume
//        self.m_tradeTime = m_tradeTime
//        self.m_volatility = m_volatility
//    }

    private var m_52WeekHigh: Double = 0.0
    private var m_52WeekLow: Double = 0.0
    private var m_askMICId: String = ""
    private var m_askPrice: Double = 0.0
    private var m_askSize: Int = 0
    private var m_askTime: Int = 0
    private var m_bidMICId: String = ""
    private var m_bidPrice: Double = 0.0
    private var m_bidSize: Int = 0
    private var m_bidTime: Int = 0
    private var m_closePrice: Double = 0.0
    private var m_highPrice: Double = 0.0
    private var m_lastMICId: String = ""
    private var m_lastPrice: Double = 0.0
    private var m_lastSize: Int = 0
    private var m_lowPrice: Double = 0.0
    private var m_mark: Double = 0.0
    private var m_markChange: Double = 0.0
    private var m_markPercentChange: Double = 0.0
    private var m_netChange: Double = 0.0
    private var m_netPercentChange: Double = 0.0
    private var m_openPrice: Double = 0.0
    private var m_postMarketChange: Double = 0.0
    private var m_postMarketPercentChange: Double = 0.0
    private var m_quoteTime: Int = 0
    private var m_securityStatus: String = ""
    private var m_totalVolume: Int = 0
    private var m_tradeTime: Int = 0
    private var m_volatility: Double = 0.0
}



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


