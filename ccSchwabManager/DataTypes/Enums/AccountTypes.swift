
import Foundation

/**
 
 Account ->type
 
 */


public enum AccountTypes: String, Codable, CaseIterable
{
    case CASH   = "CASH"
    case MARGIN = "MARGIN"
}
