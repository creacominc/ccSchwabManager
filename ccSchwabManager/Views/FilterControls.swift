import SwiftUI

struct FilterControls: View {
    @Binding var filterText: String
    @Binding var selectedAssetTypes: Set<String>
    @Binding var selectedAccountNumbers: Set<String>
    let uniqueAssetTypes: [String]
    let uniqueAccountNumbers: [String]
    
    var body: some View {
        VStack {
            HStack {
                TextField("Filter by symbol or description", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                if !filterText.isEmpty {
                    Button(action: { filterText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading) {
                    Text("Asset Types:")
                        .font(.headline)
                    HStack {
                        ForEach(uniqueAssetTypes, id: \.self) { assetType in
                            Toggle(assetType, isOn: Binding(
                                get: { selectedAssetTypes.contains(assetType) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedAssetTypes.insert(assetType)
                                    } else {
                                        selectedAssetTypes.remove(assetType)
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                        }
                    }
                    
                    Text("Accounts:")
                        .font(.headline)
                        .padding(.top)
                    HStack {
                        ForEach(uniqueAccountNumbers, id: \.self) { accountNumber in
                            Toggle("Acct \(accountNumber)", isOn: Binding(
                                get: { selectedAccountNumbers.contains(accountNumber) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedAccountNumbers.insert(accountNumber)
                                    } else {
                                        selectedAccountNumbers.remove(accountNumber)
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
} 
