import SwiftUI

class HoldingsViewModel: ObservableObject {
    @Published var uniqueAssetTypes: [String] = []
    @Published var uniqueAccountNumbers: [String] = []
 
    func updateUniqueValues(holdings: [Position], accountPositions: [(Position, String, Date)]) {
        uniqueAssetTypes = Array(Set(holdings.compactMap { $0.instrument?.assetType?.rawValue })).sorted()
        uniqueAccountNumbers = Array(Set(accountPositions.map { $0.1 })).sorted()
    }
} 
