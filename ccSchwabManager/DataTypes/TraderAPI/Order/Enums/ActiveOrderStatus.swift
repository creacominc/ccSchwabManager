//
//  ActiveOrderStatus.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-06-29.
//

import Foundation

/**
 * ActiveOrderStatus - represents only the order statuses that indicate active/waiting orders
 * Ordered by priority for display purposes (most important first)
 */
public enum ActiveOrderStatus: String, Codable, CaseIterable {
    case working = "WORKING"
    case awaitingSellStopCondition = "AWAITING_SELL_STOP_CONDITION"
    case awaitingBuyStopCondition = "AWAITING_BUY_STOP_CONDITION"
    case awaitingCondition = "AWAITING_CONDITION"
    case awaitingManualReview = "AWAITING_MANUAL_REVIEW"
    case awaitingParentOrder = "AWAITING_PARENT_ORDER"
    case accepted = "ACCEPTED"
    case pendingActivation = "PENDING_ACTIVATION"
    case queued = "QUEUED"
    case new = "NEW"
    case awaitingReleaseTime = "AWAITING_RELEASE_TIME"
    case pendingAcknowledgement = "PENDING_ACKNOWLEDGEMENT"
    case pendingRecall = "PENDING_RECALL"
    
    // Convert from OrderStatus to ActiveOrderStatus
    init?(from orderStatus: OrderStatus) {
        switch orderStatus {
        case .working:
            self = .working
        case .awaitingStopCondition:
            // This will be handled by the order-specific initializer
            return nil
        case .awaitingCondition:
            self = .awaitingCondition
        case .awaitingManualReview:
            self = .awaitingManualReview
        case .awaitingParentOrder:
            self = .awaitingParentOrder
        case .accepted:
            self = .accepted
        case .pendingActivation:
            self = .pendingActivation
        case .queued:
            self = .queued
        case .new:
            self = .new
        case .awaitingReleaseTime:
            self = .awaitingReleaseTime
        case .pendingAcknowledgement:
            self = .pendingAcknowledgement
        case .pendingRecall:
            self = .pendingRecall
        default:
            return nil
        }
    }
    
    // Convert from OrderStatus and Order to ActiveOrderStatus (for stop conditions)
    init?(from orderStatus: OrderStatus, order: Order) {
        switch orderStatus {
        case .awaitingStopCondition:
            // Determine if this is a buy or sell stop based on the order instruction
            if let orderLegs = order.orderLegCollection, !orderLegs.isEmpty {
                // Check the first leg's instruction to determine buy/sell
                let firstLeg = orderLegs[0]
                if let instruction = firstLeg.instruction {
                    switch instruction {
                    case .BUY, .BUY_TO_COVER, .BUY_TO_OPEN, .BUY_TO_CLOSE:
                        self = .awaitingBuyStopCondition
                    case .SELL, .SELL_SHORT, .SELL_TO_OPEN, .SELL_TO_CLOSE, .SELL_SHORT_EXEMPT:
                        self = .awaitingSellStopCondition
                    case .EXCHANGE:
                        // For exchange orders, we'll default to buy stop
                        self = .awaitingBuyStopCondition
                    }
                } else {
                    // If no instruction, default to buy stop
                    self = .awaitingBuyStopCondition
                }
            } else {
                // If no order legs, default to buy stop
                self = .awaitingBuyStopCondition
            }
        default:
            // For non-stop conditions, use the regular initializer
            if let status = ActiveOrderStatus(from: orderStatus) {
                self = status
            } else {
                return nil
            }
        }
    }
    
    // Short display name for the UI
    var shortDisplayName: String {
        switch self {
        case .working:
            return "WORK"
        case .awaitingSellStopCondition:
            return "STOP/S"
        case .awaitingBuyStopCondition:
            return "STOP/B"
        case .awaitingCondition:
            return "COND"
        case .awaitingManualReview:
            return "REVW"
        case .awaitingParentOrder:
            return "PAR"
        case .accepted:
            return "ACC"
        case .pendingActivation:
            return "ACT"
        case .queued:
            return "QUE"
        case .new:
            return "NEW"
        case .awaitingReleaseTime:
            return "REL"
        case .pendingAcknowledgement:
            return "ACK"
        case .pendingRecall:
            return "REC"
        }
    }
    
    // Priority for sorting (lower number = higher priority)
    var priority: Int {
        switch self {
        case .working:
            return 1
        case .awaitingSellStopCondition:
            return 2
        case .awaitingBuyStopCondition:
            return 3
        case .awaitingCondition:
            return 4
        case .awaitingManualReview:
            return 5
        case .awaitingParentOrder:
            return 6
        case .accepted:
            return 7
        case .pendingActivation:
            return 8
        case .queued:
            return 9
        case .new:
            return 10
        case .awaitingReleaseTime:
            return 11
        case .pendingAcknowledgement:
            return 12
        case .pendingRecall:
            return 13
        }
    }
} 
