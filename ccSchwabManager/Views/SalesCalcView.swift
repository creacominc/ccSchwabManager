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
//
//func copyToClipboard( text: String, copiedValue: inout String )
//{
//#if canImport(UIKit)
//    UIPasteboard.general.string = text
//    copiedValue = UIPasteboard.general.string ?? "no string"
//#elseif canImport(AppKit)
//    NSPasteboard.general.clearContents()
//    NSPasteboard.general.setString( text, forType: .string )
//    copiedValue = NSPasteboard.general.string(forType: .string) ?? "no string"
//#endif
//    // print( "Copied string to clipboard: \(text)" )
//}
//
//func copyToClipboard( value: Double, format: String, copiedValue: inout String )
//{
//#if canImport(UIKit)
//    UIPasteboard.general.string = String( format: format, value )
//    copiedValue = UIPasteboard.general.string ?? "no double"
//#elseif canImport(AppKit)
//    NSPasteboard.general.clearContents()
//    NSPasteboard.general.setString( String( format: format, value ), forType: .string )
//    copiedValue = NSPasteboard.general.string(forType: .string) ?? "no double"
//#endif
//    // print( "Copied double to clipboard: \(String( format: format, value ) )" )
//}
//
//func copyToClipboard( value: Int, format: String, copiedValue: inout String )
//{
//#if canImport(UIKit)
//    UIPasteboard.general.string = String( format: format, value )
//    copiedValue = UIPasteboard.general.string ?? "no Int"
//#elseif canImport(AppKit)
//    NSPasteboard.general.clearContents()
//    NSPasteboard.general.setString( String( format: format, value ), forType: .string )
//    copiedValue = NSPasteboard.general.string(forType: .string) ?? "no Int"
//#endif
//    // print( "Copied Int to clipboard: \(String( format: format, value ) )" )
//}

//func rowStyle( item: SalesCalcResultsRecord ) -> Color
//{
//    // print( "Trailing Stop: \(item.trailingStop), Open Date: \(item.openDate)" )
//    return ( ( item.trailingStop <= 2.0 ) || ( daysBetweenDates(dateString: item.openDate) ?? 0 < 31  ) )
//    ? Color.red
//    : item.trailingStop < 5.0
//    ? Color.yellow
//    : Color.green
//}


//struct InformationSection: View
//{
//    @State var copiedValue: String = "TBD"
//    let symbol: String
//    let atrValue: Double
//
//    var body: some View
//    {
//        VStack(alignment: .leading, spacing: 12) {
//            Text(symbol)
//                .font(.title2)
//                .bold()
//                .frame(maxWidth: .infinity, alignment: .center)
//            
//            HStack(spacing: 20) {
//                SalesCalcLeftColumn(atrValue: atrValue)
//                SalesCalcRightColumn(copiedValue: copiedValue)
//            }
//        }
//        .padding()
//        .background(backgroundColor)
//        .frame(maxWidth: .infinity)
//    }
//    
//    private var backgroundColor: Color {
//        #if os(iOS)
//        return Color(.systemBackground)
//        #else
//        return Color(.windowBackgroundColor)
//        #endif
//    }
//}

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

