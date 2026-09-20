import SwiftUI

struct FilterControls: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedAssetTypes: Set<AssetType>
    @Binding var selectedAccountNumbers: Set<String>
    @Binding var selectedOrderStatuses: Set<ActiveOrderStatus>
    @Binding var includeNAStatus: Bool
    let uniqueAssetTypes: [AssetType]
    let uniqueAccountNumbers: [String]
    let uniqueOrderStatuses: [ActiveOrderStatus]

    private var adaptiveRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
    }
    
    var body: some View {
        VStack(spacing: 8) {
            adaptiveRowLayout {
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
                                    .background(selectedAssetTypes.contains(assetType) ? Color.accentColor : Color.secondary.opacity(0.14))
                                    .foregroundColor(selectedAssetTypes.contains(assetType) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .accessibilityValue(selectedAssetTypes.contains(assetType) ? "Selected" : "Not selected")
                            .accessibilityAddTraits(selectedAssetTypes.contains(assetType) ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal)
                }
            }

            adaptiveRowLayout {
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
                                    .background(selectedAccountNumbers.contains(account) ? Color.accentColor : Color.secondary.opacity(0.14))
                                    .foregroundColor(selectedAccountNumbers.contains(account) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .accessibilityLabel("Account \(account)")
                            .accessibilityValue(selectedAccountNumbers.contains(account) ? "Selected" : "Not selected")
                            .accessibilityAddTraits(selectedAccountNumbers.contains(account) ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal)
                }
                
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }
                
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
                                .background(includeNAStatus ? Color.accentColor : Color.secondary.opacity(0.14))
                                .foregroundColor(includeNAStatus ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("No order status")
                        .accessibilityValue(includeNAStatus ? "Selected" : "Not selected")
                        .accessibilityAddTraits(includeNAStatus ? .isSelected : [])
                        
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
                                    .background(selectedOrderStatuses.contains(status) ? Color.accentColor : Color.secondary.opacity(0.14))
                                    .foregroundColor(selectedOrderStatuses.contains(status) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .accessibilityValue(selectedOrderStatuses.contains(status) ? "Selected" : "Not selected")
                            .accessibilityAddTraits(selectedOrderStatuses.contains(status) ? .isSelected : [])
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
