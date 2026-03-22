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
 * View / edit Schwab API credentials. The JSON editor is fully editable so you can paste
 * a full `Secrets` blob (e.g. from Keychain) and save.
 */

struct CredentialsInputView: View {
    @EnvironmentObject var secretsManager: SecretsManager
    @Binding var isPresented: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var jsonText: String = ""
    @State private var appId: String = ""
    @State private var appSecret: String = ""
    @State private var redirectUrl: String = "https://127.0.0.1"
    @State private var saveErrorMessage: String = ""
    @State private var showingSaveError = false

    /// Fixed height so the JSON editor scrolls inside its box; the outer `ScrollView` scrolls the whole form (e.g. landscape + tab bar).
    private var jsonEditorHeight: CGFloat {
        #if os(iOS)
        verticalSizeClass == .compact ? 160 : 240
        #elseif os(macOS)
        320
        #else
        240
        #endif
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                Text("API Credentials")
                    .font(.title)

                Text("Edit the JSON below, or paste a full secrets export from Keychain. Use Save when done.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextEditor(text: $jsonText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: jsonEditorHeight, alignment: .topLeading)
                    .padding(6)
                    #if os(iOS)
                    .scrollContentBackground(.hidden)
                    #endif
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    )
                    .scrollIndicators(.visible)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick fields (optional — merge into JSON when editing)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("App ID", text: $appId)
                        .textFieldStyle(.roundedBorder)
                    TextField("App Secret", text: $appSecret)
                        .textFieldStyle(.roundedBorder)
                    TextField("Redirect URL", text: $redirectUrl)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 6) {
                        Button("Refresh fields from JSON") {
                            syncFieldsFromJsonText()
                        }
                        .font(.subheadline)
                        .help("Parse the JSON above and fill the three fields.")

                        Button("Merge fields into JSON") {
                            mergeFieldsIntoJsonEditor()
                        }
                        .font(.subheadline)
                        .help("Write App ID, Secret, and Redirect URL into the JSON above (keeps tokens and account hashes if JSON is valid).")
                    }
                }
                .frame(maxWidth: 520)

                HStack(alignment: .center) {
                    Button("Reset") {
                        resetCredentials()
                    }
                    .foregroundColor(.red)

                    Spacer(minLength: 16)

                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        saveCredentials()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.basedOnSize)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadFromSecretsManager()
        }
        .alert("Could not save", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func loadFromSecretsManager() {
        appId = secretsManager.secrets.appId
        appSecret = secretsManager.secrets.appSecret
        redirectUrl = secretsManager.secrets.redirectUrl.isEmpty ? "https://127.0.0.1" : secretsManager.secrets.redirectUrl
        jsonText = secretsManager.secrets.encodeToString() ?? "{}"
    }

    private func syncFieldsFromJsonText() {
        var raw = jsonText
        Secrets.removeSmartQuotes(secretStr: &raw)
        guard let data = raw.data(using: .utf8) else {
            saveErrorMessage = "Could not read text as UTF-8."
            showingSaveError = true
            return
        }
        do {
            let decoded = try JSONDecoder().decode(Secrets.self, from: data)
            appId = decoded.appId
            appSecret = decoded.appSecret
            redirectUrl = decoded.redirectUrl.isEmpty ? "https://127.0.0.1" : decoded.redirectUrl
        } catch {
            saveErrorMessage = "Invalid JSON: \(error.localizedDescription)"
            showingSaveError = true
        }
    }

    private func mergeFieldsIntoJsonEditor() {
        var raw = jsonText
        Secrets.removeSmartQuotes(secretStr: &raw)
        guard let data = raw.data(using: .utf8) else {
            saveErrorMessage = "Could not read text as UTF-8."
            showingSaveError = true
            return
        }
        do {
            let decoded = try JSONDecoder().decode(Secrets.self, from: data)
            decoded.appId = appId
            decoded.appSecret = appSecret
            decoded.redirectUrl = redirectUrl
            if let merged = decoded.encodeToString() {
                jsonText = merged
            }
        } catch {
            saveErrorMessage = "Invalid JSON: \(error.localizedDescription)"
            showingSaveError = true
        }
    }

    private func saveCredentials() {
        var raw = jsonText
        Secrets.removeSmartQuotes(secretStr: &raw)
        guard let data = raw.data(using: .utf8) else {
            saveErrorMessage = "Could not read text as UTF-8."
            showingSaveError = true
            return
        }
        do {
            let decoded = try JSONDecoder().decode(Secrets.self, from: data)
            secretsManager.secrets.appId = decoded.appId
            secretsManager.secrets.appSecret = decoded.appSecret
            secretsManager.secrets.redirectUrl = decoded.redirectUrl
            secretsManager.secrets.code = decoded.code
            secretsManager.secrets.session = decoded.session
            secretsManager.secrets.accessToken = decoded.accessToken
            secretsManager.secrets.refreshToken = decoded.refreshToken
            secretsManager.secrets.acountNumberHash = decoded.acountNumberHash
            secretsManager.saveSecrets()
            isPresented = false
        } catch {
            saveErrorMessage = "Invalid JSON: \(error.localizedDescription)"
            showingSaveError = true
        }
    }

    private func resetCredentials() {
        secretsManager.resetSecrets(partial: false)
        isPresented = false
    }
}