//struct PositionsDataSection: View
//{
//    let symbol : String
//    let sourceData: [SalesCalcPositionsRecord]
//
//    @State var copiedValue: String = "TBD"
//
//    // results data with custom width for Description column
//    let resultsColumns: [GridItem] = SalesCalcResultsColumns.allCases.map { column in
//        if column == .Description {
//            return GridItem(.flexible(minimum: 200, maximum: .infinity))
//        } else {
//            return GridItem(.flexible( minimum: 20, maximum: 100 ))
//        }
//    }
//    let resultsData: [SalesCalcResultsRecord] = []
//
//    // source data
//    let salesCalcColumns: [GridItem] = Array(repeating: .init(.flexible()), count: SalesCalcColumns.allCases.count)
//
//    var body: some View
//    {
//
//        // TItle row for the PositionsDataSection
//        LazyVGrid(columns: salesCalcColumns, spacing: 20)
//        {
//            ForEach(SalesCalcColumns.allCases, id: \.self)
//            { column in
//                Text(column.rawValue)
//                    .font(.headline)
//            }
//            .background(Color.gray.opacity(0.2))
//            .padding(.horizontal)
//        }
//        // ScrollView with the pasted data
//        ScrollView
//        {
//            LazyVGrid(columns: salesCalcColumns, spacing: 20)
//            {
//                ForEach(sourceData)
//                { item in
//                    Text(item.openDate)
//                        .foregroundStyle( daysBetweenDates(dateString: item.openDate) ?? 0 > 30 ? .green : .red )
//                    Text("\(item.quantity, specifier: "%.2f")")
//                    Text("\(item.price, specifier: "%.2f")")
//                    Text("\(item.costPerShare, specifier: "%.2f")")
//                    Text("\(item.marketValue, specifier: "%.2f")")
//                    Text("\(item.costBasis, specifier: "%.2f")")
//                    Text("\(item.gainLossDollar, specifier: "%.2f")")
//                        .foregroundStyle( item.gainLossDollar > 0.0 ? .green : .red )
//                    Text("\(item.gainLossPct, specifier: "%.2f")%")
//                        .foregroundStyle( item.gainLossPct > 5.0 ? .green : item.gainLossPct > 0.0 ? .yellow : .red )
////                    Text(item.holdingPeriod)
//                }
//                .background(Color.gray.opacity(0.1))
//                
//            } //LazyVGrid
//        } // ScrollView with the pasted data
//        
//        // Title row for the results
//        LazyVGrid(columns: resultsColumns, spacing: 20)
//        {
//            ForEach(SalesCalcResultsColumns.allCases, id: \.self)
//            { column in
//                Text(column.rawValue)
//                    .font(.headline)
//            }
//            .background(Color.gray.opacity(0.2))
//            .padding(.horizontal)
//        }
//        // ScrollView with the results
//        ScrollView
//        {
//            LazyVGrid(columns: resultsColumns, spacing: 20)
//            {
//                ForEach(resultsData) { item in
//                    Group {
//                        Text("\(item.rollingGainLoss, specifier: "%.2f")")
//                        Text("\(item.breakEven, specifier: "%.2f")")
//                        Text("\(item.gain, specifier: "%.2f")%")
//                        Text("\(item.sharesToSell, specifier: "%.0f")")
//                            .onTapGesture(count: 1) { copyToClipboard( value: item.sharesToSell, format: "%.0f", copiedValue: &copiedValue ) }
//                            .foregroundStyle( rowStyle(item: item) )
//                        Text("\(item.trailingStop, specifier: "%.1f")%")
//                            .onTapGesture(count: 1) { copyToClipboard( value: item.trailingStop, format: "%.1f", copiedValue: &copiedValue ) }
//                            .foregroundStyle( rowStyle(item: item) )
//                        Text("\(item.entry, specifier: "%.2f")")
//                            .onTapGesture(count: 1) { copyToClipboard( value: item.entry, format: "%.2f", copiedValue: &copiedValue ) }
//                            .foregroundStyle( rowStyle(item: item) )
//                        Text("\(item.cancel, specifier: "%.2f")")
//                            .onTapGesture(count: 1) { copyToClipboard( value: item.cancel, format: "%.2f", copiedValue: &copiedValue ) }
//                            .foregroundStyle( rowStyle(item: item) )
//                        Text(item.description)
//                            .onTapGesture(count: 1) { copyToClipboard( text: item.description, copiedValue: &copiedValue ) }
//                            .foregroundStyle( rowStyle(item: item) )
//                    }
//                }
//                .background(Color.gray.opacity(0.1))
//            } //LazyVGrid
//        } // ScrollView with the results
//    }
//}
//
//struct LoadingOverlay: View {
//    var body: some View {
//        ZStack {
//            Color.black.opacity(0.4)
//                .edgesIgnoringSafeArea(.all)
//            ProgressView()
//                .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                .scaleEffect(1.5)
//        }
//    }
//}

/**
            InformationSectiom:          symbol,   atrPercent,  copiedValue
            BuyOrderDetailSection:      Buy $ shares TS After Bid
            SellOrderDetailSection:      current positions
 */

class SalesCalcViewModel: ObservableObject {
    @Published var positionsData: [SalesCalcPositionsRecord] = []
    private let schwabClient = SchwabClient.shared
    
