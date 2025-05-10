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
        self.secrets = KeychainManager.readSecrets(prefix: "app/init") ?? Secrets()
    }
    
    func saveSecrets() {
        var secretsToSave = secrets
        _ = KeychainManager.saveSecrets(secrets: &secretsToSave)
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
