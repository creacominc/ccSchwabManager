//
//  CredentialsInputView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI
import Combine

/**
 * CredentialsInputView
 * 
 * This view provides a dialog interface for viewing and updating Schwab API credentials.
 * It displays the current secrets as formatted JSON and allows editing of specific fields.
 * 
 * Layout:
 * - VStack containing:
 *   - Title
 *   - Read-only JSON preview of current secrets
 *   - Text fields for editable credentials:
 *     - App ID
 *     - App Secret
 *     - Redirect URL
 *   - Save and Cancel buttons
 * 
 * Functionality:
 * - Displays current secrets as formatted JSON (read-only)
 * - Allows editing of App ID, App Secret, and Redirect URL
 * - Validates and saves the updated credentials
 * - Provides cancel option to dismiss without saving
 */

struct CredentialsInputView: View {
    @EnvironmentObject var secretsManager: SecretsManager
    @Binding var isPresented: Bool
    @State private var jsonText: String = ""
    @State private var appId: String = ""
    @State private var appSecret: String = ""
    @State private var redirectUrl: String = "https://127.0.0.1"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("API Credentials")
                .font(.title)
            
            // Read-only JSON preview
            TextEditor(text: .constant(jsonText))
                .font(.system(.body, design: .monospaced))
                .frame(maxHeight: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            
            // Editable credentials
            VStack(alignment: .leading, spacing: 10) {
                TextField("App ID", text: $appId)
                    .textFieldStyle(.roundedBorder)
                    .onReceive(Just(appId)) { _ in
                        updateJsonPreview()
                    }
                TextField("App Secret", text: $appSecret)
                    .textFieldStyle(.roundedBorder)
                    .onReceive(Just(appSecret)) { _ in
                        updateJsonPreview()
                    }
                TextField("Redirect URL", text: $redirectUrl)
                    .textFieldStyle(.roundedBorder)
                    .onReceive(Just(redirectUrl)) { _ in
                        updateJsonPreview()
                    }
            }
            .frame(maxWidth: 500)
            
            HStack {
                Button("Reset") {
                    resetCredentials()
                }
                .foregroundColor(.red)
                
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .opacity(isPresented ? 1 : 0) // Only show when presented as sheet
                
                Button("Save") {
                    saveCredentials()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appId.isEmpty || appSecret.isEmpty || redirectUrl.isEmpty)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Load current values
            appId = secretsManager.secrets.appId
            appSecret = secretsManager.secrets.appSecret
            redirectUrl = secretsManager.secrets.redirectUrl.isEmpty ? "https://127.0.0.1" : secretsManager.secrets.redirectUrl
            
            updateJsonPreview()
        }
    }
    
    private func updateJsonPreview() {
        // Create a dictionary of the secrets
        let secretsDict: [String: String] = [
            "appId": appId,
            "appSecret": appSecret,
            "redirectUrl": redirectUrl,
            "code": secretsManager.secrets.code,
            "accessToken": secretsManager.secrets.accessToken,
            "refreshToken": secretsManager.secrets.refreshToken
        ]
        
        // Convert to JSON with pretty printing
        if let jsonData = try? JSONSerialization.data(withJSONObject: secretsDict, options: [.sortedKeys, .prettyPrinted]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            jsonText = jsonString
        }
    }
    
    private func saveCredentials() {
        // Reset auth code to ensure we show the auth flow
        secretsManager.secrets.code = ""
        secretsManager.secrets.appId = appId
        secretsManager.secrets.appSecret = appSecret
        secretsManager.secrets.redirectUrl = redirectUrl
        secretsManager.saveSecrets()
        isPresented = false
    }
    
    private func resetCredentials() {
        // Reset all secrets
        secretsManager.secrets.code = ""
        secretsManager.secrets.appId = ""
        secretsManager.secrets.appSecret = ""
        secretsManager.secrets.redirectUrl = ""
        secretsManager.secrets.accessToken = ""
        secretsManager.secrets.refreshToken = ""
        secretsManager.saveSecrets()
        isPresented = false
    }
}
