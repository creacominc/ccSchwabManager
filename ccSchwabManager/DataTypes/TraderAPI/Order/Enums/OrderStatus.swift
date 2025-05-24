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
