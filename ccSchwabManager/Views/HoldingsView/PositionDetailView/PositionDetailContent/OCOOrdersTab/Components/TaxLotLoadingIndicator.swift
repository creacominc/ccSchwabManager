import SwiftUI

/// Component responsible for displaying the tax lot loading progress
struct TaxLotLoadingIndicator: View {
    
    // MARK: - Properties
    let isLoading: Bool
    let progress: Double
    let message: String
    let onCancel: () -> Void
    
    // MARK: - Body
    var body: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(maxWidth: .infinity)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Previews
#Preview("TaxLotLoadingIndicator - Loading") {
    TaxLotLoadingIndicator(
        isLoading: true,
        progress: 0.5,
        message: "Processing tax lot data...",
        onCancel: {}
    )
    .padding()
}

#Preview("TaxLotLoadingIndicator - Not Loading") {
    TaxLotLoadingIndicator(
        isLoading: false,
        progress: 0.0,
        message: "",
        onCancel: {}
    )
    .padding()
}
