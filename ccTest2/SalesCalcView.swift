import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif



enum SalesCalcColumns : String, CaseIterable
{
    case OpenDate         = "Open Date"
    case GainLossPct      = "Gain/Loss %"
    case GainLossDollar   = "Gain/Loss $"
    case Quantity         = "Quantity"
    case Price            = "Price"
    case CostPerShare     = "Cost/Share"
    case MarketValue      = "Market Value"
    case CostBasis        = "Cost Basis"
    case HoldingPeriod    = "Holding Period"
}

enum ResultsColumns : String, CaseIterable
{
    case RollingGainLoss  = "Rolling Gain/Loss"
    case Breakeven        = "Breakeven"
    case Gain             = "Gain"
    case SharesToSell     = "Shares to Sell"
    case TrailingStop     = "TS"
    case Entry            = "Entry"
    case Cancel           = "Cancel"
    case Description      = "Description"
}

struct SalesCalcRecord: Identifiable
{
    let id = UUID()
    var openDate: String = ""
    var gainLossPct: Double = 0.0
    var gainLossDollar: Double = 0.0
    var quantity: Double = 0
    var price: Double = 0.0
    var costPerShare: Double = 0.0
    var marketValue: Double = 0.0
    var costBasis: Double = 0.0
    var holdingPeriod: String = ""
}

struct ResultsRecord: Identifiable
{
    let id = UUID()
    var shares : Double = 0.0
    var rollingGainLoss: Double = 0.0
    var breakEven: Double = 0.0
    var gain: Double = 0.0
    var sharesToSell: Double = 0.0
    var trailingStop: Double = 0.0
    var entry: Double = 0.0
    var cancel: Double = 0.0
    var description: String = ""
    var openDate: String = ""
}

// BUY 10% (of +138 currently) PLTR @89.85 (LAST+0.05%) TRSTPLMT LAST+5.93%(5.60) (STP 94.36) BID GTC OCO #1002926348365 SUBMIT AT 3/12/25 09:40:00 WHEN PLTR BID AT OR ABOVE 89.82
struct BuyOrder: Identifiable
{
    let id = UUID()
    var percent          : Double = 0.0
    var equivalentShares : Int = 0
    var trailingStop     : Double = 0.0
    var submitDate       : Date = Date()
    var bidPriceOver     : Double = 0.0
}


struct SalesCalcView: View
{
    // source data
    let sourceColumns: [GridItem] = Array(repeating: .init(.flexible()), count: SalesCalcColumns.allCases.count)
    @State var sourceData: [SalesCalcRecord] = []
    // buy order
    @State var buyOrder: BuyOrder? = nil
    // sell order
    @State var sellOrder: ResultsRecord? = nil
    // position statements
    @Binding var positionStatementData: [PositionStatementData]
    
