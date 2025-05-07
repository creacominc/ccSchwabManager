//
//  AccountNumberHashTests.swift
//

import Testing
import Foundation
@testable import ccSchwabManager


/**
 
 
 
 
   * accountNumberHash can appear like this:
 {"hashValue":"0B1442C77300B4C17B9555E15A31B27E37FB94AAF87015BA95A16C5B16B3805F"}]
 */
struct AccountNumberHashTests
{
    @Test func testEncodingWithoutAccount() throws
    {
        let accountNumberHash : AccountNumberHash = .init(hashValue: "1234567890")
        #expect(accountNumberHash.hashValue == "1234567890")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Act
        let jsonData : Data = try encoder.encode( accountNumberHash )
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Assert
        #expect( nil != jsonString, "Encoded JSON string should not be nil" )
        // print( "Encoded JSON:\n\(jsonString!)" )


        #expect( jsonString?.contains( "\"hashValue\" : \"1234567890\"" ) ?? false, "JSON string should contain the symbol 'hashValue'" )
    }
    
    @Test func testEncodingWithAccount() throws
    {
        let accountNumberHash : AccountNumberHash = .init(accountNumber: "Acctn1234", hashValue: "1234567890" )
        #expect(accountNumberHash.hashValue == "1234567890")
        #expect(accountNumberHash.accountNumber == "Acctn1234")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Act
        let jsonData : Data = try encoder.encode( accountNumberHash )
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Assert
        #expect( nil != jsonString, "Encoded JSON string should not be nil" )
        // print( "Encoded JSON:\n\(jsonString!)" )

        #expect( jsonString?.contains( "\"hashValue\" : \"1234567890\"" ) ?? false, "JSON string should contain the symbol 'hashValue'" )
        #expect( jsonString?.contains( "\"accountNumber\" : \"Acctn1234\"" ) ?? false, "JSON string should contain the symbol 'accountNumber'" )
    }

    @Test func testDecodingWithoutAccount() throws
    {
        let jsonString : String = "{\"hashValue\" : \"1234567890\"}"
        let jsonData : Data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let accountNumberHash : AccountNumberHash = try decoder.decode( AccountNumberHash.self, from: jsonData )
        #expect( accountNumberHash.hashValue == "1234567890", "Hash value does not match" )
    }

    @Test func testDecodingWithAccount() throws
    {
        let jsonString : String = "{\"hashValue\" : \"1234567890\", \"accountNumber\" : \"Acctn1234\"}"
        let jsonData : Data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let accountNumberHash : AccountNumberHash = try decoder.decode( AccountNumberHash.self, from: jsonData )
        #expect( accountNumberHash.hashValue == "1234567890", "Hash value does not match" )
        #expect( accountNumberHash.accountNumber == "Acctn1234", "Account number does not match" )
    }

}

