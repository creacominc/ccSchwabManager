//
//  SapiTransactions.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//


/**
 Transaction{
 activityId    integer($int64)
 time    string($date-time)
 user    UserDetails{...}
 description    string
 accountNumber    string
 type    TransactionType[...]
 status    string
 Enum:
 [ VALID, INVALID, PENDING, UNKNOWN ]
 subAccount    string
 Enum:
 [ CASH, MARGIN, SHORT, DIV, INCOME, UNKNOWN ]
 tradeDate    string($date-time)
 settlementDate    string($date-time)
 positionId    integer($int64)
 orderId    integer($int64)
 netAmount    number($double)
 activityType    string
 Enum:
 [ ACTIVITY_CORRECTION, EXECUTION, ORDER_ACTION, TRANSFER, UNKNOWN ]
 transferItems    [
 xml: OrderedMap { "name": "transferItems", "wrapped": true }
 TransferItem{...}]
 }
 */

import Foundation
import SwiftData

//@Model
public struct SapiTransaction : Decodable
{
}



/**
 [Transaction{
 activityId    integer($int64)
 time    string($date-time)
 user    UserDetails{
 cdDomainId    string
 login    string
 type    string
 Enum:
 [ ADVISOR_USER, BROKER_USER, CLIENT_USER, SYSTEM_USER, UNKNOWN ]
 userId    integer($int64)
 systemUserName    string
 firstName    string
 lastName    string
 brokerRepCode    string
 }
 description    string
 accountNumber    string
 type    TransactionTypestring
 Enum:
 [ TRADE, RECEIVE_AND_DELIVER, DIVIDEND_OR_INTEREST, ACH_RECEIPT, ACH_DISBURSEMENT, CASH_RECEIPT, CASH_DISBURSEMENT, ELECTRONIC_FUND, WIRE_OUT, WIRE_IN, JOURNAL, MEMORANDUM, MARGIN_CALL, MONEY_MARKET, SMA_ADJUSTMENT ]
 status    string
 Enum:
 [ VALID, INVALID, PENDING, UNKNOWN ]
 subAccount    string
 Enum:
 [ CASH, MARGIN, SHORT, DIV, INCOME, UNKNOWN ]
 tradeDate    string($date-time)
 settlementDate    string($date-time)
 positionId    integer($int64)
 orderId    integer($int64)
 netAmount    number($double)
 activityType    string
 Enum:
 [ ACTIVITY_CORRECTION, EXECUTION, ORDER_ACTION, TRANSFER, UNKNOWN ]
 transferItems    [
 xml: OrderedMap { "name": "transferItems", "wrapped": true }
 TransferItem{
 instrument    TransactionInstrument{
 oneOf ->
 TransactionCashEquivalent{
 assetType*    string
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    string
 Enum:
 [ SWEEP_VEHICLE, SAVINGS, MONEY_MARKET_FUND, UNKNOWN ]
 }
 CollectiveInvestment{
 assetType*    string
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    string
 Enum:
 [ UNIT_INVESTMENT_TRUST, EXCHANGE_TRADED_FUND, CLOSED_END_FUND, INDEX, UNITS ]
 }
 Currency{
 assetType*    string
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 }
 TransactionEquity{
 assetType*    string
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    string
 Enum:
 [ COMMON_STOCK, PREFERRED_STOCK, DEPOSITORY_RECEIPT, PREFERRED_DEPOSITORY_RECEIPT, RESTRICTED_STOCK, COMPONENT_UNIT, RIGHT, WARRANT, CONVERTIBLE_PREFERRED_STOCK, CONVERTIBLE_STOCK, LIMITED_PARTNERSHIP, WHEN_ISSUED, UNKNOWN ]
 }
 TransactionFixedIncome{
 assetType*    string
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    string
 Enum:
 [ BOND_UNIT, CERTIFICATE_OF_DEPOSIT, CONVERTIBLE_BOND, COLLATERALIZED_MORTGAGE_OBLIGATION, CORPORATE_BOND, GOVERNMENT_MORTGAGE, GNMA_BONDS, MUNICIPAL_ASSESSMENT_DISTRICT, MUNICIPAL_BOND, OTHER_GOVERNMENT, SHORT_TERM_PAPER, US_TREASURY_BOND, US_TREASURY_BILL, US_TREASURY_NOTE, US_TREASURY_ZERO_COUPON, AGENCY_BOND, WHEN_AS_AND_IF_ISSUED_BOND, ASSET_BACKED_SECURITY, UNKNOWN ]
 maturityDate    string($date-time)
 factor    number($double)
 multiplier    number($double)
 variableRate    number($double)
 }
 Forex{...}
 Future{...}
 Index{
 activeContract    boolean
 default: false
 type    string
 Enum:
 [ BROAD_BASED, NARROW_BASED, UNKNOWN ]
 }
 TransactionMutualFund{
 assetType*    string
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 fundFamilyName    string
 fundFamilySymbol    string
 fundGroup    string
 type    string
 Enum:
 [ NOT_APPLICABLE, OPEN_END_NON_TAXABLE, OPEN_END_TAXABLE, NO_LOAD_NON_TAXABLE, NO_LOAD_TAXABLE, UNKNOWN ]
 exchangeCutoffTime    string($date-time)
 purchaseCutoffTime    string($date-time)
 redemptionCutoffTime    string($date-time)
 }
 TransactionOption{
 assetType*    string
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 expirationDate    string($date-time)
 optionDeliverables    [
 xml: OrderedMap { "name": "optionDeliverables", "wrapped": true }
 TransactionAPIOptionDeliverable{
 rootSymbol    string
 strikePercent    integer($int64)
 deliverableNumber    integer($int64)
 deliverableUnits    number($double)
 deliverable    {
 }
 assetType    assetTypestring
 Enum:
 [ EQUITY, MUTUAL_FUND, OPTION, FUTURE, FOREX, INDEX, CASH_EQUIVALENT, FIXED_INCOME, PRODUCT, CURRENCY, COLLECTIVE_INVESTMENT ]
 }]
 optionPremiumMultiplier    integer($int64)
 putCall    string
 Enum:
 [ PUT, CALL, UNKNOWN ]
 strikePrice    number($double)
 type    string
 Enum:
 [ VANILLA, BINARY, BARRIER, UNKNOWN ]
 underlyingSymbol    string
 underlyingCusip    string
 deliverable    {
 }
 }
 Product{
 assetType*    string
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    string
 Enum:
 [ TBD, UNKNOWN ]
 }
 }
 amount    number($double)
 cost    number($double)
 price    number($double)
 feeType    string
 Enum:
 [ COMMISSION, SEC_FEE, STR_FEE, R_FEE, CDSC_FEE, OPT_REG_FEE, ADDITIONAL_FEE, MISCELLANEOUS_FEE, FUTURES_EXCHANGE_FEE, LOW_PROCEEDS_COMMISSION, BASE_CHARGE, GENERAL_CHARGE, GST_FEE, TAF_FEE, INDEX_OPTION_FEE, UNKNOWN ]
 positionEffect    string
 Enum:
 [ OPENING, CLOSING, AUTOMATIC, UNKNOWN ]
 }]
 }]
 */
