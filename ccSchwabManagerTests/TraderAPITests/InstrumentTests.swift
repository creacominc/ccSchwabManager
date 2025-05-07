//
//  InstrumentTests.swift
//


import Testing
import Foundation
@testable import ccSchwabManager

/**
  SapiAccountsInstruments could be encoded in JSON as follows:
 

 
 */

struct InstrumentTests
{
    /**
     {
     "assetType":"OPTION",
     "cusip":"0INTC.EG50024500",
     "symbol":"INTC  250516C00024500",
     "description":"INTEL CORP 05/16/2025 $24.5 Call",
     "netChange":-0.0046,
     "type":"VANILLA",
     "putCall":"CALL",
     "underlyingSymbol":"INTC"
     }
     */
    @Test func testEncodingOption() throws
    {
        // create the object
        let testData : Instrument = Instrument(
            assetType: .OPTION,
            cusip: "0INTC.EG50024500",
            symbol: "INTC  250516C00024500",
            description: "INTEL CORP 05/16/2025 $24.5 Call",
            netChange: -0.0046,
            type: .VANILLA,
            putCall: .CALL,
            underlyingSymbol: "INTC"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // encode to json
        let jsonData = try encoder.encode( testData )
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        // verify
        #expect( nil != jsonString, "Encoded JSON string should not be nil")
        // print("Encoded JSON:\n\(jsonString ?? "Nil")")
        
        // test the contents
        #expect( jsonString?.contains( "\"assetType\" : \"OPTION\"" ) ?? false , "The assetType property does not match")
        #expect( jsonString?.contains( "\"cusip\" : \"0INTC.EG50024500\"" ) ?? false , "The cusip property does not match")
        #expect( jsonString?.contains( "\"symbol\" : \"INTC  250516C00024500\"" ) ?? false , "The symbol property does not match")
        #expect( jsonString?.contains( "\"netChange\" : -0.0046" ) ?? false , "The netChange property does not match")
        #expect( jsonString?.contains( "\"underlyingSymbol\" : \"INTC\"" ) ?? false , "The underlyingSymbol property does not match")
        
    }
    
    /**
     {
     "assetType":"OPTION",
     "cusip":"0INTC.EG50024500",
     "symbol":"INTC  250516C00024500",
     "description":"INTEL CORP 05/16/2025 $24.5 Call",
     "netChange":-0.0046,
     "type":"VANILLA",
     "putCall":"CALL",
     "underlyingSymbol":"INTC"
     }
     */
    @Test func testDecodingOption() throws
    {
        // create the test json
        let jsonString = """
        {
        "assetType":"OPTION",
        "cusip":"0INTC.EG50024500",
        "symbol":"INTC  250516C00024500",
        "description":"INTEL CORP 05/16/2025 $24.5 Call",
        "netChange":-0.0046,
        "type":"VANILLA",
        "putCall":"CALL",
        "underlyingSymbol":"INTC"
         }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // decode to object
        let decodedObject = try decoder.decode( Instrument.self, from: jsonData )
        
        // verify
        #expect( decodedObject.assetType == .OPTION, "assetType failed" )
        #expect( decodedObject.symbol == "INTC  250516C00024500", "symbol failed" )
        #expect( decodedObject.netChange == -0.0046, "netChange failed" )
        #expect( decodedObject.putCall == .CALL, "putCall failed" )
        #expect( decodedObject.underlyingSymbol == "INTC", "underlyingSymbol failed" )
    }


    /**
     * Equity
     * documentation claims:
     * {
     "assetType": "EQUITY",
     "status": "ACTIVE",
     "symbol": "SFM",
     "instrumentId": 1806651,
     "closingPrice": 169.76,
     "type": "COMMON_STOCK"
     *     }
     *
     * reality is:
     *   {"assetType":"EQUITY","cusip":"910873405","symbol":"UMC","netChange":0.29}
     */
    @Test func testEncodingEquityPerDocs() throws
    {
        // create the object
        let testData : Instrument = Instrument(
            assetType: .EQUITY,
            symbol: "SFM",
            instrumentId: 1806651,
            status: .ACTIVE,
            closingPrice: 169.76,
            type: .COMMON_STOCK
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // encode to json
        let jsonData = try encoder.encode( testData )
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        // verify
        #expect( nil != jsonString, "Encoded JSON string should not be nil")
        // print("Encoded JSON:\n\(jsonString ?? "Nil")")
        
        // test the contents
        #expect( jsonString?.contains( "\"assetType\" : \"EQUITY\"" ) ?? false , "The assetType property does not match")
        #expect( jsonString?.contains( "\"symbol\" : \"SFM\"" ) ?? false , "The symbol property does not match")
        #expect( jsonString?.contains( "\"instrumentId\" : 1806651" ) ?? false , "The instrumentId property does not match")
    }
    

    /**
     * Equity
     * documentation claims:
     * {
     "assetType": "EQUITY",
     "status": "ACTIVE",
     "symbol": "SFM",
     "instrumentId": 1806651,
     "closingPrice": 169.76,
     "type": "COMMON_STOCK"
     *     }
     *
     * reality is:
     *   {"assetType":"EQUITY","cusip":"910873405","symbol":"UMC","netChange":0.29}
     */
    @Test func testDecodingEquityPerDocs() throws
    {
        // create the test json
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
        
        // decode to object
        let decodedObject = try decoder.decode( Instrument.self, from: jsonData )
        
        // verify
        #expect( decodedObject.assetType == .EQUITY, "assetType failed" )
        #expect( decodedObject.symbol == "SFM", "symbol failed" )
        #expect( decodedObject.instrumentId == 1806651, "instrumentId failed" )
        #expect( decodedObject.type == .COMMON_STOCK, "type failed" )
        #expect( decodedObject.status == .ACTIVE, "status failed" )

    }
    



    /**
     * Equity
     * documentation claims:
     * {
     "assetType": "EQUITY",
     "status": "ACTIVE",
     "symbol": "SFM",
     "instrumentId": 1806651,
     "closingPrice": 169.76,
     "type": "COMMON_STOCK"
     *     }
     *
     * reality is:
     *   {"assetType":"EQUITY","cusip":"910873405","symbol":"UMC","netChange":0.29}
     */
    @Test func testEncodingEquityPerResponse() throws
    {
        // create the object
        let testData : Instrument = Instrument(
            assetType: .EQUITY,
            cusip: "910873405",
            symbol: "SFM",
            netChange: 0.29
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // encode to json
        let jsonData = try encoder.encode( testData )
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        // verify
        #expect( nil != jsonString, "Encoded JSON string should not be nil")
        // print("Encoded JSON:\n\(jsonString ?? "Nil")")
        
        // test the contents
        #expect( jsonString?.contains( "\"assetType\" : \"EQUITY\"" ) ?? false , "The assetType property does not match")
        #expect( jsonString?.contains( "\"symbol\" : \"SFM\"" ) ?? false , "The symbol property does not match")
        #expect( jsonString?.contains( "\"netChange\" : 0.29" ) ?? false , "The netChange property does not match")
    }
    

    /**
     * Equity
     * documentation claims:
     * {
     "assetType": "EQUITY",
     "status": "ACTIVE",
     "symbol": "SFM",
     "instrumentId": 1806651,
     "closingPrice": 169.76,
     "type": "COMMON_STOCK"
     *     }
     *
     * reality is:
     *   {"assetType":"EQUITY","cusip":"910873405","symbol":"UMC","netChange":0.29}
     */
    @Test func testDecodingEquityPerResponse() throws
    {
        // create the test json
        let jsonString = """
        {
        "assetType": "EQUITY",
        "cusip": "910873405",
        "symbol": "SFM",
        "netChange": 0.29
         }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // decode to object
        let decodedObject = try decoder.decode( Instrument.self, from: jsonData )
        
        // verify
        #expect( decodedObject.assetType == .EQUITY, "assetType failed" )
        #expect( decodedObject.symbol == "SFM", "symbol failed" )
        #expect( decodedObject.netChange == 0.29, "netChange failed" )
        #expect( decodedObject.cusip == "910873405", "cusip failed" )

    }
    


}
