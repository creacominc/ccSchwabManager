//
//  AggregatedBalanceTests.swift
//



import Testing
import Foundation
@testable import ccSchwabManager

/**
 
 AggregatedBalance can appear as the following JSON:

{"currentLiquidationValue":425187.77,"liquidationValue":425187.77}

 */

struct AggregatedBalanceTests
{

    @Test func testEncodingAggregatedBalance() throws
    {
        let aggregatedBalance : AggregatedBalance = .init(currentLiquidationValue: 425187.77, liquidationValue: 425187.77)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Act
        let jsonData : Data = try encoder.encode( aggregatedBalance )
        let jsonString = String(data: jsonData, encoding: .utf8)

        let expectedString : String = """
            {
              "currentLiquidationValue" : 425187.77,
              "liquidationValue" : 425187.77
            }
            """
        #expect(jsonString == expectedString )
    }

    @Test func testDecodingAggregatedBalance() throws
    {
        let jsonString : String = "{\"currentLiquidationValue\":425187.77,\"liquidationValue\":425187.77}"
        let decoder = JSONDecoder()

        let aggregatedBalance : AggregatedBalance = try decoder.decode(AggregatedBalance.self, from: jsonString.data(using: .utf8)!)
        #expect( 425187.77 == aggregatedBalance.currentLiquidationValue, "liquidation value should be 425187.77" )
        #expect( 425187.77 == aggregatedBalance.liquidationValue, "liquidation value should be 425187.77" )
    }

}
