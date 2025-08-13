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
        print( "=== ccSchwabManagerApp init ===" )
        AppLogger.shared.info("=== ccSchwabManagerApp started ===")
        AppLogger.shared.info("=== Testing log file write ===" )
        print("Log file should be at: ~/Documents/ccSchwabManager.log")
        
        // Direct file write test
        let testMessage = "=== Direct file write test ===\n"
        if let data = testMessage.data(using: .utf8) {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let logFileURL = documentsPath.appendingPathComponent("ccSchwabManager.log")
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
    }
    
    var didBecomeActiveNotification: Notification.Name {
#if os(iOS)
        return UIApplication.didBecomeActiveNotification
#else
        return NSApplication.didBecomeActiveNotification
#endif
    }
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .environmentObject(secretsManager)
                .onAppear {
                    AppLogger.shared.info("=== ContentView appeared ===")
                    AppLogger.shared.info("Log file location: \(AppLogger.shared.getLogFilePath())")
                    print("ContentView appeared - this should show in console")
                }
                .onReceive(NotificationCenter.default.publisher(for: didBecomeActiveNotification)) { _ in
                    print("📱 App became active - clearing any stuck loading states")
                    SchwabClient.shared.clearLoadingState()
                }
                .onKeyPress(.escape) {
                    print("🔑 ESC key pressed - clearing any stuck loading states")
                    SchwabClient.shared.clearLoadingState()
                    return .handled
                }
                .overlay(CSVShareView())
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
