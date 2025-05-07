
import Foundation

/**
 
 Account -> Positions[] -> instrument ->putCall

 
 */

public enum PutCallType: String, Codable, CaseIterable
{
    case PUT = "PUT"
    case CALL = "CALL"
    case UNKNOWN = "UNKNOWN"
}
