import Foundation
import os.log

class AppLogger {
    static let shared = AppLogger()
    
    private let logger = Logger(subsystem: "com.creacom.ccSchwabManager", category: "AppLogger")
    private let logFileURL: URL
    
    private init() {
        // Create log file in Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentsPath.appendingPathComponent("ccSchwabManager.log")
        
        // Create log file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            try? "=== ccSchwabManager Log Started ===\n".write(to: logFileURL, atomically: true, encoding: .utf8)
        }
        
        // Log startup message
        info("=== AppLogger initialized ===")
    }
    
    func log(_ message: String, level: OSLogType = .default) {
        let timestamp = Date().formatted(date: .abbreviated, time: .standard)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Log to OSLog (shows in Console app and Xcode console)
        logger.log(level: level, "\(message)")
        
        // Also print to console for immediate visibility
        print("[\(timestamp)] \(message)")
        
        // Write to file using atomic write (more reliable than file handle)
        do {
            let existingContent = try String(contentsOf: logFileURL, encoding: .utf8)
            let newContent = existingContent + logMessage
            try newContent.write(to: logFileURL, atomically: true, encoding: .utf8)
        } catch {
            // If writing fails, just print to console
            print("Failed to write to log file: \(error)")
        }
    }
    
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    func warning(_ message: String) {
        log(message, level: .error)
    }
    
    func error(_ message: String) {
        log(message, level: .fault)
    }
    
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    // Get the log file contents
    func getLogContents() -> String {
        return (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? "No log file found"
    }
    
    // Clear the log file
    func clearLog() {
        try? "=== Log Cleared ===\n".write(to: logFileURL, atomically: true, encoding: .utf8)
    }
    
    // Get the log file path for monitoring
    func getLogFilePath() -> String {
        return logFileURL.path
    }
} 