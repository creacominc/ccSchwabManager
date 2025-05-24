//
//  AccountInstrument.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 AccountsInstrument{
oneOf ->
AccountCashEquivalent{
assetType*    [...]
cusip    [...]
symbol    [...]
description    [...]
instrumentId    [...]
netChange    [...]
type    [...]
}
AccountEquity{
assetType*    [...]
cusip    [...]
symbol    [...]
description    [...]
instrumentId    [...]
netChange    [...]
}
AccountFixedIncome{
assetType*    [...]
cusip    [...]
symbol    [...]
description    [...]
instrumentId    [...]
netChange    [...]
maturityDate    [...]
factor    [...]
variableRate    [...]
}
AccountMutualFund{
assetType*    [...]
cusip    [...]
symbol    [...]
description    [...]
instrumentId    [...]
netChange    [...]
}
AccountOption{
assetType*    [...]
cusip    [...]
symbol    [...]
description    [...]
instrumentId    [...]
netChange    [...]
optionDeliverables    [...]
putCall    [...]
optionMultiplier    [...]
type    [...]
underlyingSymbol    [...]
}
}
 */

class AccountsInstrument: Codable, Identifiable {
    var assetType: AssetType?
    var cusip: String?
    var symbol: String?
    var description: String?
    var instrumentId: Int64?
    var netChange: Double?
    var type: InstrumentType?
    var maturityDate: String?
    var factor: Double?
    var variableRate: Double?
    var optionDeliverables: [AccountApiOptionDeliverable]?
    var putCall: PutCallType?
    var optionMultiplier: Int32?
    var underlyingSymbol: String?
    
    enum CodingKeys: String, CodingKey {
        case assetType = "assetType"
        case cusip = "cusip"
        case symbol = "symbol"
        case description = "description"
        case instrumentId = "instrumentId"
        case netChange = "netChange"
        case type = "type"
        case maturityDate = "maturityDate"
        case factor = "factor"
        case variableRate = "variableRate"
        case optionDeliverables = "optionDeliverables"
        case putCall = "putCall"
        case optionMultiplier = "optionMultiplier"
        case underlyingSymbol = "underlyingSymbol"
    }
    
    init(assetType: AssetType? = nil, cusip: String? = nil, symbol: String? = nil, description: String? = nil, instrumentId: Int64? = nil, netChange: Double? = nil, type: InstrumentType? = nil, maturityDate: String? = nil, factor: Double? = nil, variableRate: Double? = nil, optionDeliverables: [AccountApiOptionDeliverable]? = nil, putCall: PutCallType? = nil, optionMultiplier: Int32? = nil, underlyingSymbol: String? = nil) {
        self.assetType = assetType
        self.cusip = cusip
        self.symbol = symbol
        self.description = description
        self.instrumentId = instrumentId
        self.netChange = netChange
        self.type = type
        self.maturityDate = maturityDate
        self.factor = factor
        self.variableRate = variableRate
        self.optionDeliverables = optionDeliverables
        self.putCall = putCall
        self.optionMultiplier = optionMultiplier
        self.underlyingSymbol = underlyingSymbol
    }
}
