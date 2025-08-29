import SwiftUI

struct CurrentOrdersTab: View {
    let symbol: String
    let orders: [Order]
    
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
                    CurrentOrdersSection(symbol: symbol, orders: orders)
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

#Preview("CurrentOrdersTab - With Orders", traits: .landscapeLeft) {
    VStack {
        createMockTabBar()
        CurrentOrdersTab(
            symbol: "AAPL",
            orders: createMockOrders()
        )
    }
}

#Preview("CurrentOrdersTab - No Orders", traits: .landscapeLeft) {
    VStack {
        createMockTabBar()
        CurrentOrdersTab(
            symbol: "XYZ",
            orders: []
        )
    }
}

// MARK: - Mock Data for Previews
private func createMockOrders() -> [Order] {
    let instrument = AccountsInstrument(
        assetType: .EQUITY,
        symbol: "AAPL",
        description: "Apple Inc. Common Stock"
    )
    
    let orderLeg = OrderLegCollection(
        instrument: instrument,
        instruction: .BUY_TO_OPEN,
        positionEffect: .OPENING,
        quantity: 2
    )
    
    let order = Order(
        orderType: .LIMIT,
        quantity: 2,
        price: 50.50,
        orderLegCollection: [orderLeg],
        orderStrategyType: .SINGLE,
        orderId: 12345,
        status: .working,
        enteredTime: "2025-01-15T09:30:00-05:00"
    )
    
    return [order]
}


@MainActor
private func createMockTabBar() -> some View {
    HStack(spacing: 0) {
        TabButton(
            title: "Details",
            icon: "info.circle",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Price History",
            icon: "chart.line.uptrend.xyaxis",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Transactions",
            icon: "list.bullet",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Sales Calc",
            icon: "calculator",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Orders",
            icon: "doc.text",
            isSelected: true,
            action: {}
        )
        TabButton(
            title: "OCO",
            icon: "arrow.up.circle",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Sequence",
            icon: "arrow.up.circle",
            isSelected: false,
            action: {}
        )
    }
    .background(Color.gray.opacity(0.1))
    .padding(.horizontal)
    .padding(.bottom, 2)
}
