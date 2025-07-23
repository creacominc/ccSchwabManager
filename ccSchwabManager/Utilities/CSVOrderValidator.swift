import Foundation

struct CSVOrderValidator {
    
    // MARK: - CSV Data Structures
    
    struct BuyOrderCSVRecord {
        let scenario: String
        let ticker: String
        let atr: Double
        let lastTradeDate: String
        let totalQuantity: Double
        let totalCost: Double
        let lastPrice: Double
        let averagePrice: Double
        let gainPercent: Double
        let sevenXATR: Double
        let targetGainMin15: Double
        let greaterOfLastAndBreakeven: Double
        let entryPrice: Double
        let targetPrice: Double
        let sevenDaysAfterLastTrade: String
        let submitDateTime: String
        let sharesToBuyAtTargetPrice: Double
        let limitShares: Double
        let description: String
    }
    
    struct SellOrderCSVRecord {
        let scenario: String
        let ticker: String
        let atr: Double
        let lastTradeDate: String
        let totalQuantity: Double
        let totalCost: Double
        let lastPrice: Double
        let averagePrice: Double
        let gainPercent: Double
        let sharesToSell: Double
        let entryPrice: Double
        let targetPrice: Double
        let exitPrice: Double
        let submitDateTime: String
        let description: String
    }
    
    // MARK: - CSV Parsing Methods
    
    static func parseBuyOrderCSV(_ csvData: String) -> [BuyOrderCSVRecord] {
        let lines = csvData.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }
        
        var records: [BuyOrderCSVRecord] = []
        
        // Skip header line
        for line in lines.dropFirst() {
            let fields = line.components(separatedBy: ",")
            guard fields.count >= 20 else { continue }
            
            // Parse fields, handling quoted values and empty fields
            let cleanFields = fields.map { field in
                field.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
            }
            
            // Debug: Print the fields to see what we're working with
            print("Parsing buy order line with \(cleanFields.count) fields: \(cleanFields)")
            
            guard let atr = Double(cleanFields[2]),
                  let totalQuantity = Double(cleanFields[5]),
                  let totalCost = Double(cleanFields[6].replacingOccurrences(of: "$", with: "")),
                  let lastPrice = Double(cleanFields[7].replacingOccurrences(of: "$", with: "")),
                  let averagePrice = Double(cleanFields[8].replacingOccurrences(of: "$", with: "")),
                  let gainPercent = Double(cleanFields[9]),
                  let sevenXATR = Double(cleanFields[10]),
                  let targetGainMin15 = Double(cleanFields[11]),
                  let greaterOfLastAndBreakeven = Double(cleanFields[12].replacingOccurrences(of: "$", with: "")),
                  let entryPrice = Double(cleanFields[13].replacingOccurrences(of: "$", with: "")),
                  let targetPrice = Double(cleanFields[14].replacingOccurrences(of: "$", with: "")),
                  let sharesToBuyAtTargetPrice = Double(cleanFields[17]),
                  let limitShares = Double(cleanFields[18]) else {
                print("Failed to parse buy order line: \(cleanFields)")
                continue
            }
            
            let record = BuyOrderCSVRecord(
                scenario: cleanFields[0],
                ticker: cleanFields[1],
                atr: atr,
                lastTradeDate: cleanFields[3],
                totalQuantity: totalQuantity,
                totalCost: totalCost,
                lastPrice: lastPrice,
                averagePrice: averagePrice,
                gainPercent: gainPercent,
                sevenXATR: sevenXATR,
                targetGainMin15: targetGainMin15,
                greaterOfLastAndBreakeven: greaterOfLastAndBreakeven,
                entryPrice: entryPrice,
                targetPrice: targetPrice,
                sevenDaysAfterLastTrade: cleanFields[15],
                submitDateTime: cleanFields[16],
                sharesToBuyAtTargetPrice: sharesToBuyAtTargetPrice,
                limitShares: limitShares,
                description: cleanFields.count > 19 ? cleanFields[19] : ""
            )
            
            records.append(record)
        }
        