    // results data with custom width for Description column
    let resultsColumns: [GridItem] = ResultsColumns.allCases.map { column in
        if column == .Description {
            return GridItem(.flexible(minimum: 200, maximum: .infinity))
        } else {
            return GridItem(.flexible( minimum: 20, maximum: 100 ))
        }
    }
    @State var resultsData: [ResultsRecord] = []
    @State var copiedValue: String = "TBD"
    @State var symbol: String = ""
    @State var atrPercent: Double = 0.0
    
    
    var body: some View
    {
        VStack
        {
            // Information row w/ Symbol, ATR, adn what is copied to clipboard
            HStack
            {
                TextField( "Symbol", text: $symbol )
                    .disableAutocorrection( true )
                    .textCase( .uppercase )
                    .onSubmit( )
                {
                    getOrders()
                }
                .padding( .leading )
                Text( "\(atrPercent * 100.0, specifier: "%.2f") %")
                Text( copiedValue )
                    .frame( maxWidth: .infinity, alignment: .trailing)
                    .padding( .trailing )
            }

            // Button for pasting into the view
            Button("Paste from Clipboard")
            {
                var clipboardContent : String = ""
#if canImport(UIKit)
                clipboardContent = UIPasteboard.general.string  ?? "Empty Clipboard Content"
#elseif canImport(AppKit)
                clipboardContent = NSPasteboard.general.string( forType: .string ) ?? "Empty Clipboard Content"
#endif
                if ( false == clipboardContent.isEmpty )
                {
                    //print( "Content: \(clipboardContent)" )

                    sourceData = getRecordsFromClipboard( content: clipboardContent )
                    resultsData = getResults( context: sourceData )
                    getOrders()
                }
                else
                {
                    print("No content in the clipboard")
                }
            }

            // Buy Order Details
            HStack
            {
                Text("Buy Order Details:")
                    .font(.headline)
                    .padding( .horizontal )
                if( nil != buyOrder )
                {
                    Text( "Buy \( buyOrder!.percent * 100.0, specifier: "%.2f") %" )
                    Text( "(\( buyOrder!.equivalentShares, specifier: "%d"))" )
                    Text( "TS: \( buyOrder!.trailingStop * 100.0, specifier: "%.0f") %" )
                    Text( "After: \(buyOrder!.submitDate.dateOnly())" )
                    Text( "Bid >: \(buyOrder!.bidPriceOver, specifier: "%.2f")" )
                }
            }

            // Sell Order Details
            HStack
            {
                Text("Sell Order Details:")
                    .font(.headline)
                    .padding( .horizontal )
                if( nil != sellOrder )
                {
                    Text("\(sellOrder!.rollingGainLoss, specifier: "%.2f")")
                    Text("\(sellOrder!.breakEven, specifier: "%.2f")")
                    Text("\(sellOrder!.gain, specifier: "%.2f")%")
                    Text("\(sellOrder!.sharesToSell, specifier: "%.0f")")
                        .onTapGesture(count: 1) { copyToClipboard( value: sellOrder!.sharesToSell, format: "%.0f" ) }
                        .foregroundStyle( rowStyle(item: sellOrder!) )
                    Text("\(sellOrder!.trailingStop, specifier: "%.1f")%")
                        .onTapGesture(count: 1) { copyToClipboard( value: sellOrder!.trailingStop, format: "%.1f" ) }
                        .foregroundStyle( rowStyle(item: sellOrder!) )
                    Text("\(sellOrder!.entry, specifier: "%.2f")")
                        .onTapGesture(count: 1) { copyToClipboard( value: sellOrder!.entry, format: "%.2f" ) }
                        .foregroundStyle( rowStyle(item: sellOrder!) )
                    Text("\(sellOrder!.cancel, specifier: "%.2f")")
                        .onTapGesture(count: 1) { copyToClipboard( value: sellOrder!.cancel, format: "%.2f" ) }
                        .foregroundStyle( rowStyle(item: sellOrder!) )
                    Text( "     " )
                    Text(sellOrder!.description)
                        .onTapGesture(count: 1) { copyToClipboard( text: sellOrder!.description ) }
                        .foregroundStyle( rowStyle(item: sellOrder!) )
                }
            }




            // TItle row for the pasted data
            LazyVGrid(columns: sourceColumns, spacing: 20)
            {
                ForEach(SalesCalcColumns.allCases, id: \.self)
                { column in
                    Text(column.rawValue)
                        .font(.headline)
                }
                .background(Color.gray.opacity(0.2))
                .padding(.horizontal)
            }
            // ScrollView with the pasted data
            ScrollView
            {
                LazyVGrid(columns: sourceColumns, spacing: 20)
                {
                    ForEach(sourceData)
                    { item in
                        Text(item.openDate)
                            .foregroundStyle( daysBetweenDates(dateString: item.openDate) ?? 0 > 30 ? .green : .red )
                        Text("\(item.gainLossPct, specifier: "%.2f")%")
                            .foregroundStyle( item.gainLossPct > 5.0 ? .green : item.gainLossPct > 0.0 ? .yellow : .red )
                        Text("\(item.gainLossDollar, specifier: "%.2f")")
                            .foregroundStyle( item.gainLossDollar > 0.0 ? .green : .red )
                        
                        Text("\(item.quantity, specifier: "%.2f")")
                        Text("\(item.price, specifier: "%.2f")")
                        Text("\(item.costPerShare, specifier: "%.2f")")
                        Text("\(item.marketValue, specifier: "%.2f")")
                        Text("\(item.costBasis, specifier: "%.2f")")
                        
                        Text(item.holdingPeriod)
                    }
                    .background(Color.gray.opacity(0.1))
                    
                } //LazyVGrid
            } // ScrollView with the pasted data
            
            // Title row for the results
            LazyVGrid(columns: resultsColumns, spacing: 20)
            {
                ForEach(ResultsColumns.allCases, id: \.self)
                { column in
                    Text(column.rawValue)
                        .font(.headline)
                }
                .background(Color.gray.opacity(0.2))
                .padding(.horizontal)
            }
            // ScrollView with the results
            ScrollView
            {
                LazyVGrid(columns: resultsColumns, spacing: 20)
                {
                    ForEach(resultsData)
                    { item in
                        Text("\(item.rollingGainLoss, specifier: "%.2f")")
                        Text("\(item.breakEven, specifier: "%.2f")")
                        Text("\(item.gain, specifier: "%.2f")%")
                        Text("\(item.sharesToSell, specifier: "%.0f")")
                            .onTapGesture(count: 1) { copyToClipboard( value: item.sharesToSell, format: "%.0f" ) }
                            .foregroundStyle( rowStyle(item: item) )
                        Text("\(item.trailingStop, specifier: "%.1f")%")
                            .onTapGesture(count: 1) { copyToClipboard( value: item.trailingStop, format: "%.1f" ) }
                            .foregroundStyle( rowStyle(item: item) )
                        Text("\(item.entry, specifier: "%.2f")")
                            .onTapGesture(count: 1) { copyToClipboard( value: item.entry, format: "%.2f" ) }
                            .foregroundStyle( rowStyle(item: item) )
                        Text("\(item.cancel, specifier: "%.2f")")
                            .onTapGesture(count: 1) { copyToClipboard( value: item.cancel, format: "%.2f" ) }
                            .foregroundStyle( rowStyle(item: item) )
                        Text(item.description)
                            .onTapGesture(count: 1) { copyToClipboard( text: item.description ) }
                            .foregroundStyle( rowStyle(item: item) )
                    }
                    .background(Color.gray.opacity(0.1))
                } //LazyVGrid
            } // ScrollView with the results
            Spacer()
            
            
        } // VStack
    }
    