    func refreshData(symbol: String) {
        print("Refreshing data for symbol: \(symbol)")
        positionsData = schwabClient.computeTaxLots(symbol: symbol)
        print("refreshData - Received \(positionsData.count) tax lot records")
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
//                InformationSection(symbol: symbol, atrValue: atrValue)
//                    .padding(.horizontal)
//                PositionsDataSection(symbol: symbol,
//                                     sourceData: positionsData)

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
                    viewModel.refreshData(symbol: symbol)
                }
            }
            .onChange(of: symbol) { _, newValue in
                print("Symbol changed to: \(newValue)")
                // Use DispatchQueue to ensure we're using the latest symbol value
                DispatchQueue.main.async {
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
    
    //    private func getResults( context: [SalesCalcPositionsRecord] ) -> [ResultsRecord]
    //    {
    //        var results : [ResultsRecord] = []
    //        var rollingGain : Double = 0.0
    //        var totalShares : Double = 0.0
    //        var totalCost:    Double = 0.0
    //
    //        // populate results collection
    //        for item in context
    //        {
    //            totalShares += item.quantity
    //            totalCost   += item.costBasis
    //            rollingGain += item.gainLossDollar
    //            let breakEven : Double = totalCost / totalShares
    //            /** @TODO:  round this. */
    //            let gain : Double      = ( ( ( item.price - breakEven ) / item.price ) - 0.005 ) * 100.0
    //            let trailingStop: Double = gain / 2.5 - 0.5
    //            let entry: Double      = item.price * ( 1 - trailingStop / 100.0 ) + 0.005
    //            let cancel: Double     = (entry - 0.005) * ( 1 - trailingStop / 100.0 ) - 0.005
    //
    //            let result : ResultsRecord = ResultsRecord(
    //                shares:           totalShares,
    //                rollingGainLoss:  rollingGain,
    //                breakEven:        breakEven,
    //                gain:             gain,
    //                sharesToSell:     totalShares,
    //                trailingStop:     trailingStop,
    //                entry:            entry,
    //                cancel:           cancel,
    //                description: String(format: "Sell %.0f shares TS=%.1f, Entry Ask < %.2f, Cancel Ask < %.2f", totalShares, trailingStop, entry, cancel),
    //                openDate:        item.openDate
    //            )
    //            results.append( result )
    //        }
    //        return results
    //    }
    //
        
        
    //    private func getRecordsFromClipboard(content: String)  -> [SalesCalcPositionsRecord]
    //    {
    //        var allResults : [SalesCalcPositionsRecord] = []
    //        var currentRow : [String] = []
    //        let rows : [String] = content.components( separatedBy: "\n" )
    //        // data rows appear as two rows when copied from the web site, the first with the date, the second tab delimited columns
    //        for row in rows
    //        {
    //            //print( "ROW:  \(row)" )
    //            var dataFields : [String] = row.split( separator: "\t" ).map{ String($0) }
    //            // handle the case where we get the date separately
    //            if( dataFields.count == 1 )
    //            { // got just the date, create a new currentRow collection
    //                currentRow = dataFields
    //                //print( " Got date:  \(currentRow)" )
    //                continue
    //            }
    //            else if( dataFields.count == SalesCalcColumns.allCases.count - 1 )
    //            { // got all but the date, append to currentRow
    //                dataFields.insert(contentsOf: currentRow, at: 0)
    //                //print( " Filled in:  \(dataFields)" )
    //            }
    //            if( dataFields.count == SalesCalcColumns.allCases.count )
    //            {
    //                //print( "Fields: \(dataFields)" )
    //                var record : SalesCalcPositionsRecord = SalesCalcPositionsRecord()
    //                var indx : Int = 0
    //                record.openDate       = dataFields[ indx ]; indx += 1;
    //                record.quantity       = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
    //                record.price          = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
    //                record.costPerShare   = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
    //                record.marketValue    = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
    //                record.costBasis      = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
    //                record.gainLossDollar = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
    //                record.gainLossPct    = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
    //                record.holdingPeriod  = dataFields[ indx ]; indx += 1;
    //
    //                allResults.append( record )
    //            }
    //            else
    //            {
    //                print( "fields size (\(dataFields.count)) != columns size (\(SalesCalcColumns.allCases.count)) \n\t  for pasted row: \(row) \n\t  from content: \(content)" )
    //            }
    //        }
    //        // Sort the array by costPerShare in descending order
    //        return allResults.sorted { $0.costPerShare > $1.costPerShare }
    //    } // getRecordsFromClipboard

    //
    //    // get buy and sell order details
    //    private func getOrders()
    //    {
    //        var atrPercent : Double = 0.0
    //        var quantity   : Double = 0.0
    //        var netLiquid  : Double = 0.0
    //        // var lastPrice  : Double = 0.0
    //        var gainPct    : Double = 0.0
    //        var equivalentShares : Int = 0
    //        var bidPriceOver : Double = 0.0
    //
    //        // Populate ATR field
    //        // get the 1.5*ATR value from the data record with the symbol
    //        var indx : Int = 0
    //        self.symbol = self.symbol.uppercased()
    //        while( indx < $positionStatementData.count )
    //        {
    //            if( positionStatementData[indx].instrument == self.symbol )
    //            {
    //                // The ATR I pull from ThinkOrSwim is actually ATR*1.5.  Divide here to compensate.
    //                atrPercent = positionStatementData[indx].atr / positionStatementData[indx].last
    //                quantity   = positionStatementData[indx].quantity
    //                netLiquid  = positionStatementData[indx].netLiquid
    //                // lastPrice  = positionStatementData[indx].last
    //                gainPct    = positionStatementData[indx].plPercent / 100.0
    //
    //                bidPriceOver = positionStatementData[indx].last + ( 2.0 * positionStatementData[indx].atr )
    //
    //                self.atrPercent = atrPercent
    //                break
    //            }
    //            indx += 1
    //        }
    //
    //        // print( "atrPercent = \(atrPercent),   quantity = \(quantity),   netLiquid = \(netLiquid),   lastPrice = \(lastPrice),   gainPct = \(gainPct)" )
    //
    //        // Populate sell order
    //        // Iterate over resultsData to find the result record with a Trailing Stop > atrPercent
    //        for( result ) in self.resultsData
    //        {
    //            //print( "result.trailingStop = \(result.trailingStop),  atrPercent = \(atrPercent),  sharesToSell = \(result.sharesToSell),  gain = \(result.gain) " )
    //            if( ( result.trailingStop > 100.0 * atrPercent ) && ( 2.0 < result.gain ) )
    //            {
    //                self.sellOrder = result
    //                break
    //            }
    //        }
    //
    //        // The percentage we buy will be half of the percent gain to a max of $2000 and a minimum of 1 share
    //        var buyPercent : Double = gainPct / 2.0
    //        if( ( 0.0 != netLiquid ) && ( 2000.0 < buyPercent * netLiquid ) )
    //        { // if buying that percent results in more than $2000, lower the percent to a $2000 buy.
    //            buyPercent = 2000.0 / netLiquid - 0.005
    //            // print( "buyPercent adjusted to 2000 limit = \(buyPercent*100.0),  netLiquid = \(netLiquid),  gainPct = \(gainPct*100.0)" )
    //        }
    //        // Minimum buy would be 1 share
    //        if( ( 0.0 != quantity ) && ( 1.0 > buyPercent * quantity ) )
    //        {
    //            buyPercent = 1.0 / quantity + 0.01
    //            // print( "setting for minimum buy of 1 share - buyPercent = \(buyPercent),  quantity = \(quantity)" )
    //        }
    //        equivalentShares = Int( buyPercent * quantity )
    //        // print( "buyPercent = \(buyPercent),  quantity = \(quantity),   equivalentShares = \(equivalentShares)" )
    //
    //        // Submittion date
    //        let nextTradeDate = getNextTradeDate()
    //
    //        // Set order entry over bid of the greater of the last buy price and the average
    //        // of the last and greatest buy points and half atr over the current price.
    //
    //
    //
    //        // Populate buy order
    //        buyOrder = BuyOrder( percent: buyPercent,
    //                             equivalentShares: equivalentShares,
    //                             trailingStop: atrPercent,
    //                             submitDate: nextTradeDate,
    //                             bidPriceOver: bidPriceOver
    //        )
    //
    //
    //    }
    //


    
} // SalesCalcView

