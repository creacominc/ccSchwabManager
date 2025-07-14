import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class CSVExporter {
    
    static func exportTransactions(_ transactions: [Transaction], symbol: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let currentDate = dateFormatter.string(from: Date())
        let defaultFileName = "Transactions_\(symbol)_\(currentDate).csv"
        
        let csvContent = generateTransactionCSV(transactions, symbol: symbol)
        saveCSVFile(content: csvContent, defaultFileName: defaultFileName)
    }
    
    static func exportTaxLots(_ taxLots: [SalesCalcPositionsRecord], symbol: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let currentDate = dateFormatter.string(from: Date())
        let defaultFileName = "TaxLots_\(symbol)_\(currentDate).csv"
        
        let csvContent = generateTaxLotCSV(taxLots)
        saveCSVFile(content: csvContent, defaultFileName: defaultFileName)
    }
    
    static func generateTransactionCSV(_ transactions: [Transaction], symbol: String) -> String {
        var csv = "Date,Type,Quantity,Price,Net Amount\n"
        
        for transaction in transactions {
            let date = formatTransactionDate(transaction.tradeDate)
            let type = transaction.netAmount ?? 0 < 0 ? "Buy" : transaction.netAmount ?? 0 > 0 ? "Sell" : "Unknown"
            
            if let transferItem = transaction.transferItems.first(where: { $0.instrument?.symbol == symbol }) {
                let quantity = String(format: "%.4f", transferItem.amount ?? 0)
                let price = String(format: "%.2f", transferItem.price ?? 0)
                let netAmount = String(format: "%.2f", transaction.netAmount ?? 0)
                
                csv += "\(date),\(type),\(quantity),\(price),\(netAmount)\n"
            }
        }
        
        return csv
    }
    
    static func generateTaxLotCSV(_ taxLots: [SalesCalcPositionsRecord]) -> String {
        var csv = "Open Date,Quantity,Price,Cost/Share,Market Value,Cost Basis,Gain/Loss $,Gain/Loss %\n"
        
        for taxLot in taxLots {
            let openDate = taxLot.openDate
            let quantity = String(format: "%.2f", taxLot.quantity)
            let price = String(format: "%.2f", taxLot.price)
            let costPerShare = String(format: "%.2f", taxLot.costPerShare)
            let marketValue = String(format: "%.2f", taxLot.marketValue)
            let costBasis = String(format: "%.2f", taxLot.costBasis)
            let gainLossDollar = String(format: "%.2f", taxLot.gainLossDollar)
            let gainLossPct = String(format: "%.2f", taxLot.gainLossPct)
            
            csv += "\(openDate),\(quantity),\(price),\(costPerShare),\(marketValue),\(costBasis),\(gainLossDollar),\(gainLossPct)\n"
        }
        
        return csv
    }
    
    static func formatTransactionDate(_ dateString: String?) -> String {
        guard let dateString = dateString,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private static func saveCSVFile(content: String, defaultFileName: String) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = defaultFileName
        savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    print("CSV file saved successfully to: \(url.path)")
                } catch {
                    print("Error saving CSV file: \(error)")
                }
            }
        }
        #else
        // For iOS, we would need to implement a different approach
        // For now, just print the content
        print("CSV content for \(defaultFileName):")
        print(content)
        #endif
    }
} 