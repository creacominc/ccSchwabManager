import Foundation
import os.log

class AppLogger {
    static let shared = AppLogger()
    
    private let logger = Logger(subsystem: "com.creacom.ccSchwabManager", category: "AppLogger")
    private let logFileURL: URL
    private let fileHandle: FileHandle?
    
    private init() {
        // Create log file in Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentsPath.appendingPathComponent("ccSchwabManager.log")
        
        // Create log file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            try? "=== ccSchwabManager Log Started ===\n".write(to: logFileURL, atomically: true, encoding: .utf8)
        }
        
        // Open file handle for writing
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        
        // Seek to end of file
        fileHandle?.seekToEndOfFile()
    }
    
    deinit {
        fileHandle?.closeFile()
    }
    
    func log(_ message: String, level: OSLogType = .default) {
        let timestamp = Date().formatted(date: .abbreviated, time: .standard)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Log to OSLog (shows in Console app)
        logger.log(level: level, "\(message)")
        
        // Also print to console for Xcode debugging
        print(message)
        
        // Write to file
        if let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
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
        fileHandle?.seekToEndOfFile()
    }
} 