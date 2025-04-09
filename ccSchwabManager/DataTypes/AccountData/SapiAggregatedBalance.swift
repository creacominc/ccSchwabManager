import Foundation

class SapiAggregatedBalance: Codable, Identifiable
{
        var currentLiquidationValue : Double?
        var liquidationValue : Double?

    func dump() -> String
    {
        var retVal : String = ""
        retVal += "\n\t currentLiquidationValue = "
        retVal += String( currentLiquidationValue ?? -1 )
        return retVal
    }
}

