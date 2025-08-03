//
//  DebugLogView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-11.
//

import SwiftUI

struct DebugLogView: View {
    @State private var logEntries: [String] = []
    @State private var isLoading = false
    @State private var refreshTokenRunning = false
    @State private var accessToken = ""
    @State private var refreshToken = ""
    @State private var code = ""
    
    var body: some View {
        VStack {
            HStack {
                Text("Debug Information")
                    .font(.title)
                Spacer()
                Button("Refresh") {
                    updateDebugInfo()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Authentication Status:")
                            .font(.headline)
                        Text("Access Token: \(accessToken.isEmpty ? "Empty" : "Present")")
                        Text("Refresh Token: \(refreshToken.isEmpty ? "Empty" : "Present")")
                        Text("Authorization Code: \(code.isEmpty ? "Empty" : "Present")")
                        Text("Refresh Token Running: \(refreshTokenRunning ? "Yes" : "No")")
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Loading States:")
                            .font(.headline)
                        Text("App Loading: \(isLoading ? "Yes" : "No")")
                        Text("SchwabClient Loading: \(SchwabClient.shared.isLoading ? "Yes" : "No")")
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Account Data:")
                            .font(.headline)
                        Text("Accounts Count: \(SchwabClient.shared.getAccounts().count)")
                        Text("Orders Count: \(SchwabClient.shared.getOrderList().count)")
                        Text("Symbols with Orders: \(SchwabClient.shared.getSymbolsWithOrders().count)")
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Order State:")
                            .font(.headline)
                        Button("Debug Order State") {
                            SchwabClient.shared.debugPrintOrderState()
                        }
                        .buttonStyle(.bordered)
                        
                        // Show some sample symbols with orders
                        let symbolsWithOrders = SchwabClient.shared.getSymbolsWithOrders()
                        if !symbolsWithOrders.isEmpty {
                            Text("Sample symbols with orders:")
                                .font(.subheadline)
                            ForEach(Array(symbolsWithOrders.prefix(5)), id: \.key) { symbol, statuses in
                                Text("  \(symbol): \(statuses.map { $0.shortDisplayName }.joined(separator: ", "))")
                                    .font(.caption)
                            }
                        } else {
                            Text("No symbols with orders found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Recent Log Entries:")
                            .font(.headline)
                        
                        ForEach(logEntries.suffix(20), id: \.self) { entry in
                            Text(entry)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Clear Loading States") {
                    SchwabClient.shared.clearLoadingState()
                    updateDebugInfo()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Clear All States") {
                    SchwabClient.shared.clearLoadingState()
                    updateDebugInfo()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .onAppear {
            updateDebugInfo()
        }
    }
    
    private func updateDebugInfo() {
        // Update authentication status using public methods
        let secrets = SchwabClient.shared.getSecrets()
        accessToken = secrets.accessToken.isEmpty ? "" : "Present"
        refreshToken = secrets.refreshToken.isEmpty ? "" : "Present"
        code = secrets.code.isEmpty ? "" : "Present"
        refreshTokenRunning = SchwabClient.shared.isRefreshTokenRunning
        isLoading = SchwabClient.shared.isLoading
        
        // Get recent log entries (this would need to be implemented in AppLogger)
        logEntries = ["Debug info updated at \(Date())"]
    }
} 