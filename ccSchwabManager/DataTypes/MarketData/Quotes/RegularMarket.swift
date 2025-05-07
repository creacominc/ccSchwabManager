//
//  Regular.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-11.
//

import Foundation

public struct RegularMarket : Codable
{

//    init(m_regularMarketLastPrice: Double, m_regularMarketLastSize: Int, m_regularMarketNetChange: Double, m_regularMarketPercentChange: Double, m_regularMarketTradeTime: Int)
//    {
//        self.m_regularMarketLastPrice = m_regularMarketLastPrice
//        self.m_regularMarketLastSize = m_regularMarketLastSize
//        self.m_regularMarketNetChange = m_regularMarketNetChange
//        self.m_regularMarketPercentChange = m_regularMarketPercentChange
//        self.m_regularMarketTradeTime = m_regularMarketTradeTime
//    }

    private var m_regularMarketLastPrice: Double = 0.0
    private var m_regularMarketLastSize: Int = 0
    private var m_regularMarketNetChange: Double = 0.0
    private var m_regularMarketPercentChange: Double = 0.0
    private var m_regularMarketTradeTime: Int = 0

}

/**
 "regular": {
   "regularMarketLastPrice": 118.42,
   "regularMarketLastSize": 45019,
   "regularMarketNetChange": -3.25,
   "regularMarketPercentChange": -2.67115969,
   "regularMarketTradeTime": 1736553600002
 }
 */
