//
//  ContentView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI
// IOS or VisionOS
#if os(iOS) ||  os(visionOS)
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
        // IOS or VisionOS
#if os(iOS) ||  os(visionOS)
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
    }
}
