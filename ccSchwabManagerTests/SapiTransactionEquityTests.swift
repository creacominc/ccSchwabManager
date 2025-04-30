//
//  SapiTransactionEquityTests.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-29.
//


import XCTest
@testable import ccSchwabManager

final class SapiTransactionEquityTests: XCTestCase {

    func testEncodingSapiTransactionEquity() throws {
        // Arrange
        let equity = SapiTransactionEquity(
            assetType: .EQUITY,
            symbol: "SFM",
            instrumentId: 1806651,
            type: .COMMON_STOCK,
            status: .ACTIVE,
            closingPrice: 169.76
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        // Act
        let jsonData = try encoder.encode(equity)
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Assert
        XCTAssertNotNil(jsonString, "Encoded JSON string should not be nil")
        print("Encoded JSON:\n\(jsonString!)")
    }

    func testDecodingSapiTransactionEquity() throws {
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
        XCTAssertEqual(decodedEquity.assetType, .EQUITY, "Asset type should be .EQUITY")
        XCTAssertEqual(decodedEquity.status, .ACTIVE, "Status should be .ACTIVE")
        XCTAssertEqual(decodedEquity.symbol, "SFM", "Symbol should be 'SFM'")
        XCTAssertEqual(decodedEquity.instrumentId, 1806651, "Instrument ID should be 1806651")
        XCTAssertEqual(decodedEquity.closingPrice, 169.76, "Closing price should be 169.76")
        XCTAssertEqual(decodedEquity.type, .COMMON_STOCK, "Type should be .COMMON_STOCK")
    }
}