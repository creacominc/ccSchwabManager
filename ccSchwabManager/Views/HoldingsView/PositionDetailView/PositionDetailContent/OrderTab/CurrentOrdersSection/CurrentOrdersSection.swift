import SwiftUI

struct CurrentOrdersSection: View {
    let symbol: String
    let orders: [Order]
    @State private var selectedOrderGroups: Set<Int64> = []
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingSuccessAlert = false
    
    private var openStatuses: [ActiveOrderStatus] {
        return [.awaitingParentOrder, .awaitingCondition, .awaitingSellStopCondition, .awaitingBuyStopCondition, .awaitingManualReview, 
                .accepted, .pendingActivation, .queued, .working, .new, .awaitingReleaseTime, 
                .pendingAcknowledgement, .pendingRecall]
    }
    
    private var currentOrders: [Order] {
        var filteredOrders: [Order] = []
        
        print("[CurrentOrdersSection] Checking open orders for symbol: \(symbol)")
        print("[CurrentOrdersSection] Total orders passed in: \(orders.count)")
        
        for order in orders {
            // Check if order matches the symbol
            var orderMatchesSymbol = false
            var hasOpenChildOrder = false
            
            // For OCO orders, check if any child orders are open and match the symbol
            if order.orderStrategyType == .OCO, let childOrderStrategies = order.childOrderStrategies {
                for childStrategy in childOrderStrategies {
                    if let legs = childStrategy.orderLegCollection {
                        for leg in legs {
                            if let instrument = leg.instrument, 
                               let symbol = instrument.symbol,
                               symbol == self.symbol {
                                orderMatchesSymbol = true
                                
                                // Check if this child order is open
                                if let childStatus = childStrategy.status,
                                   let childActiveStatus = ActiveOrderStatus(from: childStatus, order: childStrategy),
                                   openStatuses.contains(childActiveStatus) {
                                    hasOpenChildOrder = true
                                    break
                                }
                            }
                        }
                    }
                    if hasOpenChildOrder { break }
                }
            } else {
                // For non-OCO orders, check main order legs
                if let legs = order.orderLegCollection {
                    for leg in legs {
                        if let instrument = leg.instrument, 
                           let symbol = instrument.symbol,
                           symbol == self.symbol {
                            orderMatchesSymbol = true
                            break
                        }
                    }
                }
            }
            
            if orderMatchesSymbol {
                print("[CurrentOrdersSection] Found order for symbol \(self.symbol): ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil"), StrategyType=\(order.orderStrategyType?.rawValue ?? "nil")")
                
                // For OCO orders, only add if there are open child orders
                if order.orderStrategyType == .OCO {
                    if hasOpenChildOrder {
                        print("[CurrentOrdersSection] OCO order has open child orders")
                        filteredOrders.append(order)
                    } else {
                        print("[CurrentOrdersSection] OCO order has no open child orders")
                    }
                } else {
                    // For non-OCO orders, check if order status is open
                    if let status = order.status,
                       let activeStatus = ActiveOrderStatus(from: status, order: order),
                       openStatuses.contains(activeStatus) {
                        print("[CurrentOrdersSection] Order is open: \(activeStatus.shortDisplayName)")
                        filteredOrders.append(order)
                    } else {
                        print("[CurrentOrdersSection] Order is not open: \(order.status?.rawValue ?? "nil")")
                    }
                }
            }
        }
        
        print("[CurrentOrdersSection] Found \(filteredOrders.count) open orders for symbol \(symbol)")
        
        // // Debug: Print all order IDs being returned
        // print("[CurrentOrdersSection] Order IDs being returned:")
        // for (index, order) in filteredOrders.enumerated() {
        //     print("[CurrentOrdersSection]   \(index + 1). ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil")")
        // }
        
        return filteredOrders
    }
    
