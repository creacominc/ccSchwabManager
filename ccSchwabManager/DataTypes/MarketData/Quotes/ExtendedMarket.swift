//
//  SapiExtended.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-11.
//

import Foundation

//@Model
public struct ExtendedMarket : Codable
{

//    init(m_askPrice: Double, m_askSize: Int, m_bidPrice: Double, m_bidSize: Int, m_lastPrice: Double, m_lastSize: Int, m_mark: Double, m_quoteTime: Int, m_totalVolume: Int, m_tradeTime: Int)
//    {
//        self.m_askPrice = m_askPrice
//        self.m_askSize = m_askSize
//        self.m_bidPrice = m_bidPrice
//        self.m_bidSize = m_bidSize
//        self.m_lastPrice = m_lastPrice
//        self.m_lastSize = m_lastSize
//        self.m_mark = m_mark
//        self.m_quoteTime = m_quoteTime
//        self.m_totalVolume = m_totalVolume
//        self.m_tradeTime = m_tradeTime
//    }

    private var m_askPrice: Double = 0.0
    private var m_askSize: Int = 0
    private var m_bidPrice: Double = 0.0
    private var m_bidSize: Int = 0
    private var m_lastPrice: Double = 0.0
    private var m_lastSize: Int = 0
    private var m_mark: Double = 0.0
    private var m_quoteTime: Int = 0
    private var m_totalVolume: Int = 0
    private var m_tradeTime: Int = 0

}

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


