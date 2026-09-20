//
//

import Foundation

public enum TransactionStatus: String, Codable, CaseIterable, Sendable
{
    case VALID    = "VALID"
    case INVALID  = "INVALID"
    case PENDING  = "PENDING"
    case UNKNOWN  = "UNKNOWN"
}
