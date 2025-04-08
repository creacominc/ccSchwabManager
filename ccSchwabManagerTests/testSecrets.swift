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

        #expect(secrets.getAppId() == "UNINITIALIZED", "App ID should be UNINITIALIZED")
        #expect(secrets.getAppSecret() == "UNINITIALIZED", "App Secret should be UNINITIALIZED")
        #expect(secrets.getRedirectUrl() == "UNINITIALIZED", "Redirect URL should be UNINITIALIZED")
        #expect(secrets.getCode() == "UNINITIALIZED", "Code should be UNINITIALIZED")
        #expect(secrets.getSession() == "UNINITIALIZED", "Session should be UNINITIALIZED")
        #expect(secrets.getAccessToken() == "UNINITIALIZED", "Access Token should be UNINITIALIZED")
        #expect(secrets.getRefreshToken() == "UNINITIALIZED", "Refresh Token should be UNINITIALIZED")
    }

    @Test func testSecretsEncoding() async throws {
        let secrets = Secrets()
        secrets.setAppId("appIdValue")
        secrets.setAppSecret("appSecretValue")
        secrets.setRedirectUrl("redirectUrlValue")
        secrets.setCode("codeValue")
        secrets.setSession("sessionValue")
        secrets.setAccessToken("accessTokenValue")
        secrets.setRefreshToken("refreshTokenValue")

        let encodedString: String? = secrets.encodeToString()
        #expect(encodedString != nil, "Encoded string should not be nil")

        // Load encodedString into a Json object for comparison
        let encodedJsonObj: [String: Any] = try JSONSerialization.jsonObject(with: (encodedString?.data(using: .utf8)!)!, options: []) as! [String: Any]
        // Convert dictionary to an array of key-value pairs
        let keyValueEncodedPairs:[(String, Any)] = encodedJsonObj.map{ ($0.key, $0.value) }
        // Sort the array by keys
        let sortedKeyValueEncodedPairs:[(String, Any)]  = keyValueEncodedPairs.sorted { $0.0 < $1.0 }
        // Print the sorted array
        for (key, value) in sortedKeyValueEncodedPairs {
            print("\(key): \(value)")
        }

        let expectedString: String = "{\"appId\":\"appIdValue\",\"appSecret\":\"appSecretValue\",\"redirectUrl\":\"redirectUrlValue\",\"code\":\"codeValue\",\"session\":\"sessionValue\",\"accessToken\":\"accessTokenValue\",\"refreshToken\":\"refreshTokenValue\"}"
        // Load expectedString into a Json object for comparison
        let expectedJsonObj: [String: Any] = try JSONSerialization.jsonObject(with: expectedString.data(using: .utf8)!, options: []) as! [String: Any]
        // Convert dictionary to an array of key-value pairs
        let keyValueExpectedPairs:[(String, Any)] = expectedJsonObj.map { ($0.key, $0.value) }
        // Sort the array by keys
        let sortedKeyValueExpectedPairs:[(String, Any)]  = keyValueExpectedPairs.sorted { $0.0 < $1.0 }
        // Print the sorted array
        for (key, value) in sortedKeyValueExpectedPairs {
            print("\(key): \(value)")
        }

        #expect( areEquivalent( sortedKeyValueExpectedPairs, sortedKeyValueEncodedPairs ), "Encoded string does not match expected string")
    }

    @Test func testSecretsDump() async throws
    {
        let secrets = Secrets()
        secrets.setAppId("appIdValue")
        secrets.setAppSecret("appSecretValue")
        secrets.setRedirectUrl("redirectUrlValue")
        secrets.setCode("codeValue")
        secrets.setSession("sessionValue")
        secrets.setAccessToken("accessTokenValue")
        secrets.setRefreshToken("refreshTokenValue")

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
