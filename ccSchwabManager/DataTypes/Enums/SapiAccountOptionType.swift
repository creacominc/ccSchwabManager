
import Foundation


/**
 VANILLA, BINARY, BARRIER, UNKNOWN
 */

public enum SapiAccountOptionType: String, Codable, CaseIterable
{
    case vanilla = "VANILLA"
    case binary = "BINARY"
    case barrier = "BARRIER"
    case unknown = "UNKNOWN"
}
