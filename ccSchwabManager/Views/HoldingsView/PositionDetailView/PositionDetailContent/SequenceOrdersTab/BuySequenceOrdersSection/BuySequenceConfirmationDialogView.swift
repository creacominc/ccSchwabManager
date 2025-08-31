import SwiftUI

struct BuySequenceConfirmationDialogView: View {
    let orderDescriptions: [String]
    let orderJson: String
    let onCancel: () -> Void
    let onSubmit: () -> Void
    let trailingStopValidation: (() -> String?)? // Returns error message if validation fails, nil if passes
    
    var body: some View {
        // Use the enhanced OrderConfirmationDialog with trailing stop validation
        OrderConfirmationDialog(
            isPresented: .constant(true), // This will be managed by the parent view
            orderDescriptions: orderDescriptions,
            orderJson: orderJson,
            onConfirm: onSubmit,
            onCancel: onCancel,
            trailingStopValidation: trailingStopValidation
        )
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
        onSubmit: {},
        trailingStopValidation: nil // No specific validation for this preview
    )
}
