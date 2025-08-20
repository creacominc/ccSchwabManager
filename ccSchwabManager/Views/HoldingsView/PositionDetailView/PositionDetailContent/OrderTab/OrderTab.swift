import SwiftUI

struct OrderTab: View {
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let quoteData: QuoteData?
    let geometry: GeometryProxy
    let accountNumber: String
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Section 1: Current Orders
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
//                .overlay(
//                    RoundedRectangle(cornerRadius: 8)
//                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
//                )
                
                // Section 2: Recommended Orders (Single or OCO)
                VStack(alignment: .leading, spacing: 0) {
                    // Section Header
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.green)
                        Text("Recommended Orders")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    
                    // Section Content
                    RecommendedOCOOrdersSection(
                        symbol: symbol,
                        atrValue: atrValue,
                        taxLotData: taxLotData,
                        sharesAvailableForTrading: sharesAvailableForTrading,
                        quoteData: quoteData,
                        accountNumber: accountNumber
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 8)
//                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
//                )
                
                // Section 3: Buy Sequence Orders
                VStack(alignment: .leading, spacing: 0) {
                    // Section Header
                    HStack {
                        Image(systemName: "arrow.up.circle")
                            .foregroundColor(.orange)
                        Text("Buy Sequence Orders")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    
                    // Section Content
                    BuySequenceOrdersSection(
                        symbol: symbol,
                        atrValue: atrValue,
                        taxLotData: taxLotData,
                        sharesAvailableForTrading: sharesAvailableForTrading,
                        quoteData: quoteData,
                        accountNumber: accountNumber
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 8)
//                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
//                )
                
                // Add bottom padding to ensure last section is fully visible
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.black.opacity(0.1))
        .tabItem {
            Image(systemName: "list.bullet")
            Text("Orders")
        }
    }
} 
