import Foundation

/**

 {
    "accruedInterest":0.0,
    "cashAvailableForTrading":38429.41,
    "cashAvailableForWithdrawal":38429.41,
    "cashBalance":38429.41,
    "bondValue":0.0,
    "cashReceipts":0.0,
    "liquidationValue":425403.66,
    "longOptionMarketValue":0.0,
    "longStockValue":387454.36,
    "moneyMarketFund":0.0,
    "mutualFundValue":38429.41,
    "shortOptionMarketValue":-480.11,
    "shortStockValue":-480.11,
    "isInCall":false,
    "unsettledCash":0.0,
    "cashDebitCallValue":0.0,
    "pendingDeposits":0.0,
    "accountValue":425403.66
 }
 
 {
    "accruedInterest":0.0,
    "cashBalance":38429.41,
    "cashReceipts":0.0,
    "longOptionMarketValue":0.0,
    "liquidationValue":425187.77,
    "longMarketValue":343441.09,
    "moneyMarketFund":0.0,
    "savings":0.0,
    "shortMarketValue":0.0,
    "pendingDeposits":0.0,
    "mutualFundValue":0.0,
    "bondValue":44013.27,
    "shortOptionMarketValue":-696.0,
    "cashAvailableForTrading":38429.41,
    "cashAvailableForWithdrawal":38429.41,
    "cashCall":0.0,
    "longNonMarginableMarketValue":38429.41,
    "totalCash":38429.41,
    "cashDebitCallValue":0.0,
    "unsettledCash":0.0
 }

 {
 "cashAvailableForTrading":5139.61,
 "cashAvailableForWithdrawal":5139.61
 }
 
 
 
 
 */


class Balance: Codable, Identifiable
{
    // CashBalance
    var cashAvailableForTrading : Double?
    var cashAvailableForWithdrawal : Double?
    var cashCall : Double?
    var longNonMarginableMarketValue : Double?
    var totalCash : Double?
    var cashDebitCallValue : Double?
    var unsettledCash : Double?
    
    // InitialBalance
    var accruedInterest : Double?
    var cashBalance : Double?
    var bondValue : Double?
    var cashReceipts : Double?
    var liquidationValue : Double?
    var longOptionMarketValue : Double?
    var longStockValue : Double?
    var moneyMarketFund : Double?
    var mutualFundValue : Double?
    var shortOptionMarketValue : Double?
    var shortStockValue : Double?
    var isInCall : Bool?
    var pendingDeposits : Double?
    var accountValue : Double?


    enum CodingKeys : String, CodingKey
    {
        case accruedInterest = "accruedInterest"
        case cashAvailableForTrading = "cashAvailableForTrading"
        case cashAvailableForWithdrawal = "cashAvailableForWithdrawal"
        case cashCall = "cashCall"
        case longNonMarginableMarketValue = "longNonMarginableMarketValue"
        case totalCash = "totalCash"
        case cashDebitCallValue = "cashDebitCallValue"
        case unsettledCash = "unsettledCash"
        case cashBalance = "cashBalance"
        case bondValue = "bondValue"
        case cashReceipts = "cashReceipts"
        case liquidationValue = "liquidationValue"
        case longOptionMarketValue = "longOptionMarketValue"
        case longStockValue = "longStockValue"
        case moneyMarketFund = "moneyMarketFund"
        case mutualFundValue = "mutualFundValue"
        case shortOptionMarketValue = "shortOptionMarketValue"
        case shortStockValue = "shortStockValue"
        case isInCall = "isInCall"
        case pendingDeposits = "pendingDeposits"
        case accountValue = "accountValue"
    }


    init( cashAvailableForTrading: Double? = nil,
         cashAvailableForWithdrawal: Double? = nil, cashCall: Double? = nil,
         longNonMarginableMarketValue: Double? = nil, totalCash: Double? = nil,
         cashDebitCallValue: Double? = nil, unsettledCash: Double? = nil,
         accruedInterest: Double? = nil, cashBalance: Double? = nil,
         bondValue: Double? = nil, cashReceipts: Double? = nil,
         liquidationValue: Double? = nil, longOptionMarketValue: Double? = nil,
         longStockValue: Double? = nil, moneyMarketFund: Double? = nil,
         mutualFundValue: Double? = nil, shortOptionMarketValue: Double? = nil,
         shortStockValue: Double? = nil, isInCall: Bool? = nil,
         pendingDeposits: Double? = nil, accountValue: Double? = nil
    )
    {
        self.cashAvailableForTrading = cashAvailableForTrading
        self.cashAvailableForWithdrawal = cashAvailableForWithdrawal
        self.cashCall = cashCall
        self.longNonMarginableMarketValue = longNonMarginableMarketValue
        self.totalCash = totalCash
        self.cashDebitCallValue = cashDebitCallValue
        self.unsettledCash = unsettledCash
        self.accruedInterest = accruedInterest
        self.cashBalance = cashBalance
        self.bondValue = bondValue
        self.cashReceipts = cashReceipts
        self.liquidationValue = liquidationValue
        self.longOptionMarketValue = longOptionMarketValue
        self.longStockValue = longStockValue
        self.moneyMarketFund = moneyMarketFund
        self.mutualFundValue = mutualFundValue
        self.shortOptionMarketValue = shortOptionMarketValue
        self.shortStockValue = shortStockValue
        self.isInCall = isInCall
        self.pendingDeposits = pendingDeposits
        self.accountValue = accountValue
    }



    func dump() -> String
    {
        var retVal : String = ""
        retVal += "accruedInterest = "
        retVal += String(accruedInterest ?? -1)
        retVal += "cashAvailableForTrading = "
        retVal += String(cashAvailableForTrading ?? -1 )
        return retVal
    }
}

