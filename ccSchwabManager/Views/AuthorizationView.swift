//
//  AuthorizationView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-19.
//

import SwiftUI


struct AuthorizationView: View {
    @Binding var authorizationButtonUrl: URL
    @Binding var authenticateButtonEnabled: Bool
    @Binding var resultantUrl: String
    @State var extractCodeEnabled: Bool = false
    var onAuthorize: (String) -> Void

    @State private var authorizationButtonTitle: String = "Click to Authorize"

    var body: some View {
        VStack {
            // Authorization Link
            Link( authorizationButtonTitle, destination: authorizationButtonUrl)
                .disabled(!authenticateButtonEnabled)
                .opacity(authenticateButtonEnabled ? 1 : 0)
            
            // Authorization TextField
            TextField("After authorization, paste URL here.", text: $resultantUrl)
                .autocorrectionDisabled()
                .selectionDisabled( false )
                .padding(10)
                .onChange( of: resultantUrl )
                {
                    print( "OnChange URL: \( resultantUrl )" )
                    extractCodeEnabled = true
                }

            // Extract Code Button
            Button("Extract Code From URL") {
                onAuthorize( resultantUrl )
            }
            .disabled(!extractCodeEnabled)
            .buttonStyle(.bordered)
        }
    }
}
