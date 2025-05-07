//
//


import Testing
import Foundation
@testable import ccSchwabManager

/**
 {
   "cdDomainId": "string",
   "login": "string",
   "type": "ADVISOR_USER",
   "userId": 0,
   "systemUserName": "string",
   "firstName": "string",
   "lastName": "string",
   "brokerRepCode": "string"
 }
 */


struct UserDetailsTests
{
    
    @Test func testEncodingUserDetailsTests() throws
    {
        // create test object
        let testData : UserDetails = UserDetails(cdDomainId: "domainId", login: "login",
                                                    type: .ADVISOR_USER,
                                                    userId: 12345, systemUserName: "systemUserName",
                                                    firstName: "firstName", lastName: "lastName",
                                                    brokerRepCode: "brokenCode"
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
        #expect( jsonString?.contains( "\"cdDomainId\" : \"domainId\"" ) ?? false , "The cdDomainId property does not match")
        #expect( jsonString?.contains( "\"type\" : \"ADVISOR_USER\"" ) ?? false ,  "The type property does not match")
        #expect( jsonString?.contains( "\"userId\" : 12345" ) ?? false ,  "The instrumentId userId does not match")
        #expect( jsonString?.contains( "\"firstName\" : \"firstName\"" ) ?? false ,  "The firstName property does not match")

    }


    @Test func testDecodingUserDetailsTests() throws
    {
        // create the test json
        let jsonString = """
        {
        "cdDomainId": "domainId",
        "login": "login",
        "type": "ADVISOR_USER",
        "userId": 12345,
        "systemUserName": "systemUserName",
        "firstName": "first",
        "lastName": "last",
        "brokerRepCode": "code"
         }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()

        // decode to object
        let decodedObject = try decoder.decode( UserDetails.self, from: jsonData )

        // verify
        #expect( decodedObject.cdDomainId == "domainId" )
        #expect( decodedObject.login == "login" )
        #expect( decodedObject.firstName == "first" )
        #expect( decodedObject.login == "login" )
        #expect( decodedObject.brokerRepCode == "code" )
    }


    
}

