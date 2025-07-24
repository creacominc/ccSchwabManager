//
//  ContentView.swift
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

struct ContentView: View
{
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var authCode = ""
    @State private var selectedTab = 0
    @State private var showingAuthDialog = false
    @State private var isLoading = false
    
    var didBecomeActiveNotification: Notification.Name {
#if os(iOS)
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
            } else if secretsManager.secrets.code.isEmpty {
                // Show authentication flow
                AuthFlowView(authCode: $authCode)
            } else {
                // Show main app content
                TabView(selection: $selectedTab) {
                    HoldingsView()
                        .tabItem {
                            Label("Holdings", systemImage: "list.bullet")
                        }
                        .tag(0)
                    
                    CredentialsInputView(isPresented: .constant(true))
                        .tabItem {
                            Label("Credentials", systemImage: "key.fill")
                        }
                        .tag(1)
                    
                    DebugLogView()
                        .tabItem {
                            Label("Debug", systemImage: "ladybug.fill")
                        }
                        .tag(2)
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
        .onAppear {
            // Clear any stuck loading states when the view appears
            SchwabClient.shared.clearLoadingState()
        }
        .onReceive(NotificationCenter.default.publisher(for: didBecomeActiveNotification)) { _ in
            // Clear stuck loading states when app becomes active
            print("📱 App became active - clearing stuck loading states")
            SchwabClient.shared.clearLoadingState()
        }
    }
}
