//
//  AccountApiOptionDeliverable.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 AccountAPIOptionDeliverable{
 symbol    [...]
 deliverableUnits    [...]
 apiCurrencyType    [...]
 assetType    assetTypestring
 Enum:
 [ EQUITY, MUTUAL_FUND, OPTION, FUTURE, FOREX, INDEX, CASH_EQUIVALENT, FIXED_INCOME, PRODUCT, CURRENCY, COLLECTIVE_INVESTMENT ]
 */

class AccountApiOptionDeliverable: Codable, Identifiable {
    var symbol: String?
    var deliverableUnits: Double?
    var apiCurrencyType: ApiCurrencyType?
    var assetType: AssetType?
    
    enum CodingKeys: String, CodingKey {
        case symbol = "symbol"
        case deliverableUnits = "deliverableUnits"
        case apiCurrencyType = "apiCurrencyType"
        case assetType = "assetType"
    }
    
    init(symbol: String? = nil, deliverableUnits: Double? = nil, apiCurrencyType: ApiCurrencyType? = nil, assetType: AssetType? = nil) {
        self.symbol = symbol
        self.deliverableUnits = deliverableUnits
        self.apiCurrencyType = apiCurrencyType
        self.assetType = assetType
    }
    
}
