//
//  SapiTransactionEquityTests.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-29.
//


import Testing
import Foundation
@testable import ccSchwabManager

struct SapiTransactionEquityTests
{

        @Test func testEncodingSapiTransactionEquity() throws
        {
            // Arrange
            let equity = SapiTransactionEquity(
                assetType: .EQUITY,
                status: .ACTIVE,
                symbol: "SFM",
                instrumentId: 1806651,
                closingPrice: 169.76,
                type: .COMMON_STOCK,
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
            // Act
            let jsonData : Data = try encoder.encode(equity)
            let jsonString = String(data: jsonData, encoding: .utf8)
    
            // Assert
            #expect( nil != jsonString, "Encoded JSON string should not be nil" )
            //        print( "Encoded JSON:\n\(jsonString!)" )
            #expect( jsonString?.contains( "\"symbol\" : \"SFM\"" ) ?? false, "JSON string should contain the symbol 'SFM'" )
            #expect( jsonString?.contains( "\"closingPrice\" : 169.76" ) ?? false, "JSON string should contain the closingPrice 169.76" )
        }

    @Test func testDecodingSapiTransactionEquity() throws
    {
        // Arrange
        let jsonString = """
        {
            "assetType": "EQUITY",
            "status": "ACTIVE",
            "symbol": "SFM",
            "instrumentId": 1806651,
            "closingPrice": 169.76,
            "type": "COMMON_STOCK"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()

        // Act
        let decodedEquity = try decoder.decode(SapiTransactionEquity.self, from: jsonData)

        // Assert
        #expect(decodedEquity.assetType == .EQUITY, "Asset type should be .EQUITY")
        #expect(decodedEquity.status == .ACTIVE, "Status should be .ACTIVE")
        #expect(decodedEquity.symbol == "SFM", "Symbol should be 'SFM'")
        #expect(decodedEquity.instrumentId == 1806651, "Instrument ID should be 1806651")
        #expect(decodedEquity.closingPrice == 169.76, "Closing price should be 169.76")
        #expect(decodedEquity.type == .COMMON_STOCK, "Type should be .COMMON_STOCK")
    }

}
