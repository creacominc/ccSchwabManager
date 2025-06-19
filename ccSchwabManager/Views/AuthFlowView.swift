//
//  AuthFlowView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

/**
 * AuthFlowView
 * 
 * This view handles the OAuth authentication flow with Schwab's API.
 * It guides users through the process of authorizing the app to access their Schwab account.
 * 
 * Layout:
 * - VStack with spacing of 20
 *   - Title text "Authentication Required"
 *   - Link to open Schwab login page (appears when URL is available)
 *   - Text field for pasting the authorization code
 *   - Submit button (disabled when code is empty)
 *   - Reset credentials button (red)
 * 
 * Functionality:
 * - On appear, generates and displays the Schwab authorization URL
 * - When user submits the auth code:
 *   1. Saves the code to secrets
 *   2. Fetches account numbers
 *   3. Updates secrets with account numbers
 *   4. Fetches account holdings
 * - Reset credentials button clears all API credentials and authentication data
 */

struct AuthFlowView: View {
    @EnvironmentObject var secretsManager: SecretsManager
    @Binding var authCode: String
    @State private var authUrl: URL?
    @State private var showingResetAlert = false
    @State private var showingCredentialsInput = false
    @State private var credentialsText = ""
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loadingState = LoadingState()
    
    var body: some View {
        VStack(spacing: 5) {
            if showingCredentialsInput {
                Text("Enter API Credentials")
                    .font(.title)
                
                TextEditor(text: $credentialsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding()

                Text("Format: appId=your_app_id\nappSecret=your_app_secret\nredirectUrl=your_redirect_url")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button("Save Credentials") {
                    saveCredentials()
                }
                .buttonStyle(.borderedProminent)
                .disabled(credentialsText.isEmpty)
            } else {
                Text("Authentication Required")
                    .font(.title)
                
                if let url = authUrl {
                    Link("Open Schwab Login", destination: url)
                        .buttonStyle(.borderedProminent)
                }

                TextField("Paste Authorization Code", text: $authCode)
                    .textFieldStyle(.roundedBorder)
                    .padding()
//                    .onChange(of: authCode) { oldValue, newValue in
//                        print( "changed authCode to \(newValue)" )
//                        print( "authCode = \(authCode)" )
//                    }

                Button("Submit") {
                    print( "--- submit button pressed ---" )
                    // if this button is pressed, reset the tokens
                    secretsManager.secrets.accessToken = ""
                    secretsManager.secrets.refreshToken = ""
                    // get the code from the pasted URL
                    handleAuthCode()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(authCode.isEmpty)
            }

            Spacer()

            Button("Reset All Credentials") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
            .padding(.bottom)
        }
        .padding()
        .alert("Reset Credentials", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                secretsManager.resetSecrets(partial: false)
                credentialsText = """
                appId=\(secretsManager.secrets.appId)
                appSecret=\(secretsManager.secrets.appSecret)
                redirectUrl=\(secretsManager.secrets.redirectUrl)
                """
                showingCredentialsInput = true
            }
        } message: {
            Text("Are you sure you want to reset all credentials? This will clear all API credentials and authentication data.")
        }
        .onAppear {
            // Connect loading state to SchwabClient
            SchwabClient.shared.loadingDelegate = loadingState
            
            if secretsManager.secrets.appId.isEmpty || 
               secretsManager.secrets.appSecret.isEmpty || 
               secretsManager.secrets.redirectUrl.isEmpty {
                credentialsText = """
                appId=\(secretsManager.secrets.appId)
                appSecret=\(secretsManager.secrets.appSecret)
                redirectUrl=\(secretsManager.secrets.redirectUrl)
                """
                showingCredentialsInput = true
            } else {
                // Get authorization URL from SchwabClient
                SchwabClient.shared.getAuthorizationUrl { result in
                    switch result {
                    case .success(let url):
                        authUrl = url
                    case .failure(let error):
                        secretsManager.error = error.localizedDescription
                    }
                }
            }
        }
        .withLoadingState(loadingState)
    }
    
    private func saveCredentials() {
        let lines = credentialsText.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "appId":
                    secretsManager.secrets.appId = value
                case "appSecret":
                    secretsManager.secrets.appSecret = value
                case "redirectUrl":
                    secretsManager.secrets.redirectUrl = value
                default:
                    break
                }
            }
        }
        secretsManager.saveSecrets()
        showingCredentialsInput = false
        
        // Get authorization URL after saving credentials
        SchwabClient.shared.getAuthorizationUrl { result in
            switch result {
            case .success(let url):
                authUrl = url
            case .failure(let error):
                secretsManager.error = error.localizedDescription
            }
        }
    }
    
    private func handleAuthCode() {
        // Extract the code from the URL
        print( "=== handleAuthCode ===" )
        if let code = extractCodeFromURL(authCode) {
            secretsManager.secrets.code = code
            secretsManager.saveSecrets()
            // Fetch account numbers and holdings
            Task {
                print("task started - fetching account numbers...")
                
                // Get access token if not already present
                if secretsManager.secrets.accessToken.isEmpty {
                    print("Getting initial access token...")
                    await withCheckedContinuation { continuation in
                        SchwabClient.shared.getAccessToken { result in
                            switch result {
                            case .success:
                                print("Successfully got access token")
                            case .failure(let error):
                                print("Failed to get access token: \(error.localizedDescription)")
                            }
                            continuation.resume()
                        }
                    }
                    secretsManager.saveSecrets()
                }

                await SchwabClient.shared.fetchAccountNumbers()

                // Update secrets with account numbers
                secretsManager.saveSecrets()

                // Fetch account holdings
                SchwabClient.shared.fetchAccounts( retry: true )
                
                // Force view update on main thread
                await MainActor.run {
                    secretsManager.objectWillChange.send()
                    dismiss()
                }
            }
        } else {
            // Handle invalid URL format
            print("Invalid authorization URL format")
        }
    }
    
    private func extractCodeFromURL(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }
} 
