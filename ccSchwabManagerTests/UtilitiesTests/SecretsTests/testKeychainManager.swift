//
//  testKeychainManager.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-07.
//

import Testing
import Foundation
@testable import ccSchwabManager

struct testKeychainManager
{
    
    @Test func testSaveSecrets() async throws
    {
        let _ = KeychainManager()
        let _ = Secrets() // Adjust the properties as per your Secrets struct
        //        let saveResult = keychainManager.saveSecrets(secrets: secrets)
        //        #expect(saveResult == true, "Failed to save secrets")
        //        // Additional check to verify the secrets were saved correctly
        //        let retrievedSecrets = keychainManager.readSecrets(prefix: "test")
        //        #expect(retrievedSecrets != nil, "Secrets should not be nil after saving")
        //        #expect(retrievedSecrets?.someProperty == "someValue", "The saved secrets do not match the retrieved secrets")
    }
    
    @Test func testReadSecrets() async throws
    {
        let _ = KeychainManager()
        let _ = Secrets() // Adjust the properties as per your Secrets struct
        //        let _ = keychainManager.saveSecrets(secrets: secrets)
        //        let retrievedSecrets = keychainManager.readSecrets(prefix: "test")
        //        #expect(retrievedSecrets != nil, "Secrets should not be nil")
        //        #expect(retrievedSecrets?.someProperty == "someValue", "The saved secrets do not match the retrieved secrets")
    }
    
    @Test func testReadSecretsWhenNoneSaved() async throws
    {
        let _ = KeychainManager()
        //        let retrievedSecrets = keychainManager.readSecrets(prefix: "test")
        //        #expect(retrievedSecrets == nil, "Secrets should be nil when none are saved")
    }
    
    
}
