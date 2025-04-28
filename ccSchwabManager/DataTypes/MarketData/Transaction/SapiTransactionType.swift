//
//  SapiTransactionType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//


import Foundation


// TRADE, RECEIVE_AND_DELIVER, DIVIDEND_OR_INTEREST, ACH_RECEIPT, ACH_DISBURSEMENT, CASH_RECEIPT, CASH_DISBURSEMENT, ELECTRONIC_FUND, WIRE_OUT, WIRE_IN, JOURNAL, MEMORANDUM, MARGIN_CALL, MONEY_MARKET, SMA_ADJUSTMENT

public enum SapiTransactionType: String, Codable, CaseIterable
{
    case TRADE
    case RECEIVE_AND_DELIVER
    case DIVIDEND_OR_INTEREST
    case ACH_RECEIPT
    case ACH_DISBURSEMENT
    case CASH_RECEIPT
    case CASH_DISBURSEMENT
    case ELECTRONIC_FUND
    case WIRE_OUT
    case WIRE_IN
    case JOURNAL
    case MEMORANDUM
    case MARGIN_CALL
    case MONEY_MARKET
    case SMA_ADJUSTMENT
}
