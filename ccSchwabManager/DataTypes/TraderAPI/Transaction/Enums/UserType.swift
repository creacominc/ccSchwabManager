//
//

import Foundation

public enum UserType: String, Codable, CaseIterable
{

    case ADVISOR_USER = "ADVISOR_USER"
    case BROKER_USER  = "BROKER_USER"
    case CLIENT_USER  = "CLIENT_USER"
    case SYSTEM_USER  = "SYSTEM_USER"
    case UNKNOWN      = "UNKNOWN"

}
