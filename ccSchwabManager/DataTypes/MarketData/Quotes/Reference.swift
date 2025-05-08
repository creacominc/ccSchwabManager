//
//  Reference.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-11.
//

import Foundation


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


class Reference : Codable, Identifiable
{
    public var cusip: String?
    public var description: String?
    public var exchange: String?
    public var exchangeName: String?
    public var fsiDesc: String?
    public var htbQuantity: Int?
    public var htbRate: Double?
    public var isHardToBorrow: Bool?
    public var isShortable: Bool?
    public var otcMarketTier: String?
    
    enum CodingKeys: String, CodingKey {
        case cusip = "cusip"
        case description = "description"
        case exchange = "exchange"
        case exchangeName = "exchangeName"
        case fsiDesc = "fsiDesc"
        case htbQuantity = "htbQuantity"
        case htbRate = "htbRate"
        case isHardToBorrow = "isHardToBorrow"
        case isShortable = "isShortable"
        case otcMarketTier = "otcMarketTier"
    }

    public init(cusip: String? = nil, description: String? = nil, exchange: String? = nil, exchangeName: String? = nil, fsiDesc: String? = nil, htbQuantity: Int? = nil, htbRate: Double? = nil, isHardToBorrow: Bool? = nil, isShortable: Bool? = nil, otcMarketTier: String? = nil)
    {
        self.cusip = cusip
        self.description = description
        self.exchange = exchange
        self.exchangeName = exchangeName
        self.fsiDesc = fsiDesc
        self.htbQuantity = htbQuantity
        self.htbRate = htbRate
        self.isHardToBorrow = isHardToBorrow
        self.isShortable = isShortable
        self.otcMarketTier = otcMarketTier
    }

    
    
}

