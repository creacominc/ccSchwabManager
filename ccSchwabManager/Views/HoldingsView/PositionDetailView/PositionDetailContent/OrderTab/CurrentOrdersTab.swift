import SwiftUI

struct CurrentOrdersTab: View {
    let symbol: String
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Current Orders Section
                VStack(alignment: .leading, spacing: 0) {
                    // Section Header
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.blue)
                        Text("Current Orders")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    
                    // Section Content
                    CurrentOrdersSection(symbol: symbol)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                // Add bottom padding to ensure content is fully visible
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.black.opacity(0.1))
    }
}
