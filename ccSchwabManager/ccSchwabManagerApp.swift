//
//  ccSchwabManagerApp.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@main
struct ccSchwabManagerApp: App
{
    @StateObject private var secretsManager = SecretsManager()
    
    init() {
        print( "=== ccSchwabManagerApp init ===" )
    }
    
    var didBecomeActiveNotification: Notification.Name {
        #if canImport(UIKit)
        return UIApplication.didBecomeActiveNotification
        #elseif canImport(AppKit)
        return NSApplication.didBecomeActiveNotification
        #else
        return Notification.Name("UnknownPlatformDidBecomeActive")
        #endif
    }
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .environmentObject(secretsManager)
                .onReceive(NotificationCenter.default.publisher(for: didBecomeActiveNotification)) { _ in
                    print("📱 App became active - clearing any stuck loading states")
                    SchwabClient.shared.clearLoadingState()
                }
        }
    }
}

class SecretsManager: ObservableObject {
    @Published var secrets: Secrets
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        print( "=== SecretsManager init getting secrets ===" )
        self.secrets = KeychainManager.readSecrets(prefix: "SecretsManager/init") ?? Secrets()
        // Configure SchwabClient with initial secrets
        SchwabClient.shared.configure(with: &self.secrets)
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
