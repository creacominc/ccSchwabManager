//
//  BalanceTests.swift
//

import Testing
import Foundation
@testable import ccSchwabManager

/**
 
 {
    "accruedInterest":0.0,
    "cashAvailableForTrading":38429.41,
    "cashAvailableForWithdrawal":38429.41,
    "cashBalance":38429.41,
    "bondValue":0.0,
    "cashReceipts":0.0,
    "liquidationValue":425403.66,
    "longOptionMarketValue":0.0,
    "longStockValue":387454.36,
    "moneyMarketFund":0.0,
    "mutualFundValue":38429.41,
    "shortOptionMarketValue":-480.11,
    "shortStockValue":-480.11,
    "isInCall":false,
    "unsettledCash":0.0,
    "cashDebitCallValue":0.0,
    "pendingDeposits":0.0,
    "accountValue":425403.66
 }
 
 {
    "accruedInterest":0.0,
    "cashBalance":38429.41,
    "cashReceipts":0.0,
    "longOptionMarketValue":0.0,
    "liquidationValue":425187.77,
    "longMarketValue":343441.09,
    "moneyMarketFund":0.0,
    "savings":0.0,
    "shortMarketValue":0.0,
    "pendingDeposits":0.0,
    "mutualFundValue":0.0,
    "bondValue":44013.27,
    "shortOptionMarketValue":-696.0,
    "cashAvailableForTrading":38429.41,
    "cashAvailableForWithdrawal":38429.41,
    "cashCall":0.0,
    "longNonMarginableMarketValue":38429.41,
    "totalCash":38429.41,
    "cashDebitCallValue":0.0,
    "unsettledCash":0.0
 }

 {
 "cashAvailableForTrading":5139.61,
 "cashAvailableForWithdrawal":5139.61
}

 */


struct BalanceTests
{
    
    @Test func testEncodingCashBalance() throws
    {
        let cashBalance : Balance = .init( cashAvailableForTrading: 5139.61,
                                           cashAvailableForWithdrawal: 39.61 )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [ .prettyPrinted, .sortedKeys ]

        // encode
        let jsonData : Data = try encoder.encode( cashBalance )
        let jsonString : String = String( data: jsonData, encoding: .utf8 ) ?? ""

        let expectedString : String = """
            {
              "cashAvailableForTrading" : 5139.61,
              "cashAvailableForWithdrawal" : 39.61
            }
            """
        #expect( jsonString == expectedString )
    }

    @Test func testDecodingCashBalance() throws
    {
        let jsonString : String = """
            {
              "cashAvailableForTrading" : 5139.61,
              "cashAvailableForWithdrawal" : 39.61
            }
            """
        let decoder = JSONDecoder()

        let jsonData : Data = jsonString.data( using: .utf8 ) ?? Data()
        let cashBalance : Balance = try decoder.decode( Balance.self, from: jsonData )
        
        #expect( cashBalance.cashAvailableForTrading == 5139.61 )
        #expect( cashBalance.cashAvailableForWithdrawal == 39.61 )
    }

    /**
     InitialBalance :
     {
        "accruedInterest":0.01,
        "cashAvailableForTrading":38429.41,
        "cashAvailableForWithdrawal":38429.41,
        "cashBalance":38429.41,
        "bondValue":0.0,
        "cashReceipts":0.0,
        "liquidationValue":425403.66,
        "longOptionMarketValue":0.0,
        "longStockValue":387454.36,
        "moneyMarketFund":0.0,
        "mutualFundValue":38429.41,
        "shortOptionMarketValue":-480.11,
        "shortStockValue":-480.11,
        "isInCall":false,
        "unsettledCash":0.0,
        "cashDebitCallValue":0.0,
        "pendingDeposits":0.0,
        "accountValue":425403.66
     }
     */
    @Test func testEncodingInitialBalance() throws
    {
        let initialBalance : Balance = .init(
            cashAvailableForTrading: 38429.41,
            cashAvailableForWithdrawal: 38429.41,
            accruedInterest: 0.01,
            cashBalance: 38429.41,
            bondValue: 0.0,
            cashReceipts: 0.0,
            liquidationValue: 425403.66,
            longOptionMarketValue: 0.0,
            accountValue: 425403.66
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [ .prettyPrinted, .sortedKeys ]
        
        let jsonData : Data = try encoder.encode( initialBalance )
        let jsonString : String = String( data: jsonData, encoding: .utf8 ) ?? ""

        let expectedString : String = """
            {
              "accountValue" : 425403.66,
              "accruedInterest" : 0.01,
              "bondValue" : 0,
              "cashAvailableForTrading" : 38429.41,
              "cashAvailableForWithdrawal" : 38429.41,
              "cashBalance" : 38429.41,
              "cashReceipts" : 0,
              "liquidationValue" : 425403.66,
              "longOptionMarketValue" : 0
            }
            """
        #expect( jsonString == expectedString )
    }


    /**
     InitialBalance :
     {
        "accruedInterest":0.01,
        "cashAvailableForTrading":38429.41,
        "cashAvailableForWithdrawal":38429.41,
        "cashBalance":38429.41,
        "bondValue":0.0,
        "cashReceipts":0.0,
        "liquidationValue":425403.66,
        "longOptionMarketValue":0.0,
        "longStockValue":387454.36,
        "moneyMarketFund":0.0,
        "mutualFundValue":38429.41,
        "shortOptionMarketValue":-480.11,
        "shortStockValue":-480.11,
        "isInCall":false,
        "unsettledCash":0.0,
        "cashDebitCallValue":0.0,
        "pendingDeposits":0.0,
        "accountValue":425403.66
     }
     */
    @Test func testDecodingInitialBalance() throws
    {
        let jsonString : String = """
            {
               "accruedInterest":0.01,
               "cashAvailableForTrading":38429.41,
               "cashAvailableForWithdrawal":38429.41,
               "cashBalance":38429.41,
               "bondValue":0.0,
               "cashReceipts":0.0,
               "liquidationValue":425403.66,
               "longOptionMarketValue":0.0,
               "longStockValue":387454.36,
               "moneyMarketFund":0.0,
               "mutualFundValue":38429.41,
               "shortOptionMarketValue":-480.11,
               "shortStockValue":-480.11,
               "isInCall":false,
               "unsettledCash":0.0,
               "cashDebitCallValue":0.0,
               "pendingDeposits":0.0,
               "accountValue":425403.66
            }
            """
        let decoder = JSONDecoder()

        let initialBalance : Balance = try decoder.decode(Balance.self, from: jsonString.data(using: .utf8)!)
        #expect( initialBalance.accountValue == 425403.66 )
        #expect( initialBalance.cashAvailableForTrading == 38429.41 )

    }

}
