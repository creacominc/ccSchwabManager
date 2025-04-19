//
//  SecretsEditorView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-19.
//

import Foundation
import SwiftUI

struct SecretsEditorView: View {
    @Binding var secretsStr: String
    var onRead: () -> Void
    var onSave: () -> Void

    var body: some View {
        VStack {
            TextEditor(text: $secretsStr)
                .padding()
                .foregroundStyle(.secondary)
                .navigationTitle("Secrets")
                .fixedSize(horizontal: false, vertical: true)
            
            Button("Read", action: onRead)
            
            Button("Save", action: onSave)
                .buttonStyle(.borderedProminent)
        }
    }
}
