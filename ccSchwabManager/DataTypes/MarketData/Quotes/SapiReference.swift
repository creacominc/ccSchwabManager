//
//  Reference.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-11.
//

import Foundation
//import SwiftData

//@Model
//public class SapiReference
public struct SapiReference : Codable
{

//    init(m_cusip: String, m_description: String, m_exchange: String, m_exchangeName: String, m_fsiDesc: String, m_htbQuantity: Int, m_htbRate: Double, m_isHardToBorrow: Bool, m_isShortable: Bool, m_otcMarketTier: String)
//    {
//        self.m_cusip = m_cusip
//        self.m_description = m_description
//        self.m_exchange = m_exchange
//        self.m_exchangeName = m_exchangeName
//        self.m_fsiDesc = m_fsiDesc
//        self.m_htbQuantity = m_htbQuantity
//        self.m_htbRate = m_htbRate
//        self.m_isHardToBorrow = m_isHardToBorrow
//        self.m_isShortable = m_isShortable
//        self.m_otcMarketTier = m_otcMarketTier
//    }

    private var m_cusip: String = ""
    private var m_description: String = ""
    private var m_exchange: String = ""
    private var m_exchangeName: String = ""
    private var m_fsiDesc: String = ""
    private var m_htbQuantity: Int = 0
    private var m_htbRate: Double = 0.0
    private var m_isHardToBorrow: Bool = false
    private var m_isShortable: Bool = false
    private var m_otcMarketTier: String = ""

}


/**
 "reference": {
   "cusip": "780087102",
   "description": "Royal Bank of Canada",
   "exchange": "N",
   "exchangeName": "NYSE",
   "isHardToBorrow": true,
   "isShortable": true,
   "htbRate": 0
 },
 */
