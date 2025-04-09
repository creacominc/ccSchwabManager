
import Foundation

class SapiAccountNumberHash: Codable
{

    private var accountNumber: String
    private var hashValue: String

    init(
        accountNumber: String,
        hasValue: String
    )
    {
        self.accountNumber = accountNumber
        self.hashValue = hasValue
    }

    public func dump() -> String
    {
        return String( " accountNumber: \(accountNumber)\n hashValue: \(hashValue)\n" )
    }

    func getAccountNumber() -> String
    {
        return accountNumber
    }

    func getHashValue() -> String
    {
        return hashValue
    }

}

