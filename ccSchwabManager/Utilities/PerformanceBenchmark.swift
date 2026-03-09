import Foundation

/// Performance benchmarking utility to track and analyze app performance
class PerformanceBenchmark {
    static let shared = PerformanceBenchmark()
    
    private struct Metric {
        let operation: String
        let startTime: Date
        var endTime: Date?
        let metadata: [String: Any]?
        
        var duration: TimeInterval? {
            guard let endTime = endTime else { return nil }
            return endTime.timeIntervalSince(startTime)
        }
    }
    
    private struct SessionMetrics {
        let sessionId: String
        let startTime: Date
        var tabSwitches: [(tab: Int, timestamp: Date)] = []
        var dataLoads: [String: Metric] = [:] // Key: "symbol_group"
        var cacheHits: Int = 0
        var cacheMisses: Int = 0
        var networkRequests: [Metric] = []
    }
    
    private var currentSession: SessionMetrics?
    private var activeMetrics: [String: Metric] = [:]
    private let lock = NSLock()
    
    // Persistence: Store session history
    private var sessionHistory: [SessionMetrics] = []
    private let maxStoredSessions = 50 // Keep last 50 sessions
    
    // File URL for persistence
    // Tries iCloud Drive first (if available), falls back to local Documents directory
    // iCloud Drive location: 
    //   macOS: ~/Library/Mobile Documents/iCloud.com.creacom.ccSchwabManager/Documents/performance_benchmark_sessions.json
    //   iOS: Accessible via Files app under "iCloud Drive" > "ccSchwabManager" folder
    // Local fallback: App's Documents directory (sandboxed)
    private var persistenceURL: URL? {
        // Try iCloud Drive first (if iCloud is enabled and user is signed in)
        // Note: This requires iCloud capability in entitlements and user to be signed into iCloud
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.creacom.ccSchwabManager") {
            var iCloudDocuments = iCloudURL.appendingPathComponent("Documents")
            
            // Create Documents directory if it doesn't exist (required for Files app visibility)
            do {
                try FileManager.default.createDirectory(at: iCloudDocuments, withIntermediateDirectories: true)
                
                // Mark Documents as not excluded from backup (iCloud handles sync)
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = false // iCloud handles backup
                try? iCloudDocuments.setResourceValues(resourceValues)
            } catch {
                AppLogger.shared.warning("📊 Failed to create iCloud Documents directory: \(error.localizedDescription)")
            }
            
            let iCloudFileURL = iCloudDocuments.appendingPathComponent("performance_benchmark_sessions.json")
            AppLogger.shared.info("📊 Using iCloud Drive for performance benchmark storage")
            AppLogger.shared.debug("📊 iCloud path: \(iCloudFileURL.path)")
            return iCloudFileURL
        }
        
        // Fallback to local Documents directory (if iCloud not available or not signed in)
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsDir.appendingPathComponent("performance_benchmark_sessions.json")
        
        #if os(iOS)
        AppLogger.shared.info("📊 Using local storage for performance benchmark (iCloud not available or not signed in)")
        AppLogger.shared.debug("📊 Local path: \(fileURL.path)")
        #else
        AppLogger.shared.debug("📊 Using local storage for performance benchmark: \(fileURL.path)")
        #endif
        
