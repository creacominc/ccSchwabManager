//
//  ContentView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

struct ContentView: View
{
    @StateObject private var secretsManager = SecretsManager()
    @State private var authCode = ""
    @State private var selectedTab = 0
    @State private var showingAuthDialog = false

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
        .environmentObject(secretsManager)
    }
}

// Remove all other view definitions as they are now in separate files


