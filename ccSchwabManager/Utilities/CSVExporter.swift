import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
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
    
    static func exportHoldings(_ positions: [Position], accountPositions: [(Position, String, String)], tradeDates: [String: String] = [:], orderStatuses: [String: ActiveOrderStatus?] = [:]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let currentDate = dateFormatter.string(from: Date())
        let defaultFileName = "Holdings_\(currentDate).csv"
        
        let csvContent = generateHoldingsCSV(positions, accountPositions: accountPositions, tradeDates: tradeDates, orderStatuses: orderStatuses)
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
        var csv = "Open Date,Quantity,Price,Cost/Share,Market Value,Cost Basis,Gain/Loss $,Gain/Loss %,Split Multiple\n"
        
        for taxLot in taxLots {
            let openDate = taxLot.openDate
            let quantity = String(format: "%.2f", taxLot.quantity)
            let price = String(format: "%.2f", taxLot.price)
            let costPerShare = String(format: "%.2f", taxLot.costPerShare)
            let marketValue = String(format: "%.2f", taxLot.marketValue)
            let costBasis = String(format: "%.2f", taxLot.costBasis)
            let gainLossDollar = String(format: "%.2f", taxLot.gainLossDollar)
            let gainLossPct = String(format: "%.2f", taxLot.gainLossPct)
            let splitMultiple = String(format: "%.2f", taxLot.splitMultiple)
            
            csv += "\(openDate),\(quantity),\(price),\(costPerShare),\(marketValue),\(costBasis),\(gainLossDollar),\(gainLossPct),\(splitMultiple)\n"
        }
        
        return csv
    }
    
    static func generateHoldingsCSV(_ positions: [Position], accountPositions: [(Position, String, String)], tradeDates: [String: String] = [:], orderStatuses: [String: ActiveOrderStatus?] = [:]) -> String {
        var csv = "Symbol,Description,Quantity,Average Price,Market Value,P/L,P/L %,Asset Type,Account,Last Trade Date,Order Status,DTE/Contracts\n"
        
        for position in positions {
            let symbol = position.instrument?.symbol ?? ""
            let description = position.instrument?.description ?? ""
            let quantity = String(format: "%.4f", (position.longQuantity ?? 0) + (position.shortQuantity ?? 0))
            let avgPrice = String(format: "%.2f", position.averagePrice ?? 0)
            let marketValue = String(format: "%.2f", position.marketValue ?? 0)
            let pl = String(format: "%.2f", position.longOpenProfitLoss ?? 0)
            
            // Calculate P/L percentage
            let plPercent: Double
            if let mv = position.marketValue, let plValue = position.longOpenProfitLoss {
                let costBasis = mv - plValue
                plPercent = costBasis != 0 ? (plValue / costBasis) * 100 : 0
            } else {
                plPercent = 0
            }
            let plPercentStr = String(format: "%.2f", plPercent)
            
            let assetType = position.instrument?.assetType?.rawValue ?? ""
            
            // Get account number from accountPositions
            let accountNumber = accountPositions.first { $0.0.id == position.id }?.1 ?? ""
            
            // Get last trade date (this would need to be passed in or calculated)
            let lastTradeDate = tradeDates[symbol] ?? "" // Use passed-in tradeDates
            
            // Get order status (this would need to be passed in or calculated)
            let orderStatus: String
            if let status = orderStatuses[symbol], let unwrappedStatus = status {
                orderStatus = unwrappedStatus.rawValue
            } else {
                orderStatus = ""
            }
            
            // For DTE/Contracts, we'll use a placeholder since we can't call SchwabClient from static context
            let dteContracts = "" // Placeholder - would need to be calculated and passed in
            
            csv += "\(symbol),\(description),\(quantity),\(avgPrice),\(marketValue),\(pl),\(plPercentStr),\(assetType),\(accountNumber),\(lastTradeDate),\(orderStatus),\(dteContracts)\n"
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
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC timezone
        return formatter.string(from: date)
    }
    
    private static func saveCSVFile(content: String, defaultFileName: String) {
        #if os(macOS)
        Task { @MainActor in
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
        }
        #else
        // iOS implementation - trigger the share sheet
        CSVShareManager.shared.shareCSV(content: content, fileName: defaultFileName)
        #endif
    }
} 