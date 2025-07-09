import SwiftUI

struct CurrentOrdersSection: View {
    let symbol: String
    
    private var openStatuses: [ActiveOrderStatus] {
        return [.awaitingParentOrder, .awaitingCondition, .awaitingSellStopCondition, .awaitingBuyStopCondition, .awaitingManualReview, 
                .accepted, .pendingActivation, .queued, .working, .new, .awaitingReleaseTime, 
                .pendingAcknowledgement, .pendingRecall]
    }
    
    private var currentOrders: [Order] {
        let allOrders = SchwabClient.shared.getOrderList()
        var filteredOrders: [Order] = []
        
        print("[OrderTab] Checking open orders for symbol: \(symbol)")
        print("[OrderTab] Total orders from SchwabClient: \(allOrders.count)")
        
        for order in allOrders {
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
                print("[OrderTab] Found order for symbol \(self.symbol): ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil"), StrategyType=\(order.orderStrategyType?.rawValue ?? "nil")")
                
                // For OCO orders, only add if there are open child orders
                if order.orderStrategyType == .OCO {
                    if hasOpenChildOrder {
                        print("[OrderTab] OCO order has open child orders")
                        filteredOrders.append(order)
                    } else {
                        print("[OrderTab] OCO order has no open child orders")
                    }
                } else {
                    // For non-OCO orders, check if order status is open
                    if let status = order.status,
                       let activeStatus = ActiveOrderStatus(from: status, order: order),
                       openStatuses.contains(activeStatus) {
                        print("[OrderTab] Order is open: \(activeStatus.shortDisplayName)")
                        filteredOrders.append(order)
                    } else {
                        print("[OrderTab] Order is not open: \(order.status?.rawValue ?? "nil")")
                    }
                }
            }
        }
        
        print("[OrderTab] Found \(filteredOrders.count) open orders for symbol \(symbol)")
        
        // Debug: Print all order IDs being returned
        print("[OrderTab] Order IDs being returned:")
        for (index, order) in filteredOrders.enumerated() {
            print("[OrderTab]   \(index + 1). ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil")")
        }
        
        return filteredOrders
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Orders")
                .font(.headline)
                .padding(.horizontal)
            
            if currentOrders.isEmpty {
                Text("No open orders for \(symbol)")
                    .foregroundColor(.secondary)
                    .padding()
                    .onAppear {
                        print("[OrderTab] No open orders for symbol: \(symbol)")
                    }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(currentOrders) { order in
                            let detailedDescription = OrderStatusFormatter.formatDetailedOrderDescription(order: order)
                            Text(detailedDescription)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(6)
                                .padding(.horizontal)
                                .onAppear {
                                    print("[OrderTab] Rendering order: ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil"), StrategyType=\(order.orderStrategyType?.rawValue ?? "nil")")
                                    print("[OrderTab] Description: \(detailedDescription)")
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
} 