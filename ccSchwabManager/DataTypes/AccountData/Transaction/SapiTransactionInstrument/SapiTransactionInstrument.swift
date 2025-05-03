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
 SapiCurrency{...}
 SapiTransactionEquity{...}
 SapiTransactionFixedIncome{...}
 SapiForex{...}
 SapiFuture{...}
 SapiIndex{...}
 SapiTransactionMutualFund{...}
 SapiTransactionOption{...}
 SapiProduct{...}

 }
 */


public class SapiTransactionInstrument: Codable
{
    public enum InstrumentType: String, Codable, CaseIterable
    {
        case cashEquivalent = "CASH_EQUIVALENT"
        case collectiveInvestment = "COLLECTIVE_INVESTMENT"
        case currency = "CURRENCY"
        case equity = "EQUITY"
        case fixedIncome = "FIXED_INCOME"
        case forex =    "FOREX"
        case future =   "FUTURE"
        case index =    "INDEX"
        case mutualFund = "MUTUAL_FUND"
        case option =    "OPTION"
        case product =    "PRODUCT"
    }

    public var instrumentType: InstrumentType
    public var details: Codable?

    enum CodingKeys: String, CodingKey
    {
        case instrumentType
        case details
    }


    required public init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instrumentType = try container.decode(InstrumentType.self, forKey: .instrumentType)

        // Decode `details` based on `instrumentType`
        switch instrumentType
        {
        case .cashEquivalent:
            details = try container.decode(SapiTiTransactionCashEquivalent.self, forKey: .details)
        case .collectiveInvestment:
            details = try container.decode(SapiTiCollectiveInvestment.self, forKey: .details)
        case .currency:
            details = try container.decode(SapiCurrency.self, forKey: .details)
        case .equity:
            details = try container.decode(SapiTransactionEquity.self, forKey: .details)
        case .fixedIncome:
            details = try container.decode(SapiTransactionFixedIncome.self, forKey: .details)
        case .forex:
            details = try container.decode(SapiForex.self, forKey: .details)
        case .future:
            details = try container.decode(SapiFuture.self, forKey: .details)
        case .index:
            details = try container.decode(SapiIndex.self, forKey: .details)
        case .mutualFund:
            details = try container.decode(SapiTransactionMutualFund.self, forKey: .details)
        case .option:
            details = try container.decode(SapiTransactionOption.self, forKey: .details)
        case .product:
            details = try container.decode(SapiProduct.self, forKey: .details)
//        default:
//            details = nil
        }
    }

    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instrumentType, forKey: .instrumentType)

        // Encode `details` dynamically
        if let details = details as? SapiTiTransactionCashEquivalent
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiTiCollectiveInvestment
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiCurrency
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiTransactionEquity
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiTransactionFixedIncome
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiForex
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiFuture
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiIndex
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiTransactionMutualFund
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiTransactionOption
        {
            try container.encode(details, forKey: .details)
        }
        else if let details = details as? SapiProduct
        {
            try container.encode(details, forKey: .details)
        }

    }
}

