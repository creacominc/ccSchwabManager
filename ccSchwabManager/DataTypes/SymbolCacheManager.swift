import Foundation

class SymbolCacheManager: ObservableObject {
    static let shared = SymbolCacheManager()
    
    private var cache: [String: CachedSymbolData] = [:]
    private let cacheQueue = DispatchQueue(label: "com.ccschwab.symbolcache", qos: .userInitiated)
    private let maxCacheAge: TimeInterval = 300 // 5 minutes
    
    struct CachedSymbolData {
        let accountNumber: Int64
        let timestamp: Date
        let positions: [Position]?
        // Add other symbol-specific data here as needed
    }
    
    private init() {}
    
    // MARK: - Account Number Caching
    
    func getCachedAccountNumber(for symbol: String) -> Int64? {
        return cacheQueue.sync {
            guard let cached = cache[symbol],
                  Date().timeIntervalSince(cached.timestamp) < maxCacheAge else {
                return nil
            }
            return cached.accountNumber
        }
    }
    
    func cacheAccountNumber(_ accountNumber: Int64, for symbol: String, positions: [Position]? = nil) {
        cacheQueue.async {
            self.cache[symbol] = CachedSymbolData(
                accountNumber: accountNumber,
                timestamp: Date(),
                positions: positions
            )
        }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cacheQueue.async {
            self.cache.removeAll()
        }
    }
    
    func clearExpiredEntries() {
        cacheQueue.async {
            let now = Date()
            self.cache = self.cache.filter { _, cached in
                now.timeIntervalSince(cached.timestamp) < self.maxCacheAge
            }
        }
    }
    
    func getCacheSize() -> Int {
        return cacheQueue.sync { cache.count }
    }
    
    func getCacheStatus() -> String {
        return cacheQueue.sync {
            let validEntries = cache.filter { _, cached in
                Date().timeIntervalSince(cached.timestamp) < maxCacheAge
            }.count
            return "\(validEntries)/\(cache.count) valid entries"
        }
    }
}

