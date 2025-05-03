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
            instrument = .init( instrumentType: .equity, details: equityDetails )
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
        
        // Act
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(instrument)
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        // Assert
        #expect( nil != jsonString, "Encoded JSON string should not be nil")
        // print("Encoded JSON:\n\(jsonString ?? "Nil")")

        // convert jsonString to a dictionary
        let jsonDict : [String:Any] = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String:Any]
        // print( "jsonDict = \(jsonDict)" )
        let details : [String:Any] = jsonDict["details"] as! [String:Any]
        // print( details["assetType"] )
        print( details["instrumentId"] ?? -1  )

        // test the contents of the details
        #expect( equityDetails.assetType.rawValue as String == details["assetType"] as! String , "The assetType property does not match")
        #expect( equityDetails.symbol                       == details["symbol"] as! String , "The symbol property does not match")
        #expect( equityDetails.instrumentId                 == details["instrumentId"] as? Int ?? -1 , "The instrumentId property does not match")
        #expect( equityDetails.type.rawValue as String      == details["type"] as! String , "The type property does not match")
        #expect( equityDetails.status.rawValue as String    == details["status"] as! String , "The status property does not match")
        #expect( equityDetails.closingPrice                 == details["closingPrice"] as? Double  ?? -1.0 , "The closingPrice property does not match")
    }


    @Test func testDecodingSapiTransactionInstrument() throws
    {
        // Arrange
        let jsonString = """
            {
                "instrumentType": "EQUITY",
                "details": 
                {
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
        #expect( .equity == decodedInstrument.instrumentType, "The instrument type should be .equity" )
        #expect( decodedInstrument.details != nil, "The details should not be nil" )
        if( .equity == decodedInstrument.instrumentType )
        {
            let equityDetails : SapiTransactionEquity? = decodedInstrument.details as? SapiTransactionEquity
            #expect( equityDetails != nil, "The equity details should not be nil" )
            // verify the assetType
            #expect( equityDetails!.assetType == .EQUITY, "The assetType should be '.EQUITY'" )
            #expect( equityDetails!.symbol == "SFM", "The symbol should be 'SFM'")
            #expect( equityDetails!.status == .ACTIVE, "The status should be '.ACTIVE'")
            #expect( equityDetails!.closingPrice == 169.76, "The closing price should be 169.76")
            #expect( equityDetails!.type == .COMMON_STOCK, "The type should be .COMMON_STOCK")
        }

    }
    
    
}
