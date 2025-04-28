//
//  SapiTransaction.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//


/**

 */

import Foundation
import SwiftData


public struct SapiTransaction : Decodable
{
    var activityId: Int64
    var time: String
    var user: SapiUserDetails
    var description: String
    var accountNumber: String
    var type: SapiTransactionType
    var status: SapiTransactionStatus
    var subAccount: SapiTransactionSubAccount
    var tradeDate: String
    var settlementDate: String
    var positionId: Int64
    var orderId: Int64
    var netAmount: Double
    var activityType: SapiTransactionActivityType
    var transferItems: SapiTransferItem
}

