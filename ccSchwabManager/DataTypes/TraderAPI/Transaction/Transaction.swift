//
//  SapiTransaction.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

import Foundation

/**
 *
 *
 *[
 {
   "activityId": 95512265692,
   "time": "2025-04-23T19:59:12+0000",
   "accountNumber": "88516767",
   "type": "TRADE",
   "status": "VALID",
   "subAccount": "CASH",
   "tradeDate": "2025-04-23T19:59:12+0000",
   "positionId": 2788793997,
   "orderId": 1003188442747,
   "netAmount": -164.85,
   "transferItems": [
     {
       "instrument": {
         "assetType": "EQUITY",
         "status": "ACTIVE",
         "symbol": "SFM",
         "instrumentId": 1806651,
         "closingPrice": 169.76,
         "type": "COMMON_STOCK"
       },
       "amount": 1,
       "cost": -164.85,
       "price": 164.85,
       "positionEffect": "OPENING"
     }
   ]
 }
]
 *

 */


// Transaction needs to be hashable.
class Transaction: Codable, Identifiable, Hashable
{
    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        return (lhs.activityId == rhs.activityId)
    }

    func hash(into hasher: inout Hasher)
    {
        hasher.combine(activityId ?? 0)
    }

    public var activityId: Int64?
    public var time: String?
    public var user: UserDetails?
    public var description: String?
    public var accountNumber: String?
    public var type: TransactionType?
    public var status: TransactionStatus?
    public var subAccount: TransactionSubAccount?
    public var tradeDate: String?
    public var settlementDate: String?
    public var positionId: Int64?
    public var orderId: Int64?
    public var netAmount: Double?
    
    public var activityType: TransactionActivityType?
    public var transferItems: [TransferItem]
    
    // coding keys
    enum CodingKeys : String, CodingKey
    {
        case activityId = "activityId"
        case time = "time"
        case user = "user"
        case description = "description"
        case accountNumber = "accountNumber"
        case type = "type"
        case status = "status"
        case subAccount = "subAccount"
        case tradeDate = "tradeDate"
        case settlementDate = "settlementDate"
        case positionId = "positionId"
        case orderId = "orderId"
        case netAmount = "netAmount"
        case activityType = "activityType"
        case transferItems = "transferItems"
    }

    public init(activityId: Int64? = nil, time: String? = nil,
                user: UserDetails? = nil, description: String? = nil,
                accountNumber: String? = nil, type: TransactionType? = nil,
                status: TransactionStatus? = nil, subAccount: TransactionSubAccount? = nil,
                tradeDate: String? = nil, settlementDate: String? = nil,
                positionId: Int64? = nil, orderId: Int64? = nil,
                netAmount: Double? = nil, activityType: TransactionActivityType? = nil,
                transferItems: [TransferItem])
    {
        self.activityId = activityId
        self.time = time
        self.user = user
        self.description = description
        self.accountNumber = accountNumber
        self.type = type
        self.status = status
        self.subAccount = subAccount
        self.tradeDate = tradeDate
        self.settlementDate = settlementDate
        self.positionId = positionId
        self.orderId = orderId
        self.netAmount = netAmount
        self.activityType = activityType
        self.transferItems = transferItems
    }

}

