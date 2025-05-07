//
//

import Foundation

class AccountContent: Codable, Identifiable
{
    var securitiesAccount: Account?
    var aggregatedBalance: AggregatedBalance?

    enum CodingKeys : String, CodingKey
    {
        case securitiesAccount = "securitiesAccount"
        case aggregatedBalance = "aggregatedBalance"
    }

    public init( securitiesAccount: Account? = nil,
                 aggregatedBalance: AggregatedBalance? = nil )
    {
        self.securitiesAccount = securitiesAccount
        self.aggregatedBalance = aggregatedBalance
    }

    public func dump() -> String
    {
        var result: String = ""
        result += "\t securitiesAccount: " + (securitiesAccount?.dump() ?? "N/A")
        result += "\n"
        result += "\t aggregatedBalance: " + (aggregatedBalance?.dump() ?? "N/A")
        return result
    }

}
