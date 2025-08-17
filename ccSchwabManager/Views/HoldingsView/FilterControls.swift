import SwiftUI

struct FilterControls: View {
    @Binding var selectedAssetTypes: Set<AssetType>
    @Binding var selectedAccountNumbers: Set<String>
    let uniqueAssetTypes: [AssetType]
    let uniqueAccountNumbers: [String]
    
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
            }
        }
        .padding(.vertical, 8)
    }
} 

#Preview("FilterControls", traits: .landscapeLeft) {
    FilterControls(
        selectedAssetTypes: .constant([ .EQUITY, .OPTION ]),
        selectedAccountNumbers: .constant(["789"]),
        uniqueAssetTypes: AssetType.allCases,
        uniqueAccountNumbers: ["789", "321", "777"]
    )
}

