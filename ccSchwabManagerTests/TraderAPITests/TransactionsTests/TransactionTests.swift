//
//  TransactionTests.swift
//

import Testing
import Foundation
@testable import ccSchwabManager

/**
 *
 *[
 {
   "activityId": 95512265692,
   "time": "2025-04-23T19:59:12+0000",
   "accountNumber": "...767",
   "type": "TRADE",
   "status": "VALID",
   "subAccount": "CASH",
   "tradeDate": "2025-04-23T19:59:12+0000",
   "positionId": 2788793997,
   "orderId": 1003188442747,
   "netAmount": -164.85,
   "transferItems": [
     {
       "instrument": {
         "assetType": "EQUITY",
         "status": "ACTIVE",
         "symbol": "SFM",
         "instrumentId": 1806651,
         "closingPrice": 169.76,
         "type": "COMMON_STOCK"
       },
       "amount": 1,
       "cost": -164.85,
       "price": 164.85,
       "positionEffect": "OPENING"
     }
   ]
 }
]
 *

 */

struct TransactionTests
{
    
    @Test func testEncodingTransactionTests() throws
    {
        let userDetails : UserDetails = UserDetails(cdDomainId: "domainId", login: "login",
                                                    type: .ADVISOR_USER,
                                                    userId: 12345, systemUserName: "systemUserName",
                                                    firstName: "firstName", lastName: "lastName",
                                                    brokerRepCode: "brokenCode"
        )
        let instrument : Instrument = Instrument( assetType: .EQUITY,
                                                  symbol: "SFM",
                                                  instrumentId: 12345,
                                                  status: .ACTIVE,
                                                  closingPrice: 128.42,
                                                  type: .COMMON_STOCK
        )
        let transferItem : TransferItem = TransferItem( instrument: instrument,
                                                        amount: 42.42,
                                                        cost: 4.24,
                                                        price: 42.24,
                                                        positionEffect: .OPENING
        )



        let testData : Transaction = Transaction(
                                    activityId: 123456789,
                                    time: "2025-04-23T19:59:12+0000",
                                    user: userDetails,
                                    accountNumber: "...767",
                                    type: .trade,
                                    status: .VALID,
                                    subAccount: .CASH,
                                    tradeDate: "2025-04-23T19:59:12+0000",
                                    positionId: 2788793997,
                                    orderId: 1003188442747,
                                    netAmount: -164.85,
                                    transferItems: [ transferItem ]
                                )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Act
        let jsonData = try encoder.encode( testData )
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Assert
        #expect( nil != jsonString, "Encoded JSON string should not be nil")
        print("Encoded JSON:\n\(jsonString ?? "Nil")")

        // verify
        #expect( jsonString?.contains("\"activityId\" : 123456789") ?? false, "activityId failed" )
        #expect( jsonString?.contains("\"type\" : \"TRADE\"") ?? false, "type failed" )
        #expect( jsonString?.contains("\"status\" : \"VALID\"") ?? false, "status failed" )
        #expect( jsonString?.contains("\"subAccount\" : \"CASH\"") ?? false, "subAccount failed" )

    }


    @Test func testDecodingTransactionTests() throws
    {
        // Arrange
        let jsonString = """
        {
          "activityId": 95512265692,
          "time": "2025-04-23T19:59:12+0000",
          "accountNumber": "...767",
          "type": "TRADE",
          "status": "VALID",
          "subAccount": "CASH",
          "tradeDate": "2025-04-23T19:59:12+0000",
          "positionId": 2788793997,
          "orderId": 1003188442747,
          "netAmount": -164.85,
          "transferItems": [
            {
              "instrument": {
                "assetType": "EQUITY",
                "status": "ACTIVE",
                "symbol": "SFM",
                "instrumentId": 1806651,
                "closingPrice": 169.76,
                "type": "COMMON_STOCK"
              },
              "amount": 1,
              "cost": -164.85,
              "price": 164.85,
              "positionEffect": "OPENING"
            }
          ]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()

        // Act
        let decodedEquity = try decoder.decode(Transaction.self, from: jsonData)

        // Assert
        #expect( decodedEquity.activityId    == 95512265692, "Activity ID should be 95512265692" )
        #expect( decodedEquity.time == "2025-04-23T19:59:12+0000", "Time should be 2025-04-23T19:59:12+0000")
        #expect( decodedEquity.accountNumber == "...767", "Account number should be ...767" )
        #expect( decodedEquity.type == TransactionType.trade, "Transaction type should be TRADE" )
        #expect( decodedEquity.status == TransactionStatus.VALID, "Status should be VALID" )
        #expect( decodedEquity.subAccount    == .CASH, "Sub account should be CASH" )
        #expect( decodedEquity.tradeDate == "2025-04-23T19:59:12+0000", "Trade date should be 2025-04-23T19:59:12+0000" )
        #expect( decodedEquity.orderId == 1003188442747, "Order ID should be 1003188442747" )
        #expect( decodedEquity.netAmount == -164.85, "Net amount should be -164.85" )
        #expect( decodedEquity.transferItems.count == 1, "Transfer items count should be 1" )
        #expect( decodedEquity.transferItems[0].amount == 1, "Transfer item amount should be 1" )
        #expect( decodedEquity.transferItems[0].cost == -164.85, "Transfer item cost should be -164.85" )
        #expect( decodedEquity.transferItems[0].price == 164.85, "Transfer item price should be 164.85" )
        #expect( decodedEquity.transferItems[0].instrument?.symbol == "SFM", "Transfer item symbol should be SFM" )

    }





}



