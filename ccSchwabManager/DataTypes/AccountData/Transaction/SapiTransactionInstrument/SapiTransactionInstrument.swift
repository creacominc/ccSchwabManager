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

/**
   A SapiTransactionInstrument is received as the following JSON string:
 
 {
     "instrument": {
         "assetType": "EQUITY",
         "status": "ACTIVE",
         "symbol": "SFM",
         "instrumentId": 1806651,
         "closingPrice": 169.76,
         "type": "COMMON_STOCK"
     }
 }

 
 */


public class SapiTransactionInstrument: Codable
{
    
    public var instrument : SapiTransactionEquity

    enum CodingKeys: String, CodingKey
    {
        case instrument = "instrument"
    }

    // Initializer
    public init(
        instrument : SapiTransactionEquity
    )
    {
        self.instrument = instrument
    }

}


