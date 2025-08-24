import SwiftUI

struct OrderGroupView: View {
    let order: Order
    @Binding var selectedOrderGroups: Set<Int64>
    
    private var openStatuses: [OrderStatus] {
        return [.awaitingParentOrder, .awaitingCondition, .awaitingStopCondition, .awaitingManualReview, 
                .accepted, .pendingActivation, .queued, .working, .new, .awaitingReleaseTime, 
                .pendingAcknowledgement, .pendingRecall]
    }
    
    private var displayableOrders: [Order] {
        var orders: [Order] = []
        
        func collectOrdersRecursively(_ order: Order) {
            // Add the current order if it's open and has order legs (or is not an OCO parent)
            if let status = order.status, openStatuses.contains(status) {
                // For OCO parent orders, only add if they have order legs
                if order.orderStrategyType == .OCO {
                    if let orderLegs = order.orderLegCollection, !orderLegs.isEmpty {
                        orders.append(order)
                    }
                } else {
                    orders.append(order)
                }
            }
            // Recursively add child orders for TRIGGER and OCO
            if let childStrategies = order.childOrderStrategies, !childStrategies.isEmpty {
                for child in childStrategies {
                    collectOrdersRecursively(child)
                }
            }
        }
        
        collectOrdersRecursively(order)
        // Sort: active order (not AWAITING_PARENT_ORDER) first, then children
        let sorted = orders.sorted { lhs, rhs in
            let lhsIsParent = lhs.status != .awaitingParentOrder
            let rhsIsParent = rhs.status != .awaitingParentOrder
            if lhsIsParent == rhsIsParent {
                return (lhs.enteredTime ?? "") < (rhs.enteredTime ?? "")
            }
            return lhsIsParent && !rhsIsParent
        }
        return sorted
    }
    
    private var groupOrderId: Int64? {
        // For OCO orders, use the parent order ID
        if order.orderStrategyType == .OCO {
            return order.orderId
        } else {
            // For single orders, use the order ID
            return order.orderId
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if displayableOrders.count > 1 {
                HStack(alignment: .top, spacing: 8) {
                    // Checkbox for the entire group
                    Button(action: {
                        if let groupId = groupOrderId {
                            if selectedOrderGroups.contains(groupId) {
                                selectedOrderGroups.remove(groupId)
                            } else {
                                selectedOrderGroups.insert(groupId)
                            }
                        }
                    }) {
                        Image(systemName: groupOrderId != nil && selectedOrderGroups.contains(groupOrderId!) ? "checkmark.square.fill" : "square")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Vertical line spanning all orders, dynamically sized
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 2)
                                .frame(height: geometry.size.height)
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(width: 10)
                    .padding(.vertical, 0)

                    // Order details
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(displayableOrders, id: \.orderId) { displayOrder in
                            OrderDetailRow(order: displayOrder, groupOrderId: groupOrderId)
                                .padding(.vertical, 2)
                        }
                    }
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: OrderGroupHeightKey.self, value: geo.size.height)
                    })
                    .onPreferenceChange(OrderGroupHeightKey.self) { _ in }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(6)
            } else if let singleOrder = displayableOrders.first {
                // Single order - show without vertical line
                HStack(alignment: .top, spacing: 8) {
                    // Checkbox
                    Button(action: {
                        if let groupId = groupOrderId {
                            if selectedOrderGroups.contains(groupId) {
                                selectedOrderGroups.remove(groupId)
                            } else {
                                selectedOrderGroups.insert(groupId)
                            }
                        }
                    }) {
                        Image(systemName: groupOrderId != nil && selectedOrderGroups.contains(groupOrderId!) ? "checkmark.square.fill" : "square")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Order details
                    OrderDetailRow(order: singleOrder, groupOrderId: groupOrderId)
                        .padding(.vertical, 2)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .onAppear {
            print("[OrderGroupView] Rendering order group: ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil")")
        }
    }
}

#Preview("OrderGroupView - Single Order", traits: .landscapeLeft) {
    OrderGroupView(
        order: createSampleSingleOrder(),
        selectedOrderGroups: .constant(Set<Int64>())
    )
    .frame(width: .infinity)
    .padding(.vertical)
}

#Preview("OrderGroupView - Multiple Orders (OCO)", traits: .landscapeLeft) {
    OrderGroupView(
        order: createSampleOCOOrder(),
        selectedOrderGroups: .constant(Set<Int64>())
    )
    .frame(width: .infinity)
    .padding(.vertical)
}

#Preview("OrderGroupView - Multiple Orders (TRIGGER)", traits: .landscapeLeft) {
    OrderGroupView(
        order: createSampleTriggerOrder(),
        selectedOrderGroups: .constant(Set<Int64>())
    )
    .frame(width: .infinity)
    .padding(.vertical)
}

// MARK: - Sample Data Creation
private func createSampleSingleOrder() -> Order {
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
    
    return Order(
        orderType: .LIMIT,
        quantity: 100,
        price: 150.50,
        orderLegCollection: [orderLeg],
        orderStrategyType: .SINGLE,
        orderId: 12345,
        status: .working,
        enteredTime: "2025-01-15T09:30:00-05:00"
    )
}

private func createSampleOCOOrder() -> Order {
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
    
    return Order(
        orderType: .LIMIT,
        quantity: 100,
        orderLegCollection: [orderLeg1, orderLeg2],
        orderStrategyType: .OCO,
        orderId: 67890,
        status: .working,
        enteredTime: "2025-01-15T09:30:00-05:00",
        childOrderStrategies: [childOrder1, childOrder2]
    )
}

private func createSampleTriggerOrder() -> Order {
    let instrument = AccountsInstrument(
        assetType: .EQUITY,
        symbol: "NVDA",
        description: "NVIDIA Corporation Common Stock"
    )
    
    let orderLeg = OrderLegCollection(
        instrument: instrument,
        instruction: .BUY_TO_OPEN,
        positionEffect: .OPENING,
        quantity: 25
    )
    
    let childOrder = Order(
        orderType: .LIMIT,
        quantity: 25,
        price: 500.00,
        orderLegCollection: [orderLeg],
        orderStrategyType: .SINGLE,
        orderId: 11112,
        status: .awaitingParentOrder,
        enteredTime: "2025-01-15T09:30:00-05:00"
    )
    
    return Order(
        orderType: .LIMIT,
        quantity: 25,
        orderLegCollection: [orderLeg],
        activationPrice: 450.00,
        orderStrategyType: .TRIGGER,
        orderId: 11111,
        status: .working,
        enteredTime: "2025-01-15T09:30:00-05:00",
        childOrderStrategies: [childOrder]
    )
}
