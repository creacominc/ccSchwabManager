//
//  ccSchwabManagerApp.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Preview Detection Helper
extension ProcessInfo {
    var isPreview: Bool {
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
//
//extension View {
////    func logPreviewStackTrace(_ message: String) -> some View {
////        if ProcessInfo.processInfo.isPreview {
////            print("⏭ PREVIEW STACK TRACE: \(message)")
////            Thread.callStackSymbols.forEach { print("⏭   \($0)") }
////        }
////        return self
////    }
//    
////    func debugPreview(_ viewName: String) -> some View {
////        if ProcessInfo.processInfo.isPreview {
////            print("⏭ PREVIEW: Initializing view: \(viewName)")
////            print("⏭ Stack trace:")
////            Thread.callStackSymbols.forEach { print("⏭   \($0)") }
////        }
////        return self
////    }
//    
////    func debugEnvironmentObject<T: ObservableObject>(_ objectType: T.Type, _ message: String = "") -> some View {
////        if ProcessInfo.processInfo.isPreview {
////            print("⏭ PREVIEW: View accessing @EnvironmentObject \(String(describing: objectType)): \(message)")
////            print("⏭ Stack trace:")
////            Thread.callStackSymbols.forEach { print("⏭   \($0)") }
////        }
////        return self
////    }
//}

@main
struct ccSchwabManagerApp: App
{
    @StateObject private var secretsManager: SecretsManager
    @StateObject private var networkMonitor = NetworkMonitor()
    
    init() {
        if ProcessInfo.processInfo.isPreview {
            print("⏭ PREVIEW: Creating SecretsManager in ccSchwabManagerApp.init()")
            print("⏭ Stack trace:")
            Thread.callStackSymbols.forEach { print("⏭   \($0)") }
        }
        self._secretsManager = StateObject(wrappedValue: SecretsManager())
        
        if ProcessInfo.processInfo.isPreview {
            print("⏭ Skipping ccSchwabManagerApp.init() because this is a preview")
            return
        }
        print( "=== ccSchwabManagerApp init ===" )
        AppLogger.shared.info("=== ccSchwabManagerApp started ===")
        print("Log file location: \(AppLogger.shared.getLogFilePath())")
        
        // // Direct file write test
        // let testMessage = "=== Direct file write test ===\n"
        // if let data = testMessage.data(using: .utf8) {
        //     let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        //     let logFileURL = documentsPath.appendingPathComponent("ccSchwabManager.log")
        //     if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
        //         fileHandle.seekToEndOfFile()
        //         fileHandle.write(data)
        //         fileHandle.closeFile()
        //     }
        // }
    }
    
    var didBecomeActiveNotification: Notification.Name {
#if os(visionOS)
        return UIApplication.didBecomeActiveNotification
#elseif os(iOS)
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
                .environmentObject(networkMonitor)
//                .debugPreview("ContentView")
//                .onReceive(NotificationCenter.default.publisher(for: didBecomeActiveNotification)) { _ in
//                    print("📱 App became active - clearing any stuck loading states")
//                    SchwabClient.shared.clearLoadingState()
//                }
//                .onKeyPress(.escape) {
//                    print("🔑 ESC key pressed - clearing any stuck loading states")
//                    SchwabClient.shared.clearLoadingState()
//                    return .handled
//                }
//                .overlay(CSVShareView().debugPreview("CSVShareView"))
        }
    }
}

class SecretsManager: ObservableObject {
    @Published var secrets: Secrets
    @Published var isLoading = false
    @Published var error: String?
    
    // Debug property to track access
    var debugSecrets: Secrets {
        if ProcessInfo.processInfo.isPreview {
            print("⏭ PREVIEW: SecretsManager.secrets accessed")
            print("⏭ Stack trace:")
            Thread.callStackSymbols.forEach { print("⏭   \($0)") }
        }
        return secrets
    }
    
    init() {
        if ProcessInfo.processInfo.isPreview {
//            print("⏭ PREVIEW: SecretsManager.init() called")
//            print("⏭ Stack trace:")
//            Thread.callStackSymbols.forEach { print("⏭   \($0)") }
//        }
//        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("⏭ Skipping SecretsManager.saveSecrets() because this is a preview")
//            print("⏭ Stack trace for SecretsManager.init() in preview:")
//            Thread.callStackSymbols.forEach { print("⏭   \($0)") }
            self.secrets = Secrets()
            return
        }
        print( "=== SecretsManager init getting secrets ===" )
        self.secrets = KeychainManager.readSecrets(prefix: "SecretsManager/init") ?? Secrets()
        // Configure SchwabClient with initial secrets
        SchwabClient.shared.configure(with: &self.secrets)
    }
    
    func saveSecrets() {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("⏭ Skipping SecretsManager.saveSecrets() because this is a preview")
            print("⏭ Stack trace for SecretsManager.saveSecrets() in preview:")
            Thread.callStackSymbols.forEach { print("⏭   \($0)") }
            return
        }
        print( "=== SecretsManager Saving secrets ===" )
        var secretsToSave = secrets
        _ = KeychainManager.saveSecrets(secrets: &secretsToSave)
        // Update SchwabClient with new secrets
        SchwabClient.shared.configure(with: &secretsToSave)
    }
    
    func resetSecrets(partial: Bool = false) {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("⏭ Skipping SecretsManager.resetSecrets() because this is a preview")
            print("⏭ Stack trace for SecretsManager.resetSecrets() in preview:")
            Thread.callStackSymbols.forEach { print("⏭   \($0)") }
            return
        }
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
