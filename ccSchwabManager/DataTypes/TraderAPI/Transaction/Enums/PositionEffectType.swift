
/**
 positionEffect    string
 Enum:
 [ OPENING, CLOSING, AUTOMATIC, UNKNOWN ]

 */

import Foundation

public enum PositionEffectType: String, Codable, CaseIterable
{
    case OPENING = "OPENING"
    case CLOSING = "CLOSING"
    case AUTOMATIC = "AUTOMATIC"
    case UNKNOWN = "UNKNOWN"
}

