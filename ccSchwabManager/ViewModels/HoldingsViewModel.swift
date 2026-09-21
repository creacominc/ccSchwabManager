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

    func filteredHoldings(
        from holdings: [Position],
        searchText: String,
        selectedAssetTypes: Set<AssetType>,
        accountPositions: [(Position, String, String)],
        selectedAccountNumbers: Set<String>,
        selectedOrderStatuses: Set<ActiveOrderStatus>,
        includeNAStatus: Bool,
        orderStatusCache: [String: ActiveOrderStatus?]
    ) -> [Position] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces)

        return holdings.filter { position in
            let matchesText = trimmedQuery.isEmpty
                || (position.instrument?.symbol?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
                || (position.instrument?.description?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
            let matchesAssetType = selectedAssetTypes.isEmpty
                || position.instrument?.assetType.map(selectedAssetTypes.contains) == true
            let accountNumber = accountPositions.first { $0.0 === position }?.1
            let matchesAccount = selectedAccountNumbers.isEmpty
                || accountNumber.map(selectedAccountNumbers.contains) == true
            let orderStatus = orderStatusCache[position.instrument?.symbol ?? ""] ?? nil
            let matchesOrderStatus: Bool

            if selectedOrderStatuses.isEmpty && !includeNAStatus {
                matchesOrderStatus = true
            } else {
                matchesOrderStatus = orderStatus.map(selectedOrderStatuses.contains) == true
                    || (orderStatus == nil && includeNAStatus)
            }

            return matchesText && matchesAssetType && matchesAccount && matchesOrderStatus
        }
    }

    func uniqueOrderStatuses(in orderStatusCache: [String: ActiveOrderStatus?]) -> [ActiveOrderStatus] {
        Array(Set(orderStatusCache.values.compactMap { $0 })).sorted { $0.priority < $1.priority }
    }

    func sortedHoldings(
        _ holdings: [Position],
        using sortConfig: SortConfig?,
        accountPositions: [(Position, String, String)],
        tradeDateCache: [String: String],
        orderStatusCache: [String: ActiveOrderStatus?]
    ) -> [Position] {
        guard let sortConfig else { return holdings }

        return holdings.sorted { first, second in
            let ascending = sortConfig.ascending
            let firstQuantity = (first.longQuantity ?? 0) + (first.shortQuantity ?? 0)
            let secondQuantity = (second.longQuantity ?? 0) + (second.shortQuantity ?? 0)

            switch sortConfig.column {
            case .symbol:
                return compare(first.instrument?.symbol ?? "", second.instrument?.symbol ?? "", ascending: ascending)
            case .quantity:
                return compare(firstQuantity, secondQuantity, ascending: ascending)
            case .avgPrice:
                return compare(first.averagePrice ?? 0, second.averagePrice ?? 0, ascending: ascending)
            case .marketValue:
                return compare(first.marketValue ?? 0, second.marketValue ?? 0, ascending: ascending)
            case .pl:
                return compare(first.longOpenProfitLoss ?? 0, second.longOpenProfitLoss ?? 0, ascending: ascending)
            case .plPercent:
                return compare(profitLossPercent(for: first), profitLossPercent(for: second), ascending: ascending)
            case .assetType:
                return compare(
                    first.instrument?.assetType?.rawValue ?? "",
                    second.instrument?.assetType?.rawValue ?? "",
                    ascending: ascending
                )
            case .account:
                let firstAccount = accountPositions.first { $0.0 === first }?.1 ?? ""
                let secondAccount = accountPositions.first { $0.0 === second }?.1 ?? ""
                return compare(firstAccount, secondAccount, ascending: ascending)
            case .lastTradeDate:
                let firstSymbol = first.instrument?.symbol ?? ""
                let secondSymbol = second.instrument?.symbol ?? ""
                let firstDate = tradeDateCache[firstSymbol] ?? "0000"
                let secondDate = tradeDateCache[secondSymbol] ?? "0000"
                return firstDate == secondDate
                    ? firstSymbol < secondSymbol
                    : compare(firstDate, secondDate, ascending: ascending)
            case .orderStatus:
                let firstStatus = orderStatusCache[first.instrument?.symbol ?? ""] ?? nil
                let secondStatus = orderStatusCache[second.instrument?.symbol ?? ""] ?? nil
                return compare(firstStatus?.priority ?? 0, secondStatus?.priority ?? 0, ascending: ascending)
            }
        }
    }

    private func profitLossPercent(for position: Position) -> Double {
        let profitLoss = position.longOpenProfitLoss ?? 0
        let costBasis = (position.marketValue ?? 0) - profitLoss
        return costBasis == 0 ? 0 : profitLoss / costBasis
    }

    private func compare<T: Comparable>(_ first: T, _ second: T, ascending: Bool) -> Bool {
        ascending ? first < second : first > second
    }
}
