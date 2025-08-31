import SwiftUI

/// Component responsible for displaying the order confirmation dialog
struct OrderConfirmationDialog: View {
    
    // MARK: - Properties
    let isPresented: Binding<Bool>
    let orderDescriptions: [String]
    let orderJson: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let trailingStopValidation: (() -> String?)? // Returns error message if validation fails, nil if passes
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Confirm Order Submission")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Trailing Stop Validation Error (if any)
            if let validationError = trailingStopValidation?() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(validationError)
                        .foregroundColor(.red)
                        .font(.headline)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Order Descriptions Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Please review the following orders before submission:")
                    .font(.headline)
                
                if orderDescriptions.isEmpty {
                    Text("No order descriptions available")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(orderDescriptions.enumerated()), id: \.offset) { index, description in
                            Text(description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // JSON Section
            VStack(alignment: .leading, spacing: 8) {
                Text("JSON to be submitted:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ScrollView {
                    Text(orderJson.isEmpty ? "No JSON available" : orderJson)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action Buttons
            HStack {
                Spacer()
                
                Button("Submit Order") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(trailingStopValidation?() != nil) // Disable if validation fails
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 600, minHeight: 400)
        .padding()
    }
}

// MARK: - Previews
#Preview("OrderConfirmationDialog - With Data") {
    OrderConfirmationDialog(
        isPresented: .constant(true),
        orderDescriptions: [
            "Order 1 (SELL): (Top 100) SELL -100 AAPL Target 157.50 TS 2.50% Cost/Share 150.00",
            "Order 2 (BUY): BUY 50 AAPL (5%) Target=149.00 TS=2.5% Gain=10.0% Cost=7450.00"
        ],
        orderJson: """
        {
          "symbol": "AAPL",
          "orders": [
            {
              "type": "SELL",
              "shares": 100,
              "target": 157.50
            }
          ]
        }
        """,
        onConfirm: {},
        onCancel: {},
        trailingStopValidation: nil
    )
}

#Preview("OrderConfirmationDialog - Empty") {
    OrderConfirmationDialog(
        isPresented: .constant(true),
        orderDescriptions: [],
        orderJson: "",
        onConfirm: {},
        onCancel: {},
        trailingStopValidation: nil
    )
}
