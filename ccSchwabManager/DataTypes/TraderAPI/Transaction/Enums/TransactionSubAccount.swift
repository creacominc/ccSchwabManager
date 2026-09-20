//
//

import Foundation

public enum TransactionSubAccount: String, Codable, CaseIterable, Sendable
{

    case CASH = "CASH"
    case MARGIN = "MARGIN"
    case SHORT = "SHORT"
    case DIV = "DIV"
    case INCOME = "INCOME"
    case UNKNOWN = "UNKNOWN"
    
}
