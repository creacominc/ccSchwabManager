import SwiftUI

/// Component responsible for the submit button and order submission logic
struct SubmitButtonSection: View {
    
    // MARK: - Properties
    let hasSelectedOrders: Bool
    let onSubmit: () -> Void
    
    // MARK: - Body
    var body: some View {
        VStack {
            if hasSelectedOrders {
                Button(action: onSubmit) {
                    VStack(spacing: 4) {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.title3)
                        Text("Submit\nOrder")
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "paperplane.circle")
                        .font(.title3)
                    Text("Submit")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.secondary)
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .frame(width: 40)
        .padding(.leading, 16)
    }
}

// MARK: - Previews
#Preview("SubmitButtonSection - With Selection") {
    SubmitButtonSection(
        hasSelectedOrders: true,
        onSubmit: {}
    )
    .padding()
}

#Preview("SubmitButtonSection - No Selection") {
    SubmitButtonSection(
        hasSelectedOrders: false,
        onSubmit: {}
    )
    .padding()
}