    private func performCancellations() {
        let orderIds = Array(selectedOrderGroups)
        
        Task {
            let result = await SchwabClient.shared.cancelOrders(orderIds: orderIds)
            
            await MainActor.run {
                if result.success {
                    // Clear selected orders and show success message
                    selectedOrderGroups.removeAll()
                    showingSuccessAlert = true
                } else {
                    // Show error message
                    errorMessage = result.errorMessage ?? "Unknown error occurred"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Current Orders")
                    .font(.headline)
                
                Spacer()
                
                Button(selectedOrderGroups.count == currentOrders.count ? "Deselect All" : "Select All") {
                    if selectedOrderGroups.count == currentOrders.count {
                        // Deselect all
                        selectedOrderGroups.removeAll()
                    } else {
                        // Select all
                        let allOrderIds = currentOrders.compactMap { $0.orderId }
                        selectedOrderGroups = Set(allOrderIds)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentOrders.isEmpty)
            }
            .padding(.horizontal)
            
            if currentOrders.isEmpty {
                Text("No open orders for \(symbol)")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .onAppear {
                        print("[CurrentOrdersSection] No open orders for symbol: \(symbol)")
                    }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    // Orders list
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(currentOrders) { order in
                                OrderGroupView(
                                    order: order,
                                    selectedOrderGroups: $selectedOrderGroups
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Cancel button on the right
                    if !selectedOrderGroups.isEmpty {
                        VStack {
                            Button(action: performCancellations) {
                                VStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                    Text("Cancel\nSelected")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                            }
                            Spacer()
                        }
                        .padding(.trailing, 8)
                    }
                }
            }
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .alert("Order Cancellation Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Orders Cancelled", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Selected orders have been successfully cancelled.")
        }
    }
}

#Preview("CurrentOrdersSection - With Orders", traits: .landscapeLeft) {
    CurrentOrdersSection(symbol: "AAPL", orders: createMockOrders())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}

#Preview("CurrentOrdersSection - No Orders", traits: .landscapeLeft) {
    CurrentOrdersSection(symbol: "XYZ", orders: [])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}

#Preview("CurrentOrdersSection - Multiple Order Types", traits: .landscapeLeft) {
    CurrentOrdersSection(symbol: "TSLA", orders: createMockOCOOrders())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        quantity: 100
    )
    
    let order = Order(
        orderType: .LIMIT,
        quantity: 100,
        price: 150.50,
        orderLegCollection: [orderLeg],
        orderStrategyType: .SINGLE,
        orderId: 12345,
        status: .working,
        enteredTime: "2025-01-15T09:30:00-05:00"
    )
    
    return [order]
}

private func createMockOCOOrders() -> [Order] {
    let instrument1 = AccountsInstrument(
        assetType: .EQUITY,
        symbol: "TSLA",
        description: "Tesla Inc. Common Stock"
    )
    
    let instrument2 = AccountsInstrument(
        assetType: .EQUITY,
        symbol: "TSLA",
        description: "Tesla Inc. Common Stock"
    )
    
    let orderLeg1 = OrderLegCollection(
        instrument: instrument1,
        instruction: .SELL_TO_CLOSE,
        positionEffect: .CLOSING,
        quantity: 50
    )
    
    let orderLeg2 = OrderLegCollection(
        instrument: instrument2,
        instruction: .SELL_TO_CLOSE,
        positionEffect: .CLOSING,
        quantity: 50
    )
    
    let childOrder1 = Order(
        orderType: .STOP,
        quantity: 50,
        stopPrice: 200.00,
        orderLegCollection: [orderLeg1],
        orderStrategyType: .SINGLE,
        orderId: 67891,
        status: .awaitingParentOrder,
        enteredTime: "2025-01-15T09:30:00-05:00"
    )
    
    let childOrder2 = Order(
        orderType: .LIMIT,
        quantity: 50,
        price: 250.00,
        orderLegCollection: [orderLeg2],
        orderStrategyType: .SINGLE,
        orderId: 67892,
        status: .awaitingParentOrder,
        enteredTime: "2025-01-15T09:30:00-05:00"
    )
    
    let ocoOrder = Order(
        orderType: .LIMIT,
        quantity: 100,
        orderLegCollection: [orderLeg1, orderLeg2],
        orderStrategyType: .OCO,
        orderId: 67890,
        status: .working,
        enteredTime: "2025-01-15T09:30:00-05:00",
        childOrderStrategies: [childOrder1, childOrder2]
    )
    
    return [ocoOrder]
}



 

 
