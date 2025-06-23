//
//  OrderStatus.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 status    statusstring
 Enum:
 [ AWAITING_PARENT_ORDER, AWAITING_CONDITION, AWAITING_STOP_CONDITION, AWAITING_MANUAL_REVIEW, ACCEPTED, AWAITING_UR_OUT, PENDING_ACTIVATION, QUEUED, WORKING, REJECTED, PENDING_CANCEL, CANCELED, PENDING_REPLACE, REPLACED, FILLED, EXPIRED, NEW, AWAITING_RELEASE_TIME, PENDING_ACKNOWLEDGEMENT, PENDING_RECALL, UNKNOWN ]

 */

public enum OrderStatus: String, Codable, CaseIterable {
    case awaitingParentOrder = "AWAITING_PARENT_ORDER"
    case awaitingCondition = "AWAITING_CONDITION"
    case awaitingStopCondition = "AWAITING_STOP_CONDITION"
    case awaitingManualReview = "AWAITING_MANUAL_REVIEW"
    case accepted = "ACCEPTED"
    case pendingActivation = "PENDING_ACTIVATION"
    case queued = "QUEUED"
    case working = "WORKING"
    case rejected = "REJECTED"
    case pendingCancel = "PENDING_CANCEL"
    case canceled = "CANCELED"
    case pendingReplace = "PENDING_REPLACE"
    case replaced = "REPLACED"
    case filled = "FILLED"
    case expired = "EXPIRED"
    case new = "NEW"
    case awaitingReleaseTime = "AWAITING_RELEASE_TIME"
    case pendingAcknowledgement = "PENDING_ACKNOWLEDGEMENT"
    case pendingRecall = "PENDING_RECALL"
    case unknown = "UNKNOWN"
}

/**
 * ActiveOrderStatus - represents only the order statuses that indicate active/waiting orders
 * Ordered by priority for display purposes (most important first)
 */
public enum ActiveOrderStatus: String, Codable, CaseIterable {
    case working = "WORKING"
    case awaitingStopCondition = "AWAITING_STOP_CONDITION"
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
            self = .awaitingStopCondition
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
    
    // Short display name for the UI
    var shortDisplayName: String {
        switch self {
        case .working:
            return "WORK"
        case .awaitingStopCondition:
            return "STOP"
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
        case .awaitingStopCondition:
            return 2
        case .awaitingCondition:
            return 3
        case .awaitingManualReview:
            return 4
        case .awaitingParentOrder:
            return 5
        case .accepted:
            return 6
        case .pendingActivation:
            return 7
        case .queued:
            return 8
        case .new:
            return 9
        case .awaitingReleaseTime:
            return 10
        case .pendingAcknowledgement:
            return 11
        case .pendingRecall:
            return 12
        }
    }
}
