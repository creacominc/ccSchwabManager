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
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loadingState = LoadingState()
    
    var body: some View {
        VStack(spacing: 5) {
            Text("Authentication Required")
                .font(.title)
            
            if let url = authUrl {
                Link("Open Schwab Login", destination: url)
                    .buttonStyle(.borderedProminent)
            }

            TextField("Paste Authorization Code", text: $authCode)
                .textFieldStyle(.roundedBorder)
                .padding()

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

            Spacer()

            Button("Reset All Credentials") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
            .padding(.bottom)
        }
        .padding()
        .sheet(isPresented: $showingCredentialsInput) {
            CredentialsInputView(isPresented: $showingCredentialsInput)
                .onDisappear {
                    // Force view update to check conditions again
                    secretsManager.objectWillChange.send()
                }
        }
        .alert("Reset Credentials", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                secretsManager.resetSecrets(partial: false)
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
                    SchwabClient.shared.getAccessToken { result in
                        switch result {
                        case .success:
                            print("Successfully got access token")
                        case .failure(let error):
                            print("Failed to get access token: \(error.localizedDescription)")
                        }
                    }
                    secretsManager.saveSecrets()
                }

                await SchwabClient.shared.fetchAccountNumbers()

                // Update secrets with account numbers
                secretsManager.saveSecrets()

                // Fetch account holdings
                await SchwabClient.shared.fetchAccounts( retry: true )
                
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
