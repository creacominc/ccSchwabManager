import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif



// Function to calculate the difference in days between today and a given date string
// This function was suggested by GitHub Copilot
func daysBetweenDates(dateString: String) -> Int?
{
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat =  "yyyy-MM-dd HH:mm:ss" // "MM/dd/yyyy" //
    // Convert the date string to a Date object
    guard let date = dateFormatter.date(from: dateString) else {
        print("Invalid date format.  date = \(dateString)")
        return nil
    }
    // Get today's date
    let today = Date()
    // Calculate the difference in days
    let calendar = Calendar.current
    let components = calendar.dateComponents([.day], from: date, to: today)
    return components.day
}

struct SalesCalcLeftColumn: View
{
    let atrValue: Double
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 8) {
            SalesCalcDetailRow(label: "ATR", value: "\(String(format: "%.2f", atrValue)) %")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SalesCalcRightColumn: View
{
    let copiedValue: String
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 8) {
            SalesCalcDetailRow(label: "Copied", value: copiedValue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SalesCalcDetailRow: View
{
    let label: String
    let value: String
    
    var body: some View
    {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .monospacedDigit()
        }
    }
}

struct BuyOrderDetailSection: View
{
    // buy order
//    @State var buyOrder: SalesCalcBuyOrder? = nil
//    @State var copiedValue: String = "TBD"

    var body: some View
    {
        // Buy Order Details
        HStack
        {
            Text("Buy Order Details:")
                .font(.headline)
                .padding( .horizontal )
//            if( nil != buyOrder )
//            {
//                Text( "Buy \( buyOrder!.percent * 100.0, specifier: "%.2f") %" )
//                    .onTapGesture(count: 1) { copyToClipboard( value: buyOrder!.percent * 100.0, format: "%.2f", copiedValue: &copiedValue ) }
//                Text( "(\( buyOrder!.equivalentShares, specifier: "%d"))" )
//                    .onTapGesture(count: 1) { copyToClipboard( value: buyOrder!.equivalentShares, format: "%d", copiedValue: &copiedValue ) }
//                Text( "TS: \( buyOrder!.trailingStop * 100.0, specifier: "%.0f") %" )
//                    .onTapGesture(count: 1) { copyToClipboard( value: buyOrder!.trailingStop * 100.0, format: "%.0f", copiedValue: &copiedValue ) }
//                Text( "After: \(buyOrder!.submitDate.dateOnly())" )
//                    .onTapGesture(count: 1) { copyToClipboard( text: buyOrder!.submitDate.dateOnly(), copiedValue: &copiedValue ) }
//                Text( "Bid >: \(buyOrder!.bidPriceOver, specifier: "%.2f")" )
//                    .onTapGesture(count: 1) { copyToClipboard( value: buyOrder!.bidPriceOver, format: "%.2f", copiedValue: &copiedValue ) }
//            }
        }
    }
}



struct SellOrderDetailSection: View{
    // current position and tax lots for a given security
    let symbol: String
//    let currentCostBasis: Double
//    let currentShares: Int
//    let transactionList : [Transaction]
    // sell order
//    @State var sellOrder: SalesCalcResultsRecord
//    @State var copiedValue: String

    var body: some View
    {
        // Sell Order Details
        HStack
        {
            Text("Sell Order Details:")
                .font(.headline)
                .padding( .horizontal )
//            Text("\(sellOrder.rollingGainLoss, specifier: "%.2f")")
//            Text("\(sellOrder.breakEven, specifier: "%.2f")")
//            Text("\(sellOrder.gain, specifier: "%.2f")%")
//            Text("\(sellOrder.sharesToSell, specifier: "%.0f")")
//                .onTapGesture(count: 1) { copyToClipboard( value: sellOrder.sharesToSell, format: "%.0f", copiedValue: &copiedValue ) }
//                .foregroundStyle( rowStyle(item: sellOrder) )
//            Text("\(sellOrder.trailingStop, specifier: "%.1f")%")
//                .onTapGesture(count: 1) { copyToClipboard( value: sellOrder.trailingStop, format: "%.1f", copiedValue: &copiedValue ) }
//                .foregroundStyle( rowStyle(item: sellOrder) )
//            Text("\(sellOrder.entry, specifier: "%.2f")")
//                .onTapGesture(count: 1) { copyToClipboard( value: sellOrder.entry, format: "%.2f", copiedValue: &copiedValue ) }
//                .foregroundStyle( rowStyle(item: sellOrder) )
//            Text("\(sellOrder.cancel, specifier: "%.2f")")
//                .onTapGesture(count: 1) { copyToClipboard( value: sellOrder.cancel, format: "%.2f", copiedValue: &copiedValue ) }
//                .foregroundStyle( rowStyle(item: sellOrder) )
//            Text( "     " )
//            Text(sellOrder.description)
//                .onTapGesture(count: 1) { copyToClipboard( text: sellOrder.description, copiedValue: &copiedValue ) }
//                .foregroundStyle( rowStyle(item: sellOrder) )
        }

    }
}


/**
            InformationSectiom:          symbol,   atrPercent,  copiedValue
            BuyOrderDetailSection:      Buy $ shares TS After Bid
            SellOrderDetailSection:      current positions
 */

class SalesCalcViewModel: ObservableObject {
    @Published var positionsData: [SalesCalcPositionsRecord] = []
    private let schwabClient = SchwabClient.shared
    
    func refreshData(symbol: String) {
        print("SalesCalcViewModel - Refreshing data for symbol: \(symbol)")
        positionsData = schwabClient.computeTaxLots(symbol: symbol)
        print("SalesCalcViewModel refreshData - Received \(positionsData.count) tax lot records")
    }
}

struct SalesCalcView: View {
    let symbol: String
    let atrValue: Double
    @StateObject private var viewModel = SalesCalcViewModel()
    @StateObject private var loadingState = LoadingState()
    @State private var currentSort: SalesCalcSortConfig? = SalesCalcSortConfig(column: .costPerShare, ascending: SalesCalcSortableColumn.costPerShare.defaultAscending )
    @State private var viewSize: CGSize = .zero
    @State private var showIncompleteDataWarning = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                SalesCalcTable(
                    positionsData: viewModel.positionsData,
                    currentSort: $currentSort,
                    viewSize: geometry.size
                )
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newValue in
                    viewSize = newValue
                }
                .padding(.horizontal)
            }
            .onAppear {
                // Use DispatchQueue to ensure we're using the latest symbol value
                DispatchQueue.main.async {
                    // Connect loading state to SchwabClient
                    SchwabClient.shared.loadingDelegate = loadingState
                    viewModel.refreshData(symbol: symbol)
                }
            }
            .onChange(of: symbol) { _, newValue in
                print("Symbol changed to: \(newValue)")
                // Use DispatchQueue to ensure we're using the latest symbol value
                DispatchQueue.main.async {
                    // Connect loading state to SchwabClient
                    SchwabClient.shared.loadingDelegate = loadingState
                    viewModel.refreshData(symbol: newValue)
                }
            }
            .onChange(of: SchwabClient.shared.showIncompleteDataWarning) { _, newValue in
                showIncompleteDataWarning = newValue
            }
            .alert("Incomplete Data Warning", isPresented: $showIncompleteDataWarning) {
                Button("OK", role: .cancel) {
                    SchwabClient.shared.showIncompleteDataWarning = false
                }
            } message: {
                Text("The information for \(symbol) may be incomplete and inaccurate due to missing historical data.")
            }
        }
        .withLoadingState(loadingState)
    }

} // SalesCalcView

