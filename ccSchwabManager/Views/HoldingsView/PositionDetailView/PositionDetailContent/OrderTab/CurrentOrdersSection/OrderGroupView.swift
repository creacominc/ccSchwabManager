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
            print("[OrderTab] Rendering order group: ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil")")
        }
    }
}
