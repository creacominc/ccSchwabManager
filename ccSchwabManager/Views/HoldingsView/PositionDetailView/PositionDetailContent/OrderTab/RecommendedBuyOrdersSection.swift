import SwiftUI

struct RecommendedBuyOrdersSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended Buy Orders")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Buy order recommendations coming soon...")
                .foregroundColor(.secondary)
                .padding()
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
} 