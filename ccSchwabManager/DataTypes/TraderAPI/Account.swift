// base class for

import Foundation



let NOTAVAILABLE : String = "Not Available"
let NOTAVAILABLENUMBER : Int = -1

class Account: Codable, Identifiable
{
    var type                    : AccountTypes?
    var accountNumber           : String?
    var roundTrips              : Int32?
    var isDayTrader             : Bool?
    var isClosingOnlyRestricted : Bool?
    var pfcbFlag                : Bool?
    var positions               : [Position]  =  []
    var initialBalances         : Balance?
    var currentBalances         : Balance?
    var projectedBalances       : Balance?

    enum CodingKeys : String, CodingKey
    {
        case type                    = "type"
        case accountNumber           = "accountNumber"
        case roundTrips              = "roundTrips"
        case isDayTrader             = "isDayTrader"
        case isClosingOnlyRestricted = "isClosingOnlyRestricted"
        case pfcbFlag                = "pfcbFlag"
        case positions               = "positions"
        case initialBalances         = "initialBalances"
        case currentBalances         = "currentBalances"
        case projectedBalances       = "projectedBalances"
    }

    init(type: AccountTypes? = nil, accountNumber: String? = nil, roundTrips: Int32? = nil, isDayTrader: Bool? = nil, isClosingOnlyRestricted: Bool? = nil, pfcbFlag: Bool? = nil, positions: [Position], initialBalances: Balance? = nil, currentBalances: Balance? = nil, projectedBalances: Balance? = nil)
    {
        self.type = type
        self.accountNumber = accountNumber
        self.roundTrips = roundTrips
        self.isDayTrader = isDayTrader
        self.isClosingOnlyRestricted = isClosingOnlyRestricted
        self.pfcbFlag = pfcbFlag
        self.positions = positions
        self.initialBalances = initialBalances
        self.currentBalances = currentBalances
        self.projectedBalances = projectedBalances
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        type = try container.decodeIfPresent(AccountTypes.self, forKey: .type)
        accountNumber = try container.decodeIfPresent(String.self, forKey: .accountNumber)
        roundTrips = try container.decodeIfPresent(Int32.self, forKey: .roundTrips)
        isDayTrader = try container.decodeIfPresent(Bool.self, forKey: .isDayTrader)
        isClosingOnlyRestricted = try container.decodeIfPresent(Bool.self, forKey: .isClosingOnlyRestricted)
        pfcbFlag = try container.decodeIfPresent(Bool.self, forKey: .pfcbFlag)
        
        // Decode positions array
        if let positionsArray = try? container.decode([Position].self, forKey: .positions) {
            positions = positionsArray
        } else {
            print( "Failed to decode positions" )
            positions = []
        }
        
        initialBalances = try container.decodeIfPresent(Balance.self, forKey: .initialBalances)
        currentBalances = try container.decodeIfPresent(Balance.self, forKey: .currentBalances)
        projectedBalances = try container.decodeIfPresent(Balance.self, forKey: .projectedBalances)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(accountNumber, forKey: .accountNumber)
        try container.encodeIfPresent(roundTrips, forKey: .roundTrips)
        try container.encodeIfPresent(isDayTrader, forKey: .isDayTrader)
        try container.encodeIfPresent(isClosingOnlyRestricted, forKey: .isClosingOnlyRestricted)
        try container.encodeIfPresent(pfcbFlag, forKey: .pfcbFlag)
        try container.encode(positions, forKey: .positions)
        try container.encodeIfPresent(initialBalances, forKey: .initialBalances)
        try container.encodeIfPresent(currentBalances, forKey: .currentBalances)
        try container.encodeIfPresent(projectedBalances, forKey: .projectedBalances)
    }

    func dump() -> String
    {
        var result: String = "\n"
        result += "\t\t type="
        result += (type?.rawValue ?? "no type")  + ", "
        result += "\t\t  account="
        result += accountNumber.map({String($0)}) ?? "no account number" + ", "
        result += "\t\t  round="
        result += roundTrips.map({String($0)}) ?? "no round trips" + ", "
        result += "\t\t  day="
        result += isDayTrader.map({String($0)}) ?? "no isDayTrader" + ", "
        result += "\t\t  restricted="
        result += isClosingOnlyRestricted.map({String($0)}) ?? "no isClosingOnlyRestricted" + ", "
        result += "\t\t  pfcbFlag="
        result += pfcbFlag.map({String($0)}) ?? "no pfcbFlag" + "\n"
        result += "\t\t  positions: \(positions.count)\n"
        for position in positions
        {
            result += "\n\t\t"
            result += "Position: "
            result += position.dump()
        }
        result += "\n\t\t initialBalances = "
        result += initialBalances?.dump() ?? "no initial balance"
        result += "\n\t\t currentBalances = "
        result += currentBalances?.dump() ?? "no current balance"
        result += "\n\t\t projectedBalances = "
        result += projectedBalances?.dump() ?? "no projected balance"
        return result
    }
    
}
