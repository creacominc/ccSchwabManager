import Foundation

/**
   AggregatedBalance can appear as the following JSON:
 
 {"currentLiquidationValue":425187.77,"liquidationValue":425187.77}
  
 */

class AggregatedBalance: Codable, Identifiable
{
    var currentLiquidationValue : Double?
    var liquidationValue : Double?

    enum CodingKeys : String, CodingKey
    {
        case currentLiquidationValue = "currentLiquidationValue"
        case liquidationValue = "liquidationValue"
    }

    init( currentLiquidationValue: Double? = nil,
          liquidationValue: Double? = nil )
    {
        self.currentLiquidationValue = currentLiquidationValue
        self.liquidationValue = liquidationValue
    }

    func dump() -> String
    {
        var retVal : String = ""
        retVal += "\n\t currentLiquidationValue = "
        retVal += String( currentLiquidationValue ?? -1 )
        return retVal
    }
}

