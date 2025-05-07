//
//

import Foundation

public enum TransactionStatus: String, Codable, CaseIterable
{
    case VALID    = "VALID"
    case INVALID  = "INVALID"
    case PENDING  = "PENDING"
    case UNKNOWN  = "UNKNOWN"
}
