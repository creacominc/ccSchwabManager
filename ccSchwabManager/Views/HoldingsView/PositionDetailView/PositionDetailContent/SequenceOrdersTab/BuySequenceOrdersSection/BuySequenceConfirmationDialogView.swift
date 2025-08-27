import SwiftUI

struct BuySequenceConfirmationDialogView: View {
    let orderDescriptions: [String]
    let orderJson: String
    let onCancel: () -> Void
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Confirm Buy Sequence Order Submission")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Order Descriptions Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Please review the following sequence orders before submission:")
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
                //.frame(maxHeight: 150)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action Buttons
            HStack {
                Spacer()
                
                Button("Submit Order") {
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
    }
}

#Preview("Order Confirmation Dialog", traits: .landscapeLeft) {
    BuySequenceConfirmationDialogView(
        orderDescriptions: [
            "Order 1 (BUY): BUY 5 AAPL Target=150.00 Entry=142.50 TS=5.0% Cost=750.00",
            "Order 2 (BUY): BUY 5 AAPL Target=145.00 Entry=137.75 TS=5.0% Cost=725.00"
        ],
        orderJson: """
        {
          "symbol": "AAPL",
          "orders": [
            {
              "shares": 5,
              "targetPrice": 150.00,
              "entryPrice": 142.50,
              "trailingStop": 5.0
            }
          ]
        }
        """,
        onCancel: {},
        onSubmit: {}
    )
}
