//
//  ccSchwabManagerApp.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

@main
struct ccSchwabManagerApp: App
{
    @StateObject private var secretsManager = SecretsManager()
    
    init() {
        print( "=== ccSchwabManagerApp init getting secrets ===" )
        // Configure SchwabClient with initial secrets
        var initialSecrets = KeychainManager.readSecrets(prefix: "ccSchwabManagerApp/init") ?? Secrets()
        SchwabClient.shared.configure(with: &initialSecrets)
    }
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .environmentObject(secretsManager)
        }
    }
}

class SecretsManager: ObservableObject {
    @Published var secrets: Secrets
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        self.secrets = KeychainManager.readSecrets(prefix: "SecretsManager/init") ?? Secrets()
    }
    
    func saveSecrets() {
        print( "=== SecretsManager Saving secrets ===" )
        var secretsToSave = secrets
        _ = KeychainManager.saveSecrets(secrets: &secretsToSave)
        // Update SchwabClient with new secrets
        SchwabClient.shared.configure(with: &secretsToSave)
    }
    
    func resetSecrets(partial: Bool = false) {
        if partial {
            // Keep appId, appSecret, and redirectUrl
            let appId = secrets.appId
            let appSecret = secrets.appSecret
            let redirectUrl = secrets.redirectUrl
            secrets = Secrets()
            secrets.appId = appId
            secrets.appSecret = appSecret
            secrets.redirectUrl = redirectUrl
        } else {
            secrets = Secrets()
        }
        saveSecrets()
    }
}