    private func rowStyle( item: ResultsRecord ) -> Color
    {
        // print( "Trailing Stop: \(item.trailingStop), Open Date: \(item.openDate)" )
        return ( ( item.trailingStop <= 2.0 ) || ( daysBetweenDates(dateString: item.openDate) ?? 0 < 31  ) )
        ? Color.red
        : item.trailingStop < 5.0
        ? Color.yellow
        : Color.green
    }
    
    
    // Function to calculate the difference in days between today and a given date string
    // This function was suggested by GitHub Copilot
    private func daysBetweenDates(dateString: String) -> Int?
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        
        // Convert the date string to a Date object
        guard let date = dateFormatter.date(from: dateString) else {
            print("Invalid date format")
            return nil
        }
        
        // Get today's date
        let today = Date()
        
        // Calculate the difference in days
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: today)
        
        return components.day
    }
    
    private func copyToClipboard( text: String )
    {
#if canImport(UIKit)
        UIPasteboard.general.string = text
        copiedValue = UIPasteboard.general.string ?? "no string"
#elseif canImport(AppKit)
        NSPasteboard.general.setString( text, forType: .string )
        copiedValue = NSPasteboard.general.string(forType: .string) ?? "no string"
#endif
    }
    
    private func copyToClipboard( value: Double, format: String )
    {
#if canImport(UIKit)
        UIPasteboard.general.string = String( format: format, value )
        copiedValue = UIPasteboard.general.string ?? "no double"
#elseif canImport(AppKit)
        NSPasteboard.general.setString( String( format: format, value ), forType: .string )
        copiedValue = NSPasteboard.general.string(forType: .string) ?? "no double"
#endif
    }

    private func getResults( context: [SalesCalcRecord] ) -> [ResultsRecord]
    {
        var results : [ResultsRecord] = []
        var rollingGain : Double = 0.0
        var totalShares : Double = 0.0
        var totalCost:    Double = 0.0

        // populate results collection
        for item in context
        {
            totalShares += item.quantity
            totalCost   += item.costBasis
            rollingGain += item.gainLossDollar
            let breakEven : Double = totalCost / totalShares
            /** @TODO:  round this. */
            let gain : Double      = ( ( ( item.price - breakEven ) / item.price ) - 0.005 ) * 100.0
            let trailingStop: Double = gain / 2.5 - 0.5
            let entry: Double      = item.price * ( 1 - trailingStop / 100.0 ) + 0.005
            let cancel: Double     = (entry - 0.005) * ( 1 - trailingStop / 100.0 ) - 0.005
            
            let result : ResultsRecord = ResultsRecord(
                shares:           totalShares,
                rollingGainLoss:  rollingGain,
                breakEven:        breakEven,
                gain:             gain,
                sharesToSell:     totalShares,
                trailingStop:     trailingStop,
                entry:            entry,
                cancel:           cancel,
                description: String(format: "Sell %.0f shares TS=%.1f, Entry Ask < %.2f, Cancel Ask < %.2f", totalShares, trailingStop, entry, cancel),
                openDate:        item.openDate
            )
            results.append( result )
        }
        return results
    }
    
    
    
    private func getRecordsFromClipboard(content: String)  -> [SalesCalcRecord]
    {
        var allResults : [SalesCalcRecord] = []
        var currentRow : [String] = []
        let rows : [String] = content.components( separatedBy: "\n" )
        // data rows appear as two rows when copied from the web site, the first with the date, the second tab delimited columns
        for row in rows
        {
            //print( "ROW:  \(row)" )
            var dataFields : [String] = row.split( separator: "\t" ).map{ String($0) }
            // handle the case where we get the date separately
            if( dataFields.count == 1 )
            { // got just the date, create a new currentRow collection
                currentRow = dataFields
                //print( " Got date:  \(currentRow)" )
                continue
            }
            else if( dataFields.count == SalesCalcColumns.allCases.count - 1 )
            { // got all but the date, append to currentRow
                dataFields.insert(contentsOf: currentRow, at: 0)
                //print( " Filled in:  \(dataFields)" )
            }
            if( dataFields.count == SalesCalcColumns.allCases.count )
            {
                //print( "Fields: \(dataFields)" )
                var record : SalesCalcRecord = SalesCalcRecord()
                var indx : Int = 0
                record.openDate       = dataFields[ indx ]; indx += 1;
                record.quantity       = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
                record.price          = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
                record.costPerShare   = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
                record.marketValue    = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
                record.costBasis      = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
                record.gainLossDollar = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
                record.gainLossPct    = stringToDouble(  content: dataFields[ indx ] ); indx += 1;
                record.holdingPeriod  = dataFields[ indx ]; indx += 1;
                
                allResults.append( record )
            }
            else
            {
                print( "fields size (\(dataFields.count)) != columns size (\(SalesCalcColumns.allCases.count)) \n\t  for pasted row: \(row) \n\t  from content: \(content)" )
            }
        }
        // Sort the array by costPerShare in descending order
        return allResults.sorted { $0.costPerShare > $1.costPerShare }
    } // getRecordsFromClipboard
    
    
    // get buy and sell order details
    private func getOrders()
    {
        var atrPercent : Double = 0.0
        var quantity   : Double = 0.0
        var netLiquid  : Double = 0.0
        var lastPrice  : Double = 0.0
        var gainPct    : Double = 0.0
        var equivalentShares : Int = 0
        var bidPriceOver : Double = 0.0
        
        // Populate ATR field
        // get the 1.5*ATR value from the data record with the symbol
        var indx : Int = 0
        self.symbol = self.symbol.uppercased()
        while( indx < $positionStatementData.count )
        {
            if( positionStatementData[indx].instrument == self.symbol )
            {
                // The ATR I pull from ThinkOrSwim is actually ATR*1.5.  Divide here to compensate.
                atrPercent = positionStatementData[indx].atr / positionStatementData[indx].last
                quantity   = positionStatementData[indx].quantity
                netLiquid  = positionStatementData[indx].netLiquid
                lastPrice  = positionStatementData[indx].last
                gainPct    = positionStatementData[indx].plPercent / 100.0

                bidPriceOver = positionStatementData[indx].last + ( 2.0 * positionStatementData[indx].atr )

                self.atrPercent = atrPercent
                break
            }
            indx += 1
        }

        print( "atrPercent = \(atrPercent),   quantity = \(quantity),   netLiquid = \(netLiquid),   lastPrice = \(lastPrice),   gainPct = \(gainPct)" )

        // Populate sell order
        // Iterate over resultsData to find the result record with a Trailing Stop > atrPercent
        for( result ) in self.resultsData
        {
            // print( "result.trailingStop = \(result.trailingStop),  atrPercent = \(atrPercent)" )
            if( result.trailingStop > atrPercent )
            {
                self.sellOrder = result
                break
            }
        }

        // The percentage we buy will be half of the percent gain to a max of $2000 and a minimum of 1 share
        var buyPercent : Double = gainPct / 2.0
        if( ( 0.0 != netLiquid ) && ( 2000.0 < buyPercent * netLiquid ) )
        { // if buying that percent results in more than $2000, lower the percent to a $2000 buy.
            buyPercent = 2000.0 / netLiquid - 0.005
            print( "buyPercent adjusted to 2000 limit = \(buyPercent*100.0),  netLiquid = \(netLiquid),  gainPct = \(gainPct*100.0)" )
        }
        // Minimum buy would be 1 share
        if( ( 0.0 != quantity ) && ( 1.0 > buyPercent * quantity ) )
        {
            buyPercent = 1.0 / quantity + 0.01
            print( "setting for minimum buy of 1 share - buyPercent = \(buyPercent),  quantity = \(quantity)" )
        }
        equivalentShares = Int( buyPercent * quantity )
        print( "buyPercent = \(buyPercent),  quantity = \(quantity),   equivalentShares = \(equivalentShares)" )

        // Submittion date
        let nextTradeDate = getNextTradeDate()

        // Set order entry over bid of the greater of the last buy price and the average
        // of the last and greatest buy points and half atr over the current price.



        // Populate buy order
        buyOrder = BuyOrder( percent: buyPercent,
                             equivalentShares: equivalentShares,
                             trailingStop: atrPercent,
                             submitDate: nextTradeDate,
                             bidPriceOver: bidPriceOver
        )


    }





} // TableView


#Preview
{ 
    @Previewable @State var positionStatementData: [PositionStatementData] = []
    SalesCalcView( positionStatementData: $positionStatementData )
}
