//
//  SapiTransactionInstrumentTests.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-29.
//


import Testing
import Foundation
@testable import ccSchwabManager

struct SapiTransactionInstrumentTests
{
    
    @Test func testEncodingSapiTransactionInstrument() throws
    {
        // create the SapiTransactionEquity object to be contained
        let equityDetails = SapiTransactionEquity(
            assetType: .EQUITY,
            symbol: "SFM",
            instrumentId: 1806651,
            type: .COMMON_STOCK,
            status: .ACTIVE,
            closingPrice: 169.76
        )

        // create the SapiTransactionInstrument object which is a SapiTransactionEquity object.
        var instrument : SapiTransactionInstrument!
        switch equityDetails.assetType {
        case .EQUITY:
            instrument = try .init(from: equityDetails)
        case .OPTION:
            fallthrough
        case .INDEX:
            fallthrough
        case .MUTUAL_FUND:
            fallthrough
        case .CASH_EQUIVALENT:
            fallthrough
        case .FIXED_INCOME:
            fallthrough
        case .CURRENCY:
            fallthrough
        case .COLLECTIVE_INVESTMENT:
            fallthrough
        case .FUTURE:
            fallthrough
        case .FOREX:
            fallthrough
        case .PRODUCT:
            fallthrough
        @unknown default:
            fatalError("Unsupported asset type \(equityDetails.assetType)")
        }

//        let instrument : SapiTransactionInstrument = SapiTransactionInstrument(
//            instrumentType: .equity,
//            details: equityDetails
//        )
        
        // Assuming these are additional properties in SapiTransactionInstrument
        let amount = 3.0
        let cost = -501.9
        let price = 167.3
        let positionEffect = "OPENING"
        
        // Act
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(instrument)
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        // Assert
        #expect( nil != jsonString, "Encoded JSON string should not be nil")
        print("Encoded JSON:\n\(jsonString ?? "Nil")")
    }
//    
//    @Test func testDecodingSapiTransactionInstrument() throws {
//        // Arrange
//        let jsonString = """
//            {
//                "instrument": {
//                    "assetType": "EQUITY",
//                    "status": "ACTIVE",
//                    "symbol": "SFM",
//                    "instrumentId": 1806651,
//                    "closingPrice": 169.76,
//                    "type": "COMMON_STOCK"
//                },
//                "amount": 3.0,
//                "cost": -501.9,
//                "price": 167.3,
//                "positionEffect": "OPENING"
//            }
//            """
//        let jsonData = jsonString.data(using: .utf8)!
//        let decoder = JSONDecoder()
//        
//        // Act
//        let decodedInstrument : SapiTransactionInstrument = try decoder.decode(SapiTransactionInstrument.self, from: jsonData)
//        
//        // Assert
//        XCTAssertEqual(decodedInstrument.details?.symbol, "SFM", "The symbol should be 'SFM'")
//        XCTAssertEqual(decodedInstrument.details?.closingPrice, 169.76, "The closing price should be 169.76")
//        XCTAssertEqual(decodedInstrument.details?.type, .COMMON_STOCK, "The type should be .COMMON_STOCK")
//        XCTAssertEqual(decodedInstrument.amount, 3.0, "The amount should be 3.0")
//        XCTAssertEqual(decodedInstrument.cost, -501.9, "The cost should be -501.9")
//        XCTAssertEqual(decodedInstrument.price, 167.3, "The price should be 167.3")
//        XCTAssertEqual(decodedInstrument.positionEffect, "OPENING", "The positionEffect should be 'OPENING'")
//    }
//    
    
}
