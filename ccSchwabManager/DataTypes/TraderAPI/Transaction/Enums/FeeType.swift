//
//

/*
 
 feeType    string
 Enum:
 [ COMMISSION, SEC_FEE, STR_FEE, R_FEE, CDSC_FEE, OPT_REG_FEE, ADDITIONAL_FEE, MISCELLANEOUS_FEE, FUTURES_EXCHANGE_FEE, LOW_PROCEEDS_COMMISSION, BASE_CHARGE, GENERAL_CHARGE, GST_FEE, TAF_FEE, INDEX_OPTION_FEE, UNKNOWN ]

 
 
 */

import Foundation

public enum FeeType: String, Codable, CaseIterable
{
    case COMMISSION = "COMMISSION"
    case SEC_FEE = "SEC_FEE"
    case STR_FEE = "STR_FEE"
    case R_FEE = "R_FEE"
    case CDSC_FEE = "CDSC_FEE"
}
