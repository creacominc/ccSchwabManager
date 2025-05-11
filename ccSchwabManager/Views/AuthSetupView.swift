//
//  AuthSetupView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

/**
 * AuthSetupView
 * 
 * This view is displayed when the app is first launched and no API credentials are set.
 * It presents a welcome message and a button to enter Schwab API credentials.
 * 
 * Layout:
 * - VStack with spacing of 20
 *   - Title text "Welcome to ccSchwabManager"
 *   - Subtitle text prompting for API credentials
 *   - "Enter Credentials" button that triggers the auth dialog
 * 
 * When the credentials button is tapped, it shows an authentication dialog
 * where users can enter their Schwab API credentials.
 */

struct AuthSetupView: View {
    @EnvironmentObject var secretsManager: SecretsManager
    @Binding var showingAuthDialog: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to ccSchwabManager")
                .font(.title)
            
            Text("Please enter your Schwab API credentials !!")
                .font(.headline)
            
            Button("Enter Credentials ") {
                showingAuthDialog = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
} 
