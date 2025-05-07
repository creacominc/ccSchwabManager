//
//

import Foundation

public enum TransactionActivityType: String, Codable, CaseIterable
{
    case ACTIVITY_CORRECTION = "ACTIVITY_CORRECTION"
    case EXECUTION = "EXECUTION"
    case ORDER_ACTION = "ORDER_ACTION"
    case TRANSFER = "TRANSFER"
    case UNKNOWN = "UNKNOWN"
}
