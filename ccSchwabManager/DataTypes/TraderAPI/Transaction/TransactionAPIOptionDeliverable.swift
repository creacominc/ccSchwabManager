//
//  TransactionAPIOptionDeliverable.swift
//

import Foundation

/**
 TransactionAPIOptionDeliverable{
     rootSymbol    string
     strikePercent    integer($int64)
     deliverableNumber    integer($int64)
     deliverableUnits    number($double)
     deliverable    {}
     assetType    AssetType
 }
 */

struct TransactionAPIOptionDeliverable: Codable, Identifiable, Hashable, Sendable
{
    var id: String { [rootSymbol, deliverableNumber.map { String($0) }].compactMap { $0 }.joined(separator: "|") }
    let rootSymbol: String?
    let strikePercent: Int64?
    let deliverableNumber: Int64?
    let deliverableUnits: Double?
    //var deliverable: Any
    let assetType: AssetType?

    // coding keys
    enum CodingKeys : String, CodingKey
    {
        case rootSymbol = "rootSymbol"
        case strikePercent = "strikePercent"
        case deliverableNumber = "deliverableNumber"
        case deliverableUnits = "deliverableUnits"
        case assetType = "assetType"
    }


    public init(rootSymbol: String? = nil,
                strikePercent: Int64? = nil,
                deliverableNumber: Int64? = nil,
                deliverableUnits: Double? = nil,
                assetType: AssetType? = nil)
    {
        /** @TODO:  find proof that this is correct. */
        print( "==== TransactionAPIOptionDeliverable init ====  rootSymbol = \(String(describing: rootSymbol))" )
        self.rootSymbol = rootSymbol
        self.strikePercent = strikePercent
        self.deliverableNumber = deliverableNumber
        self.deliverableUnits = deliverableUnits
        self.assetType = assetType
    }


}
