//
//  testSecrets 2.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-07.
//


import Testing
import SwiftUI
@testable import ccSchwabManager

struct testSecrets
{

    @Test func testSecretsInitialization() async throws {
        let secrets = Secrets()

        #expect(secrets.appId == "", "App ID should be UNINITIALIZED")
        #expect(secrets.appSecret == "", "App Secret should be UNINITIALIZED")
        #expect(secrets.redirectUrl == "", "Redirect URL should be UNINITIALIZED")
        #expect(secrets.code == "", "Code should be UNINITIALIZED")
        #expect(secrets.session == "", "Session should be UNINITIALIZED")
        #expect(secrets.accessToken == "", "Access Token should be UNINITIALIZED")
        #expect(secrets.refreshToken == "", "Refresh Token should be UNINITIALIZED")
    }

    func removeHashesFromString( input: String ) -> String
    {
        print( "Source: \(input)" )
        let regex: NSRegularExpression = try! NSRegularExpression(pattern: "\"acountNumberHash\".*\n.*\\]")
        let replaced: String = regex.stringByReplacingMatches(
            in: input,
            options: [],
            range: NSRange(location: 0, length: input.utf16.count),
            withTemplate: ""
        )
        print( "Replaced: \(replaced)" )
        return replaced
    }

    @Test func testHashRemoval() async throws
    {
        let inputString: String = "something, \"acountNumberHash\" : [\n], else"
        let expectedString: String = "something, , else"
        let outputString: String = removeHashesFromString( input: inputString )
        #expect( outputString == expectedString, "String hashes not removed correctly" )
    }

    @Test func testSecretsEncoding() async throws {
        // testing secret encoding to json
        // create a secret
        let secrets = Secrets(
                appId: "appIdValue", appSecret: "appSecretValue", redirectUrl: "redirectUrlValue",
                code: "codeValue", session: "sessionValue", accessToken: "accessTokenValue",
                refreshToken: "refreshTokenValue", acountNumberHash: [])

        // call the encodeToString method to get a JSON encoded string.
        let jsonEncodedString: String? = secrets.encodeToString()
        #expect(jsonEncodedString != nil, "Encoded string should not be nil")
        //print( "jsonEncodedString = \(jsonEncodedString ?? "Failed to Encode")" )

        // Convert the string to a dictionary.
        var elementDictionary: [String: Any] = try JSONSerialization.jsonObject(with: (jsonEncodedString?.data(using: .utf8)!)!, options: []) as! [String: Any]
        //print( "elementDictionary = \(elementDictionary)" )
        // remove the accountNumberHash from the dictionary as it does not compare well
        elementDictionary["acountNumberHash"] = nil
        //print( "(post) elementDictionary = \(elementDictionary)" )

        // Convert dictionary to an array of key-value pairs
        let keyValueEncodedPairs:[(String, Any)] = elementDictionary.map{ ($0.key, $0.value) }
        // Sort the array by keys
        let sortedKeyValueEncodedPairs:[(String, Any)]  = keyValueEncodedPairs.sorted { $0.0 < $1.0 }
//        // Print the sorted array
//        for (key, value) in sortedKeyValueEncodedPairs {
//            print("\(key): \(value)")
//        }

        let expectedString: String = "{\"appId\":\"appIdValue\",\"appSecret\":\"appSecretValue\",\"redirectUrl\":\"redirectUrlValue\",\"code\":\"codeValue\",\"session\":\"sessionValue\",\"accessToken\":\"accessTokenValue\",\"refreshToken\":\"refreshTokenValue\"}"
        // Load expectedString into a dictionary for comparison
        let expectedDictionary: [String: Any] = try JSONSerialization.jsonObject(with: expectedString.data(using: .utf8)!, options: []) as! [String: Any]
        // Convert dictionary to an array of key-value pairs
        let keyValueExpectedPairs:[(String, Any)] = expectedDictionary.map { ($0.key, $0.value) }
        // Sort the array by keys
        let sortedKeyValueExpectedPairs:[(String, Any)]  = keyValueExpectedPairs.sorted { $0.0 < $1.0 }
//        // Print the sorted array
//        for (key, value) in sortedKeyValueExpectedPairs {
//            print("\(key): \(value)")
//        }

        #expect( areEquivalent( sortedKeyValueExpectedPairs, sortedKeyValueEncodedPairs ), "Encoded string does not match expected string")
    }

    @Test func testSecretsDump() async throws
    {
        let secrets = Secrets( appId: "appIdValue", appSecret: "appSecretValue", redirectUrl: "redirectUrlValue",
                               code: "codeValue", session: "sessionValue", accessToken: "accessTokenValue",
                               refreshToken: "refreshTokenValue", acountNumberHash: [])

        let dumpOutput = secrets.dump()
        let expectedOutput = """
        Secret = appId: appIdValue,  appSecret: appSecretValue,  redirectUrl: redirectUrlValue, code: codeValue,  session: sessionValue,  accessToken: accessTokenValue,  refreshToken: refreshTokenValue
        """
        let compareCharacters : Int = 150
        #expect(dumpOutput.prefix( compareCharacters ) == expectedOutput.prefix( compareCharacters ), "Dump output does not match expected output")
    }


    func areEquivalent(_ lhs: [(String, Any)], _ rhs: [(String, Any)]) -> Bool
    {
        guard lhs.count == rhs.count else { return false }

        for (key, value) in lhs {
            if let rhsValue = rhs.first(where: { $0.0 == key })?.1 {
                if !areValuesEqual(value, rhsValue) {
                    return false
                }
            } else {
                return false
            }
        }

        return true
    }

    func areValuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
        case (let lhs as Int, let rhs as Int):
            return lhs == rhs
        case (let lhs as String, let rhs as String):
            return lhs == rhs
        case (let lhs as Double, let rhs as Double):
            return lhs == rhs
        case (let lhs as Bool, let rhs as Bool):
            return lhs == rhs
        case (let lhs as [String: Any], let rhs as [String: Any]):
            return NSDictionary(dictionary: lhs).isEqual(to: rhs)
        case (let lhs as [Any], let rhs as [Any]):
            return NSArray(array: lhs).isEqual(to: rhs)
        default:
            return false
        }
    }



}
