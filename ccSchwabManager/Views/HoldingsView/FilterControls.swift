import SwiftUI

struct FilterControls: View {
    @Binding var selectedAssetTypes: Set<AssetType>
    @Binding var selectedAccountNumbers: Set<String>
    @Binding var selectedOrderStatuses: Set<ActiveOrderStatus>
    @Binding var includeNAStatus: Bool
    let uniqueAssetTypes: [AssetType]
    let uniqueAccountNumbers: [String]
    let uniqueOrderStatuses: [ActiveOrderStatus]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Asset Types:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding( .leading )
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(uniqueAssetTypes, id: \.self) { assetType in
                            Button(action: {
                                if selectedAssetTypes.contains(assetType) {
                                    selectedAssetTypes.remove(assetType)
                                } else {
                                    selectedAssetTypes.insert(assetType)
                                }
                            }) {
                                Text(assetType.shortDisplayName)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedAssetTypes.contains(assetType) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedAssetTypes.contains(assetType) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            HStack {
                Text("Accounts:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding( .leading )
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(uniqueAccountNumbers, id: \.self) { account in
                            Button(action: {
                                if selectedAccountNumbers.contains(account) {
                                    selectedAccountNumbers.remove(account)
                                } else {
                                    selectedAccountNumbers.insert(account)
                                }
                            }) {
                                Text(account)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedAccountNumbers.contains(account) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedAccountNumbers.contains(account) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Text("Status:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        // N/A button
                        Button(action: {
                            includeNAStatus.toggle()
                        }) {
                            Text("N/A")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(includeNAStatus ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(includeNAStatus ? .white : .primary)
                                .cornerRadius(8)
                        }
                        
                        ForEach(uniqueOrderStatuses, id: \.self) { status in
                            Button(action: {
                                if selectedOrderStatuses.contains(status) {
                                    selectedOrderStatuses.remove(status)
                                } else {
                                    selectedOrderStatuses.insert(status)
                                }
                            }) {
                                Text(status.shortDisplayName)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedOrderStatuses.contains(status) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedOrderStatuses.contains(status) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
    }
} 

#Preview("FilterControls", traits: .landscapeLeft) {
    FilterControls(
        selectedAssetTypes: .constant([ .EQUITY, .OPTION ]),
        selectedAccountNumbers: .constant(["789"]),
        selectedOrderStatuses: .constant([.working, .accepted]),
        includeNAStatus: .constant(true),
        uniqueAssetTypes: AssetType.allCases,
        uniqueAccountNumbers: ["789", "321", "777"],
        uniqueOrderStatuses: [.working, .accepted, .awaitingSellStopCondition, .awaitingBuyStopCondition]
    )
}

