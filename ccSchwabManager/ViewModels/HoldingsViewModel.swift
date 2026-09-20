import Observation

@MainActor
@Observable
final class HoldingsViewModel {
    var uniqueAssetTypes: [AssetType] = []
    var uniqueAccountNumbers: [String] = []
 
    func updateUniqueValues(holdings: [Position], accountPositions: [(Position, String, String)]) {
        uniqueAssetTypes = Array(Set(holdings.compactMap { $0.instrument?.assetType })).sorted()
        uniqueAccountNumbers = Array(Set(accountPositions.map { $0.1 })).sorted()
    }
} 
