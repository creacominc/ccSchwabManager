//
//  HoldingsSearchBar.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

struct HoldingsSearchBar: View {
    @Binding var searchText: String
    @Binding var isSearchVisible: Bool
    var isSearchFieldFocused: FocusState<Bool>.Binding
    
    var body: some View {
        #if os(iOS)
        // Top controls for showing/hiding search and keyboard on iPhone
        HStack {
            Button(action: {
                withAnimation {
                    isSearchVisible.toggle()
                }
                if isSearchVisible {
                    // Focus when opening search
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isSearchFieldFocused.wrappedValue = true
                    }
                } else {
                    // Dismiss keyboard when hiding search
                    isSearchFieldFocused.wrappedValue = false
                }
            }) {
                Label(isSearchVisible ? "Hide Search" : "Show Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if isSearchFieldFocused.wrappedValue {
                Button(action: { isSearchFieldFocused.wrappedValue = false }) {
                    Label("Hide Keyboard", systemImage: "keyboard")
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Network indicator showing WiFi or Cellular signal strength
            NetworkIndicatorView()
                .padding(.trailing, 8)
        }
        .padding(.horizontal)
        .padding(.top, 8)

        if isSearchVisible {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by symbol or description", text: $searchText)
                        .focused(isSearchFieldFocused)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .onSubmit {
                            // Optional: Handle search submission
                        }
                        .onKeyPress(.delete) {
                            searchText = ""
                            return .handled
                        }
                        .onKeyPress(KeyEquivalent("\u{08}")) { // Backspace character
                            searchText = ""
                            return .handled
                        }
                        .onKeyPress { keyPress in
                            // Handle alphanumeric input for search
                            let character = keyPress.characters.first
                            if let char = character, char.isLetter || char.isNumber || char.isWhitespace || char.isPunctuation {
                                searchText += String(char)
                                return .handled
                            }
                            return .ignored
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Button(action: {
                    withAnimation { isSearchVisible = false }
                    isSearchFieldFocused.wrappedValue = false
                }) {
                    Image(systemName: "chevron.up.circle")
                        .foregroundColor(.secondary)
                        .padding(.leading, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        #endif
    }
}
