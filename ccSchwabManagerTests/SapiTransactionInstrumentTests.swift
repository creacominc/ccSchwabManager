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
        let equityDetails : SapiTransactionEquity = SapiTransactionEquity(
            assetType: .EQUITY,
            status: .ACTIVE,
            symbol: "SFM",
            instrumentId: 1806651,
            closingPrice: 169.76,
            type: .COMMON_STOCK
        )
        let instrument : SapiTransactionInstrument = .init(instrument: equityDetails)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Act
        let jsonData = try encoder.encode(instrument)
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Assert
        #expect( nil != jsonString, "Encoded JSON string should not be nil")
        print("Encoded JSON:\n\(jsonString ?? "Nil")")
        
        // test the contents of the details
        #expect( jsonString?.contains( "\"instrument\" : {" ) ?? false, "The JSON does not contain the expected opening brace for the instrument object" )
        #expect( jsonString?.contains( "\"assetType\" : \"EQUITY\"" ) ?? false , "The assetType property does not match")
        #expect( jsonString?.contains( "\"symbol\" : \"SFM\"" ) ?? false ,  "The symbol property does not match")
        #expect( jsonString?.contains( "\"instrumentId\" : 1806651" ) ?? false ,  "The instrumentId property does not match")
        #expect( jsonString?.contains( "\"type\" : \"COMMON_STOCK\"" ) ?? false ,  "The type property does not match")
        #expect( jsonString?.contains( "\"status\" : \"ACTIVE\"" ) ?? false ,  "The status property does not match")
        #expect( jsonString?.contains( "\"closingPrice\" : 169.76" ) ?? false ,  "The closingPrice property does not match")

    }

    
    @Test func testDecodingSapiTransactionInstrument() throws
    {
        // Arrange
        let jsonString = """
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
            """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // Act
        let decodedInstrument : SapiTransactionInstrument = try decoder.decode(SapiTransactionInstrument.self, from: jsonData)
        print( "decodedInstrument = \(decodedInstrument)" )
        #expect( AssetType.EQUITY == decodedInstrument.instrument.assetType, "The instrument type should be .equity" )
        if( AssetType.EQUITY == decodedInstrument.instrument.assetType )
        {
            let equityDetails : SapiTransactionEquity? = decodedInstrument.instrument
            #expect( equityDetails != nil, "The equity details should not be nil" )
            // verify the assetType
            #expect( equityDetails!.assetType == .EQUITY, "The assetType should be '.EQUITY'" )
            #expect( equityDetails!.symbol == "SFM", "The symbol should be 'SFM'")
            #expect( equityDetails!.status == .ACTIVE, "The status should be '.ACTIVE'")
            #expect( equityDetails!.closingPrice == 169.76, "The closing price should be 169.76")
            #expect( equityDetails!.type == .COMMON_STOCK, "The type should be .COMMON_STOCK")
        }

    }
    
    
    

    @Test func testEncodeSapiTransactionEquity() throws
    {
        // Step 1: Create a SapiTransactionEquity object
        let equity = SapiTransactionEquity(
            assetType: .EQUITY,
            status: .ACTIVE,
            symbol: "SFM",
            instrumentId: 1806651,
            closingPrice: 169.76,
            type: .COMMON_STOCK
        )
        
        // Step 2: Wrap the equity object in a dictionary to match the JSON structure
        let instrumentWrapper = ["instrument": equity]
        
        // Step 3: Encode the dictionary into JSON
        let encoder = JSONEncoder()
        // set the encoder to prettyPrinted and sortedKeys
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encodedData = try encoder.encode(instrumentWrapper)
        let encodedJSON = String(data: encodedData, encoding: .utf8)!
        
        // Step 4: Define the expected JSON string
        let expectedJSON = """
{
  "instrument" : {
    "assetType" : "EQUITY",
    "closingPrice" : 169.76,
    "instrumentId" : 1806651,
    "status" : "ACTIVE",
    "symbol" : "SFM",
    "type" : "COMMON_STOCK"
  }
}
"""

        // Step 5: Compare the generated JSON with the expected JSON
        #expect( encodedJSON == expectedJSON, "JSON encoding failed" )
    }
    
    
}
