//
//  SapiTransactionInstrument.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//



import Foundation

/**
 SapiTransactionInstrument{
 oneOf ->

 SapiTiTransactionCashEquivalent{...}
 SapiTiCollectiveInvestment{...}
 SapiTiCurrency{...}
 SapiTiTransactionEquity{...}
 SapiTiTransactionFixedIncome{...}
 SapiTiForex{...}
 SapiTiFuture{...}
 SapiTiIndex{...}
 SapiTiTransactionMutualFund{...}
 SapiTiTransactionOption{...}
 SapiTiProduct{...}

 }
 */



public class SapiTransactionInstrument: Codable
{
    public enum InstrumentType: String, Codable {
        case cashEquivalent, collectiveInvestment, currency, equity, fixedIncome, forex, future, index, mutualFund, option, product
    }

    public var instrumentType: InstrumentType?
    public var details: Codable?

    enum CodingKeys: String, CodingKey {
        case instrumentType, details
    }

    required public init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instrumentType = try container.decodeIfPresent(InstrumentType.self, forKey: .instrumentType)

        // Decode `details` based on `instrumentType`
        switch instrumentType {
        case .cashEquivalent:
            details = try container.decode(SapiTiTransactionCashEquivalent.self, forKey: .details)
        case .collectiveInvestment:
            details = try container.decode(SapiTiCollectiveInvestment.self, forKey: .details)
        // Add other cases here...
        default:
            break
        }
    }
}
