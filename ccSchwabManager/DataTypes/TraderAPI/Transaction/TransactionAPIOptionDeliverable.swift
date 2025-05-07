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

class TransactionAPIOptionDeliverable: Codable, Identifiable
{
    var rootSymbol: String?
    var strikePercent: Int64?
    var deliverableNumber: Int64?
    var deliverableUnits: Double?
    //var deliverable: Any
    var assetType: AssetType?

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
