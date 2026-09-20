//
//  CredentialsInputView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

/**
 * CredentialsInputView
 * 
 * This view provides a dialog interface for viewing and updating Schwab API credentials.
 * It displays the current secrets as formatted JSON and allows editing of specific fields.
 * 
 * Layout:
 * - VStack containing:
 *   - Title
 *   - Editable JSON representation of current secrets
 *   - Text fields for editable credentials:
 *     - App ID
 *     - App Secret
 *     - Redirect URL
 *   - Save and Cancel buttons
 * 
 * Functionality:
 * - Accepts pasted or edited JSON credentials
 * - Allows editing of App ID, App Secret, and Redirect URL
 * - Validates and saves the updated credentials
 * - Provides cancel option to dismiss without saving
 */

struct CredentialsInputView: View {
    private struct ImportedCredentials: Decodable {
        let appId: String?
        let appSecret: String?
        let redirectUrl: String?
        let code: String?
        let session: String?
        let accessToken: String?
        let refreshToken: String?
        let acountNumberHash: [AccountNumberHash]?
    }

    @EnvironmentObject var secretsManager: SecretsManager
    @Binding var isPresented: Bool
    @State private var jsonText: String = ""
    @State private var appId: String = ""
    @State private var appSecret: String = ""
    @State private var redirectUrl: String = "https://127.0.0.1"
    @State private var importedCode: String?
    @State private var importedSession: String?
    @State private var importedAccessToken: String?
    @State private var importedRefreshToken: String?
    @State private var importedAccountNumberHashes: [AccountNumberHash]?
    @FocusState private var isJsonEditorFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("API Credentials")
                .font(.title)
            
            // Editable JSON input. Valid pasted JSON updates the credential fields.
            TextEditor(text: $jsonText)
                .font(.system(.body, design: .monospaced))
                .frame(maxHeight: .infinity)
                .focused($isJsonEditorFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .onChange(of: jsonText) { _, newValue in
                    applyCredentials(from: newValue)
                }
            
            // Editable credentials
            VStack(alignment: .leading, spacing: 10) {
                TextField("App ID", text: $appId)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: appId) { _, _ in
                        if !isJsonEditorFocused { updateJsonPreview() }
                    }
                TextField("App Secret", text: $appSecret)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: appSecret) { _, _ in
                        if !isJsonEditorFocused { updateJsonPreview() }
                    }
                TextField("Redirect URL", text: $redirectUrl)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: redirectUrl) { _, _ in
                        if !isJsonEditorFocused { updateJsonPreview() }
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
        let current = secretsManager.secrets
        let preview = Secrets(
            appId: appId,
            appSecret: appSecret,
            redirectUrl: redirectUrl,
            code: importedCode ?? current.code,
            session: importedSession ?? current.session,
            accessToken: importedAccessToken ?? current.accessToken,
            refreshToken: importedRefreshToken ?? current.refreshToken,
            acountNumberHash: importedAccountNumberHashes ?? current.acountNumberHash
        )
        jsonText = preview.encodeToString() ?? jsonText
    }

    private func applyCredentials(from json: String) {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode(ImportedCredentials.self, from: data) else {
            return
        }

        if let value = values.appId {
            appId = value
        }
        if let value = values.appSecret {
            appSecret = value
        }
        if let value = values.redirectUrl {
            redirectUrl = value
        }
        importedCode = values.code
        importedSession = values.session
        importedAccessToken = values.accessToken
        importedRefreshToken = values.refreshToken
        importedAccountNumberHashes = values.acountNumberHash
    }
    
    private func saveCredentials() {
        let current = secretsManager.secrets
        secretsManager.secrets = Secrets(
            appId: appId,
            appSecret: appSecret,
            redirectUrl: redirectUrl,
            code: importedCode ?? current.code,
            session: importedSession ?? current.session,
            accessToken: importedAccessToken ?? current.accessToken,
            refreshToken: importedRefreshToken ?? current.refreshToken,
            acountNumberHash: importedAccountNumberHashes ?? current.acountNumberHash
        )
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
