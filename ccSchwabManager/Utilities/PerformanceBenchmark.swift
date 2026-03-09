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
    
    private init() {
        startNewSession()
    }
    
    /// Start a new benchmarking session
    func startNewSession() {
        lock.lock()
        defer { lock.unlock() }
        
        // Log summary of previous session if exists
        if let previousSession = currentSession {
            logSessionSummary(previousSession)
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
}