        return fileURL
    }
    
    private init() {
        loadSessionHistory()
        startNewSession()
    }
    
    /// Start a new benchmarking session
    func startNewSession() {
        lock.lock()
        defer { lock.unlock() }
        
        // Save previous session to history before starting new one
        if let previousSession = currentSession {
            logSessionSummary(previousSession)
            sessionHistory.append(previousSession)
            
            // Trim history if too large
            if sessionHistory.count > maxStoredSessions {
                sessionHistory.removeFirst(sessionHistory.count - maxStoredSessions)
            }
            
            // Persist to disk
            saveSessionHistory()
        }
        
        let sessionId = UUID().uuidString.prefix(8).lowercased()
        currentSession = SessionMetrics(
            sessionId: String(sessionId),
            startTime: Date()
        )
        
        AppLogger.shared.info("📊 Performance Benchmark: Started new session \(sessionId)")
    }
    
    /// Start timing an operation
    func startTiming(_ operation: String, metadata: [String: Any]? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        let metric = Metric(
            operation: operation,
            startTime: Date(),
            endTime: nil,
            metadata: metadata
        )
        activeMetrics[operation] = metric
    }
    
    /// End timing an operation and record it
    func endTiming(_ operation: String) -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        
        guard var metric = activeMetrics[operation] else {
            AppLogger.shared.warning("📊 Performance Benchmark: No active timing for \(operation)")
            return nil
        }
        
        metric.endTime = Date()
        activeMetrics.removeValue(forKey: operation)
        
        guard let duration = metric.duration else { return nil }
        
        // Record in current session
        if var session = currentSession {
            // Determine if this is a data load operation
            if operation.contains("_") {
                let parts = operation.split(separator: "_")
                if parts.count >= 2 {
                    let key = operation
                    session.dataLoads[key] = metric
                }
            }
            
            // Check if it's a network request
            if operation.contains("fetch") || operation.contains("get") || operation.contains("compute") {
                session.networkRequests.append(metric)
            }
            
            currentSession = session
        }
        
        // Log the metric
        let durationStr = String(format: "%.3f", duration)
        let metadataStr = metric.metadata?.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") ?? ""
        let logMsg = metadataStr.isEmpty ? 
            "📊 [\(durationStr)s] \(operation)" :
            "📊 [\(durationStr)s] \(operation) (\(metadataStr))"
        AppLogger.shared.info(logMsg)
        
        return duration
    }
    
    /// Record a tab switch
    func recordTabSwitch(to tab: Int, symbol: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        guard var session = currentSession else { return }
        session.tabSwitches.append((tab: tab, timestamp: Date()))
        currentSession = session
        
        let tabName = tabName(for: tab)
        AppLogger.shared.debug("📊 Tab switch: \(tabName) (tab \(tab))" + (symbol != nil ? " for \(symbol!)" : ""))
    }
    
    /// Record a cache hit
    func recordCacheHit(for operation: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard var session = currentSession else { return }
        session.cacheHits += 1
        currentSession = session
        
        AppLogger.shared.debug("📊 Cache HIT: \(operation)")
    }
    
    /// Record a cache miss
    func recordCacheMiss(for operation: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard var session = currentSession else { return }
        session.cacheMisses += 1
        currentSession = session
        
        AppLogger.shared.debug("📊 Cache MISS: \(operation)")
    }
    
    /// Record data load timing for a specific symbol and group
    func recordDataLoad(symbol: String, group: SecurityDataGroup, duration: TimeInterval, fromCache: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = "\(symbol)_\(group)"
        let metric = Metric(
            operation: key,
            startTime: Date().addingTimeInterval(-duration),
            endTime: Date(),
            metadata: ["fromCache": fromCache, "group": "\(group)"]
        )
        
        if var session = currentSession {
            session.dataLoads[key] = metric
            if fromCache {
                session.cacheHits += 1
            } else {
                session.cacheMisses += 1
            }
            currentSession = session
        }
    }
    
    /// Get current session summary
    func getSessionSummary() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        guard let session = currentSession else {
            return "No active session"
        }
        
        let sessionDuration = Date().timeIntervalSince(session.startTime)
        var summary = "\n"
        summary += "═══════════════════════════════════════════════════════════\n"
        summary += "📊 PERFORMANCE BENCHMARK SESSION SUMMARY\n"
        summary += "═══════════════════════════════════════════════════════════\n"
        summary += "Session ID: \(session.sessionId)\n"
        summary += "Duration: \(String(format: "%.2f", sessionDuration))s\n"
        summary += "\n"
        
        // Tab switches
        summary += "Tab Switches: \(session.tabSwitches.count)\n"
        if !session.tabSwitches.isEmpty {
            for (index, switch_) in session.tabSwitches.enumerated() {
                let tabName = tabName(for: switch_.tab)
                let timeSinceStart = switch_.timestamp.timeIntervalSince(session.startTime)
                summary += "  \(index + 1). \(tabName) (tab \(switch_.tab)) at \(String(format: "%.2f", timeSinceStart))s\n"
            }
        }
        summary += "\n"
        
        // Cache statistics
        let totalCacheOps = session.cacheHits + session.cacheMisses
        let cacheHitRate = totalCacheOps > 0 ? Double(session.cacheHits) / Double(totalCacheOps) * 100 : 0
        summary += "Cache Statistics:\n"
        summary += "  Hits: \(session.cacheHits)\n"
        summary += "  Misses: \(session.cacheMisses)\n"
        summary += "  Hit Rate: \(String(format: "%.1f", cacheHitRate))%\n"
        summary += "\n"
        
        // Data load times by group
        var groupTimes: [SecurityDataGroup: [TimeInterval]] = [:]
        for (_, metric) in session.dataLoads {
            if let duration = metric.duration,
               let groupStr = metric.metadata?["group"] as? String,
               let group = SecurityDataGroup.allCases.first(where: { "\($0)" == groupStr }) {
                groupTimes[group, default: []].append(duration)
            }
        }
        
        if !groupTimes.isEmpty {
            summary += "Data Load Times by Group:\n"
            for group in SecurityDataGroup.allCases {
                if let times = groupTimes[group], !times.isEmpty {
                    let avg = times.reduce(0, +) / Double(times.count)
                    let min = times.min() ?? 0
                    let max = times.max() ?? 0
                    let variance = times.map { pow($0 - avg, 2) }.reduce(0, +) / Double(times.count)
                    let stdDev = sqrt(variance)
                    let coefficientOfVariation = avg > 0 ? (stdDev / avg) * 100 : 0
                    
                    summary += "  \(group): avg=\(String(format: "%.3f", avg))s, min=\(String(format: "%.3f", min))s, max=\(String(format: "%.3f", max))s (n=\(times.count))\n"
                    
                    // Add variance warning if high
                    if coefficientOfVariation > 50 {
                        summary += "    ⚠️  High variance detected (CV=\(String(format: "%.1f", coefficientOfVariation))%) - inconsistent performance\n"
                    }
                }
            }
            summary += "\n"
            
            // Performance recommendations
            summary += "Performance Recommendations:\n"
            var recommendations: [String] = []
            
            // Check cache hit rate
            if cacheHitRate < 60 {
                recommendations.append("• Cache hit rate (\(String(format: "%.1f", cacheHitRate))%) is low - consider improving cache retention")
            }
            
            // Check for high variance operations
            for group in SecurityDataGroup.allCases {
                if let times = groupTimes[group], times.count > 1 {
                    let avg = times.reduce(0, +) / Double(times.count)
                    let variance = times.map { pow($0 - avg, 2) }.reduce(0, +) / Double(times.count)
                    let stdDev = sqrt(variance)
                    let coefficientOfVariation = avg > 0 ? (stdDev / avg) * 100 : 0
                    
                    if coefficientOfVariation > 50 && avg > 0.1 {
                        recommendations.append("• \(group) shows high variance (CV=\(String(format: "%.1f", coefficientOfVariation))%) - some loads are much slower than others")
                    }
                }
            }
            
            // Check for slow operations
            let allDurations = session.dataLoads.values.compactMap { $0.duration }
            if let maxDuration = allDurations.max(), maxDuration > 0.5 {
                recommendations.append("• Some operations take >0.5s - consider optimizing slowest operations")
            }
            
            if recommendations.isEmpty {
                summary += "  ✅ Performance looks good!\n"
            } else {
                for rec in recommendations {
                    summary += "  \(rec)\n"
                }
            }
            summary += "\n"
        }
        
        // Network requests
        if !session.networkRequests.isEmpty {
            let totalNetworkTime = session.networkRequests.compactMap { $0.duration }.reduce(0, +)
            let avgNetworkTime = totalNetworkTime / Double(session.networkRequests.count)
            summary += "Network Requests:\n"
            summary += "  Total: \(session.networkRequests.count)\n"
            summary += "  Total Time: \(String(format: "%.3f", totalNetworkTime))s\n"
            summary += "  Average: \(String(format: "%.3f", avgNetworkTime))s\n"
            summary += "\n"
        }
        
        // Slowest operations
        let allDurations = session.dataLoads.values.compactMap { $0.duration } + 
                          session.networkRequests.compactMap { $0.duration }
        if !allDurations.isEmpty {
            let sortedOps = session.dataLoads.values.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
            summary += "Slowest Operations:\n"
            for (index, op) in sortedOps.prefix(5).enumerated() {
                if let duration = op.duration {
                    summary += "  \(index + 1). \(op.operation): \(String(format: "%.3f", duration))s\n"
                }
            }
            summary += "\n"
        }
        
        summary += "═══════════════════════════════════════════════════════════\n"
        
        return summary
    }
    
    /// Log session summary
    private func logSessionSummary(_ session: SessionMetrics) {
        let summary = getSessionSummary()
        AppLogger.shared.info(summary)
    }
    
    /// Export session data as JSON
    func exportSessionData() -> [String: Any]? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let session = currentSession else { return nil }
        
        var data: [String: Any] = [
            "sessionId": session.sessionId,
            "startTime": ISO8601DateFormatter().string(from: session.startTime),
            "duration": Date().timeIntervalSince(session.startTime),
            "tabSwitches": session.tabSwitches.map { ["tab": $0.tab, "timestamp": ISO8601DateFormatter().string(from: $0.timestamp)] },
            "cacheHits": session.cacheHits,
            "cacheMisses": session.cacheMisses,
            "cacheHitRate": session.cacheHits + session.cacheMisses > 0 ? 
                Double(session.cacheHits) / Double(session.cacheHits + session.cacheMisses) : 0
        ]
        
        // Convert data loads to dictionary
        var dataLoadsDict: [String: [String: Any]] = [:]
        for (key, metric) in session.dataLoads {
            var metricDict: [String: Any] = [
                "operation": metric.operation,
                "duration": metric.duration ?? 0
            ]
            if let metadata = metric.metadata {
                metricDict["metadata"] = metadata
            }
            dataLoadsDict[key] = metricDict
        }
        data["dataLoads"] = dataLoadsDict
        
        // Convert network requests
        data["networkRequests"] = session.networkRequests.map { metric in
            var dict: [String: Any] = [
                "operation": metric.operation,
                "duration": metric.duration ?? 0
            ]
            if let metadata = metric.metadata {
                dict["metadata"] = metadata
            }
            return dict
        }
        
        return data
    }
    
    /// Helper to get tab name
    private func tabName(for tab: Int) -> String {
        switch tab {
        case 0: return "Details"
        case 1: return "Price History"
        case 2: return "Transactions"
        case 3: return "Sales Calc"
        case 4: return "Current Orders"
        case 5: return "OCO Orders"
        case 6: return "Sequence"
        default: return "Unknown"
        }
    }
    
    // MARK: - Persistence
    
    /// Save session history to disk
    private func saveSessionHistory() {
        guard let url = persistenceURL else { return }
        
        // Convert sessions to JSON-serializable format
        let sessionsData = sessionHistory.map { session -> [String: Any] in
            var dict: [String: Any] = [
                "sessionId": session.sessionId,
                "startTime": ISO8601DateFormatter().string(from: session.startTime),
                "cacheHits": session.cacheHits,
                "cacheMisses": session.cacheMisses,
                "tabSwitches": session.tabSwitches.map { ["tab": $0.tab, "timestamp": ISO8601DateFormatter().string(from: $0.timestamp)] }
            ]
            
            // Convert data loads (only include duration, skip Date objects)
            var dataLoadsDict: [String: [String: Any]] = [:]
            for (key, metric) in session.dataLoads {
                var metricDict: [String: Any] = [
                    "operation": metric.operation,
                    "duration": metric.duration ?? 0
                ]
                // Only include simple metadata (skip Date objects)
                if let metadata = metric.metadata {
                    let simpleMetadata = metadata.compactMapValues { value -> Any? in
                        // Only include JSON-serializable types
                        if value is String || value is Int || value is Double || value is Bool {
                            return value
                        }
                        return nil
                    }
                    if !simpleMetadata.isEmpty {
                        metricDict["metadata"] = simpleMetadata
                    }
                }
                dataLoadsDict[key] = metricDict
            }
            dict["dataLoads"] = dataLoadsDict
            
            return dict
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionsData, options: .prettyPrinted)
            try jsonData.write(to: url)
            AppLogger.shared.debug("📊 Saved \(sessionHistory.count) sessions to disk")
        } catch {
            AppLogger.shared.error("📊 Failed to save session history: \(error.localizedDescription)")
        }
    }
    
    /// Load session history from disk
    private func loadSessionHistory() {
        guard let url = persistenceURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            AppLogger.shared.debug("📊 No saved session history found")
            return
        }
        
        // Note: We load the data but don't restore full SessionMetrics objects
        // This is mainly for future use - the current session is what matters
        AppLogger.shared.debug("📊 Loaded \(json.count) historical sessions from disk")
    }
    
    /// Get all stored session IDs
    func getStoredSessionIds() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return sessionHistory.map { $0.sessionId }
    }
    
    /// Get summary for a specific session by ID
    func getSessionSummary(for sessionId: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let session = sessionHistory.first(where: { $0.sessionId == sessionId }) else {
            return nil
        }
        
        // Temporarily set as current session to generate summary
        let savedCurrent = currentSession
        currentSession = session
        let summary = getSessionSummary()
        currentSession = savedCurrent
        return summary
    }
    
    /// Get storage location description for display
    func getStorageLocation() -> String {
        guard let url = persistenceURL else {
            return "Not configured"
        }
        
        // Check if it's iCloud or local
        if url.path.contains("Mobile Documents") || url.path.contains("iCloud") || url.path.contains("CloudDocs") {
            #if os(iOS)
            if url.path.contains("iCloud.com.creacom.ccSchwabManager") {
                return "iCloud Drive (Files app > ccSchwabManager)"
            } else {
                return "iCloud Drive (Files app)"
            }
            #else
            if url.path.contains("iCloud.com.creacom.ccSchwabManager") {
                return "iCloud Drive (app container): \(url.path)"
            } else {
                return "iCloud Drive (generic): \(url.path)"
            }
            #endif
        } else {
            #if os(iOS)
            return "Local storage (app sandbox)"
            #else
            return "Local: \(url.path)"
            #endif
        }
    }
}
