
import SwiftUI
import UniformTypeIdentifiers

enum PositionStatementColumns : String, CaseIterable
{
    // Instrument,Qty,Net Liq,Trade Price,Last,ATR,HT_FPL,Account Name,Company Name,P/L %,P/L Open
    case Instrument = "Instrument"
    case Quantity = "Qty"
    case NetLiquid = "Net Liq"
    case TradePrice = "Trade Price"
    case Last = "Last"
    case ATR = "ATR"
    case FloatingPL = "HT_FPL"
    case Account = "Account Name"
    case Company = "Company Name"
    case PLPercent = "P/L %"
    case PLOpen = "P/L Open"
}

struct PositionStatementView: View
{
    // source data
    let sourceColumns: [GridItem] = Array(repeating: .init(.flexible()), count: PositionStatementColumns.allCases.count)
    @Binding var positionStatementData: [PositionStatementData]
    // results data with custom width for Description column

    var body: some View
    {
        VStack
        {
            Text( "PositionStatement" )
                .onAppear()
            {
                let url = Bundle.main.url(forResource: "PositionStatement", withExtension: "csv")
                positionStatementData = parseCSV(url: url )
            }
            if positionStatementData.isEmpty
            {
                Text("No data loaded")
            }
            else
            {
                LazyVGrid(columns: sourceColumns, spacing: 10)
                {
                    ForEach( PositionStatementColumns.allCases, id: \.self )
                    { column in
                        Text(column.rawValue)
                            .font(.headline)
                    }
                    .background(Color.gray.opacity(0.2))
                }

                ScrollView
                {

                    // Table( data: data )
                    LazyVGrid(columns: sourceColumns, spacing: 10)
                    {

                        ForEach( positionStatementData )
                        { positionStatement   in
                            Text( positionStatement.instrument )
                            Text("\(positionStatement.quantity, specifier: "%.2f")")
                            Text("\(positionStatement.netLiquid, specifier: "%.2f")")
                            Text("\(positionStatement.tradePrice, specifier: "%.2f")")
                            Text("\(positionStatement.last, specifier: "%.2f")")
                            Text("\(positionStatement.atr, specifier: "%.2f")")
                            Text("\(positionStatement.floatingPL, specifier: "%.2f")")
                            Text( positionStatement.account )
                            Text( positionStatement.company )
                            Text("\(positionStatement.plPercent, specifier: "%.2f")%")
                            Text("\(positionStatement.plOpen, specifier: "%.2f")")
                        }
                        .background(Color.gray.opacity(0.1))
                    }
                    .padding() //LazyVGrid
                } // ScrollView

            } // if positionStatementData

        } // VStack
    } // body

}
