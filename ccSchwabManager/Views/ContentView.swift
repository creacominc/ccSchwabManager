//
//  ContentView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

struct ContentView: View
{
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var showingAuthDialog = false
    @State private var authCode = ""
    @State private var selectedTab = 0
    
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
                    
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(1)
                }
            }
        }
        .alert("Authentication Required", isPresented: $showingAuthDialog) {
            Button("OK") { }
        } message: {
            Text("Please enter your Schwab API credentials")
        }
    }
}

struct AuthSetupView: View
{
    @EnvironmentObject var secretsManager: SecretsManager
    @Binding var showingAuthDialog: Bool
    
    var body: some View
    {
        VStack(spacing: 20) {
            Text("Welcome to ccSchwabManager")
                .font(.title)
            
            Text("Please enter your Schwab API credentials")
                .font(.headline)
            
            Button("Enter Credentials") {
                showingAuthDialog = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct AuthFlowView: View
{
    @EnvironmentObject var secretsManager: SecretsManager
    @Binding var authCode: String
    @State private var authUrl: URL?
    
    var body: some View
    {
        VStack(spacing: 20) {
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
                handleAuthCode()
            }
            .buttonStyle(.borderedProminent)
            .disabled(authCode.isEmpty)
        }
        .padding()
        .onAppear {
            // Get authorization URL from SchwabClient
            let schwabClient = SchwabClient(secrets: &secretsManager.secrets)
            schwabClient.getAuthorizationUrl { result in
                switch result {
                case .success(let url):
                    authUrl = url
                case .failure(let error):
                    secretsManager.error = error.localizedDescription
                }
            }
        }
    }
    
    private func handleAuthCode() {
        secretsManager.secrets.code = authCode
        secretsManager.saveSecrets()
        
        // Fetch account numbers and holdings
        Task {
//            do {
                let schwabClient = SchwabClient(secrets: &secretsManager.secrets)
                await schwabClient.fetchAccountNumbers()
                
                // Update secrets with account numbers
                secretsManager.saveSecrets()
                
                // Fetch account holdings
                await schwabClient.fetchAccounts()
//            } catch {
//                secretsManager.error = error.localizedDescription
//            }
        }
    }
}

struct HoldingsView: View
{
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var holdings: [Position] = []
    @State private var sortOrder: [KeyPathComparator<Position>] = []
    @State private var searchText = ""

    var filteredHoldings: [Position] {
        holdings.filter { position in
            searchText.isEmpty ||
            ((position.instrument?.symbol?.localizedCaseInsensitiveContains(searchText)) != nil) ||
            ((position.instrument?.description?.localizedCaseInsensitiveContains(searchText)) != nil)
        }
    }

    var body: some View
    {
        NavigationView {
            Table(filteredHoldings, sortOrder: $sortOrder) {
                TableColumn("Symbol") { (position: Position) in
                    Text(position.instrument?.symbol ?? "")
                }
                TableColumn("Description") { (position: Position) in
                    Text(position.instrument?.description ?? "")
                }
                TableColumn("Quantity") { (position: Position) in
                    Text(String(format: "%.2f", position.longQuantity ?? 0.0))
                }
                TableColumn("Avg Price") { (position: Position) in
                    Text(String(format: "%.2f", position.averagePrice ?? 0.0))
                }
                TableColumn("Market Value") { (position: Position) in
                    Text(String(format: "%.2f", position.marketValue ?? 0.0))
                }
                TableColumn("P/L") { (position: Position) in
                    Text(String(format: "%.2f", position.longOpenProfitLoss ?? 0.0))
                }
                TableColumn("Asset Type") { (position: Position) in
                    Text(position.instrument?.assetType?.rawValue ?? "")
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Holdings")
        }
        .task {
            // Fetch holdings when view appears
            await fetchHoldings()
        }
    }
    
    private func fetchHoldings() async {
        print( "=== fetchHoldings ===" )
//        do {
            let schwabClient = SchwabClient(secrets: &secretsManager.secrets)
            await schwabClient.fetchAccounts()
            
            // Extract positions from accounts
            holdings = schwabClient.getAccounts().flatMap { $0.securitiesAccount?.positions ?? [] }
            // print the first holding to verify
        print( "count of holding:  \(holdings.count)" )
//        } catch {
//            secretsManager.error = error.localizedDescription
//        }
    }
}

struct SettingsView: View
{
    @EnvironmentObject var secretsManager: SecretsManager
    
    var body: some View
    {
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


