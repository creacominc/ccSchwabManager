//
//  ContentView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI
#if os(visionOS)
import UIKit
#elseif os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ContentView: View
{
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var authCode = ""
    @State private var selectedTab = 0
    @State private var showingAuthDialog = false
    @State private var isLoading = false
    @State private var holdingsReloadID = UUID()
    @State private var connectionReady = false

    private var shouldAttemptConnection: Bool {
        !connectionReady &&
            !secretsManager.secrets.appId.isEmpty &&
            !secretsManager.secrets.appSecret.isEmpty &&
            !secretsManager.secrets.redirectUrl.isEmpty &&
            !secretsManager.secrets.accessToken.isEmpty &&
            !secretsManager.secrets.refreshToken.isEmpty
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

    var body: some View
    {
        Group {
            if secretsManager.secrets.appId.isEmpty || 
               secretsManager.secrets.appSecret.isEmpty || 
               secretsManager.secrets.redirectUrl.isEmpty {
                // Show authentication setup
                AuthSetupView(showingAuthDialog: $showingAuthDialog)
            } else if secretsManager.secrets.code.isEmpty &&
                        (secretsManager.secrets.accessToken.isEmpty || secretsManager.secrets.refreshToken.isEmpty) {
                // Show authentication flow
                AuthFlowView(authCode: $authCode)
            } else {
                // Show main app content
                TabView(selection: $selectedTab) {
                    Group {
                        if connectionReady {
                            HoldingsView()
                                .id(holdingsReloadID)
                        } else {
                            ProgressView("Connecting to Schwab…")
                        }
                    }
                        .tabItem {
                            Label("Holdings", systemImage: "list.bullet")
                        }
                        .tag(0)
                    
                    CredentialsInputView(isPresented: .constant(true))
                        .tabItem {
                            Label("Credentials", systemImage: "key.fill")
                        }
                        .tag(1)
                }
            }
        }
        .sheet(isPresented: $showingAuthDialog) {
            CredentialsInputView(isPresented: $showingAuthDialog)
                .onDisappear {
                    // Force view update to check conditions again
                    secretsManager.objectWillChange.send()
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: SchwabClient.authorizationRequiredNotification)) { _ in
            connectionReady = false
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: SchwabClient.connectionRestoredNotification)) { _ in
            connectionReady = true
            holdingsReloadID = UUID()
            selectedTab = 0
        }
        .task(id: shouldAttemptConnection) {
            guard shouldAttemptConnection else { return }
            await SchwabClient.shared.reconnectAfterCredentialsUpdate()
        }
        .overlay(CSVShareView())
    }
}
