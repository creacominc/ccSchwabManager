/**
 *
 */

import Testing
import Foundation
@testable import ccSchwabManager

struct TransactionAPIOptionDeliverableTests
{
    
    @Test func testEncodingTransactionAPIOptionDeliverable() throws
    {
        // Create the test object
        let testObj : TransactionAPIOptionDeliverable = TransactionAPIOptionDeliverable(
            rootSymbol: "optiondeliverable",
            strikePercent: 12,
            deliverableNumber: 1234,
            deliverableUnits: 2,
            assetType: .OPTION)
        // Encode to json
        let encoder : JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Encode to JSON string
        let jsonData : Data = try encoder.encode( testObj )
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Test
        #expect( nil != jsonString, "Encoded JSON string should not be nil" )
        //        print( "Encoded JSON:\n\(jsonString!)" )

        #expect( jsonString?.contains( "\"rootSymbol\" : \"optiondeliverable\"" ) ?? false, "JSON string should contain the rootSymbol 'optiondeliverable'" )
        #expect( jsonString?.contains( "\"deliverableNumber\" : 1234" ) ?? false, "JSON string should contain the deliverableNumber 1234" )
    }
    
    @Test func testDecodingTransactionAPIOptionDeliverable() throws
    {
        // Create JSON string
        let jsonString = """
            {
                "rootSymbol": "optiondeliverable",
                "strikePercent": 12,
                "deliverableNumber": 1234,
                "deliverableUnits": 2,
                "assetType": "OPTION"
            }
            """
        let jsonData = jsonString.data( using: .utf8)!
        let decoder : JSONDecoder = JSONDecoder()

        // Decode
        let decodedEquity = try decoder.decode( TransactionAPIOptionDeliverable.self, from: jsonData )

        // Test
        #expect(decodedEquity.rootSymbol == "optiondeliverable", "rootSymbol should be optiondeliverable")
        #expect(decodedEquity.strikePercent == 12, "strikePercent should be 12")
        #expect(decodedEquity.deliverableNumber == 1234, "deliverableNumber should be 1234")
        #expect(decodedEquity.deliverableUnits == 2, "deliverableUnits should be 2")
        #expect(decodedEquity.assetType == .OPTION, "assetType should be OPTION")

    }
    
}
