
import Foundation

public class AccountNumberHash: Codable, Identifiable, @unchecked Sendable
{

    public var accountNumber: String?
    public var hashValue: String?

    // coding keys
    enum CodingKeys : String, CodingKey
    {
        case accountNumber = "accountNumber"
        case hashValue = "hashValue"
    }

    public init(
        accountNumber: String? = nil,
        hashValue: String
    )
    {
        print( "SapiAccountNumberHash init - accountNumber: \(accountNumber ?? "N/A"), hasValue: \(hashValue)")
        self.accountNumber = accountNumber
        self.hashValue = hashValue
    }

    public func dump() -> String
    {
        return String( " accountNumber: \(accountNumber ?? "N/A")\n hashValue: \(hashValue)\n" )
    }

    func getAccountNumber() -> String
    {
        return accountNumber ?? "N/A"
    }

    func getHashValue() -> String
    {
        return hashValue ?? "N/A"
    }

}

