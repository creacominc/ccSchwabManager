//
//  SettingsView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

/**
 * SettingsView
 * 
 * This view provides options for managing the app's API credentials and authentication state.
 * It allows users to reset their credentials or just the authentication state.
 * 
 * Layout:
 * - NavigationView containing:
 *   - List with "API Credentials" section
 *     - "Reset All Credentials" button (red)
 *     - "Reset Authentication" button (orange)
 * 
 * Functionality:
 * - Reset All Credentials: Clears all API credentials and authentication data
 * - Reset Authentication: Clears only the authentication data while preserving API credentials
 */

struct SettingsView: View {
    @EnvironmentObject var secretsManager: SecretsManager
    
    var body: some View {
        NavigationView {
            List {
                Section("API Credentials") {
                    Button("Reset All Credentials") {
                        secretsManager.resetSecrets(partial: false)
                    }
                    .foregroundColor(.red)
                    
                    Button("Reset Authentication") {
                        secretsManager.resetSecrets(partial: true)
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Settings")
        }
    }
} 