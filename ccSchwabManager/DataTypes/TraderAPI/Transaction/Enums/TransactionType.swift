//
//


import Foundation


// TRADE, RECEIVE_AND_DELIVER, DIVIDEND_OR_INTEREST, ACH_RECEIPT, ACH_DISBURSEMENT, CASH_RECEIPT, CASH_DISBURSEMENT, ELECTRONIC_FUND, WIRE_OUT, WIRE_IN, JOURNAL, MEMORANDUM, MARGIN_CALL, MONEY_MARKET, SMA_ADJUSTMENT

public enum TransactionType: String, Codable, CaseIterable, Sendable
{
    case trade                 = "TRADE"
    case receiveAndDeliver     = "RECEIVE_AND_DELIVER"
    case dividendOrInterest    = "DIVIDEND_OR_INTEREST"
    case achReceipt            = "ACH_RECEIPT"
    case achDisbursement       = "ACH_DISBURSEMENT"
    case cashReceipt           = "CASH_RECEIPT"
    case cashDisbursement      = "CASH_DISBURSEMENT"
    case electronicFund        = "ELECTRONIC_FUND"
    case wireOut               = "WIRE_OUT"
    case wireIn                = "WIRE_IN"
    case journal               = "JOURNAL"
    case memorandum            = "MEMORANDUM"
    case marginCall            = "MARGIN_CALL"
    case moneyMarket           = "MONEY_MARKET"
    case smaAdjustment         = "SMA_ADJUSTMENT"
}