        return records
    }
    
    static func parseSellOrderCSV(_ csvData: String) -> [SellOrderCSVRecord] {
        let lines = csvData.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }
        
        var records: [SellOrderCSVRecord] = []
        
        // Skip header line
        for line in lines.dropFirst() {
            let fields = line.components(separatedBy: ",")
            guard fields.count >= 15 else { continue }
            
            // Parse fields, handling quoted values and empty fields
            let cleanFields = fields.map { field in
                field.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
            }
            
            // Debug: Print the fields to see what we're working with
            print("Parsing sell order line with \(cleanFields.count) fields: \(cleanFields)")
            
            guard let atr = Double(cleanFields[2]),
                  let totalQuantity = Double(cleanFields[4]),
                  let totalCost = Double(cleanFields[5].replacingOccurrences(of: "$", with: "")),
                  let lastPrice = Double(cleanFields[6].replacingOccurrences(of: "$", with: "")),
                  let averagePrice = Double(cleanFields[7].replacingOccurrences(of: "$", with: "")),
                  let gainPercent = Double(cleanFields[8]),
                  let sharesToSell = Double(cleanFields[9]),
                  let entryPrice = Double(cleanFields[10].replacingOccurrences(of: "$", with: "")),
                  let targetPrice = Double(cleanFields[11].replacingOccurrences(of: "$", with: "")),
                  let exitPrice = Double(cleanFields[12].replacingOccurrences(of: "$", with: "")) else {
                print("Failed to parse sell order line: \(cleanFields)")
                continue
            }
            
            let record = SellOrderCSVRecord(
                scenario: cleanFields[0],
                ticker: cleanFields[1],
                atr: atr,
                lastTradeDate: cleanFields[3],
                totalQuantity: totalQuantity,
                totalCost: totalCost,
                lastPrice: lastPrice,
                averagePrice: averagePrice,
                gainPercent: gainPercent,
                sharesToSell: sharesToSell,
                entryPrice: entryPrice,
                targetPrice: targetPrice,
                exitPrice: exitPrice,
                submitDateTime: cleanFields[13],
                description: cleanFields.count > 14 ? cleanFields[14] : ""
            )
            
            records.append(record)
        }
        
        return records
    }
    
    // MARK: - Validation Methods
    
    static func validateBuyOrderLogic(_ record: BuyOrderCSVRecord) -> [String] {
        var errors: [String] = []
        
        // Validate entry price calculation
        let expectedEntryPrice = record.greaterOfLastAndBreakeven * (1.0 + record.atr / 100.0)
        if abs(expectedEntryPrice - record.entryPrice) > 0.01 {
            errors.append("Entry price calculation error: expected \(expectedEntryPrice), got \(record.entryPrice)")
        }
        
        // Validate target price calculation
        let expectedTargetPrice = record.entryPrice * (1.0 + record.atr / 100.0)
        if abs(expectedTargetPrice - record.targetPrice) > 0.01 {
            errors.append("Target price calculation error: expected \(expectedTargetPrice), got \(record.targetPrice)")
        }
        
        // Validate target gain calculation
        let expectedTargetGain = max(15.0, 7.0 * record.atr)
        if abs(expectedTargetGain - record.targetGainMin15) > 0.1 {
            errors.append("Target gain calculation error: expected \(expectedTargetGain), got \(record.targetGainMin15)")
        }
        
        // Validate shares calculation
        let expectedSharesToBuy = (record.totalQuantity * record.targetPrice - record.totalCost) / (record.targetPrice - record.averagePrice)
        if abs(expectedSharesToBuy - record.limitShares) > 1.0 {
            errors.append("Shares calculation error: expected \(expectedSharesToBuy), got \(record.limitShares)")
        }
        
        return errors
    }
    
    static func validateSellOrderLogic(_ record: SellOrderCSVRecord) -> [String] {
        var errors: [String] = []
        
        // Validate that target price is above average price
        if record.targetPrice <= record.averagePrice {
            errors.append("Target price should be above average price")
        }
        
        // Validate that entry price is below last price
        if record.entryPrice >= record.lastPrice {
            errors.append("Entry price should be below last price")
        }
        
        // Validate that exit price is below target price
        if record.exitPrice >= record.targetPrice {
            errors.append("Exit price should be below target price")
        }
        
        // Validate shares to sell is reasonable
        if record.sharesToSell > record.totalQuantity {
            errors.append("Shares to sell cannot exceed total quantity")
        }
        
        return errors
    }
    
    // MARK: - File Loading Methods
    
    static func loadCSVFromFile(_ filePath: String) -> String? {
        do {
            return try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            print("Error loading CSV file: \(error)")
            return nil
        }
    }
    
    static func validateCSVFile(_ filePath: String, orderType: String) -> [String] {
        guard let csvData = loadCSVFromFile(filePath) else {
            return ["Failed to load CSV file"]
        }
        
        var allErrors: [String] = []
        
        if orderType.lowercased() == "buy" {
            let records = parseBuyOrderCSV(csvData)
            for (index, record) in records.enumerated() {
                let errors = validateBuyOrderLogic(record)
                for error in errors {
                    allErrors.append("Row \(index + 1) (\(record.ticker)): \(error)")
                }
            }
        } else if orderType.lowercased() == "sell" {
            let records = parseSellOrderCSV(csvData)
            for (index, record) in records.enumerated() {
                let errors = validateSellOrderLogic(record)
                for error in errors {
                    allErrors.append("Row \(index + 1) (\(record.ticker)): \(error)")
                }
            }
        }
        
        return allErrors
    }
} 