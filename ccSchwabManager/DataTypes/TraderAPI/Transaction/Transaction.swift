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
   "accountNumber": "...767",
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
class Transaction: Codable, Identifiable, Hashable, @unchecked Sendable
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
    
    // Computed price cache to avoid repeated API calls
    private var computedPriceCache: [String: Double] = [:]
    
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

    // print the contents of the transaction
    public func dump()
    {
        print( "=============================================" )
        print("Transaction Details:")
        print("Activity Id: \(String(describing: activityId))")
        print("Time: \(String(describing: time))")
        print("User: \(String(describing: user))")
        print("Description: \(String(describing: description))")
        print("Type: \(String(describing: type))")
        print("Status: \(String(describing: status))")
        print("Sub Account: \(String(describing: subAccount))")
        print("Trade Date: \(String(describing: tradeDate))")
        print("Settlement Date: \(String(describing: settlementDate))")
        print("Position Id: \(String(describing: positionId))")
        print("Order Id: \(String(describing: orderId))")
        print("Net Amount: \(String(describing: netAmount))")
        print("Activity Type: \(String(describing: activityType))")
        // dump each transfer item
        for item in transferItems
        {
            item.dump()
        }
        print( "=============================================" )
    }
    
    /**
     * getComputedPriceForSymbol - get the computed price for a specific symbol
     * This method caches the result to avoid repeated API calls
     */
    public func getComputedPriceForSymbol(_ symbol: String) -> Double {
        // Check cache first
        if let cachedPrice = computedPriceCache[symbol] {
            return cachedPrice
        }
        
        // Get the computed price from SchwabClient
        let computedPrice = SchwabClient.shared.getComputedPriceForTransaction(self, symbol: symbol)
        
        // Cache the result
        computedPriceCache[symbol] = computedPrice
        
        return computedPrice
    }
    
    /**
     * clearComputedPriceCache - clear the computed price cache
     * Useful when the transaction data changes
     */
    public func clearComputedPriceCache() {
        computedPriceCache.removeAll()
    }
}

/**
 * TransactionWithComputedPrice - wraps a Transaction with pre-computed price data
 * This allows us to move the price computation logic higher up in the view hierarchy
 * and avoid repeated API calls when rendering transaction rows.
 */
struct TransactionWithComputedPrice {
    let transaction: Transaction
    let symbol: String
    let computedPrice: Double
    let transferItem: TransferItem?
    
    init(transaction: Transaction, symbol: String) {
        self.transaction = transaction
        self.symbol = symbol
        
        // Find the transfer item for this symbol
        self.transferItem = transaction.transferItems.first(where: { $0.instrument?.symbol == symbol })
        
        // Pre-compute the price to avoid repeated API calls
        self.computedPrice = transaction.getComputedPriceForSymbol(symbol)
    }
    
    var amount: Double {
        return transferItem?.amount ?? 0
    }
    
    var isSell: Bool {
        return transaction.netAmount ?? 0 > 0
    }
    
    var isBuy: Bool {
        return transaction.netAmount ?? 0 < 0
    }
    
    var transactionType: String {
        if isBuy {
            return "Buy"
        } else if isSell {
            return "Sell"
        } else {
            return "Unknown"
        }
    }
}

