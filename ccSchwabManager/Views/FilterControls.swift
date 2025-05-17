import SwiftUI

struct FilterControls: View {
    @Binding var selectedAssetTypes: Set<String>
    @Binding var selectedAccountNumbers: Set<String>
    let uniqueAssetTypes: [String]
    let uniqueAccountNumbers: [String]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Asset Types:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(uniqueAssetTypes, id: \.self) { type in
                            Button(action: {
                                if selectedAssetTypes.contains(type) {
                                    selectedAssetTypes.remove(type)
                                } else {
                                    selectedAssetTypes.insert(type)
                                }
                            }) {
                                Text(type)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedAssetTypes.contains(type) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedAssetTypes.contains(type) ? .white : .primary)
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
 
