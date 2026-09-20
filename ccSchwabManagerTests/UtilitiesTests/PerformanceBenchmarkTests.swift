import XCTest
@testable import ccSchwabManager

final class PerformanceBenchmarkTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await PerformanceBenchmark.shared.resetForUnitTests()
    }

    func testRepeatedDataLoadsAreAllExported_notOverwritten() async {
        let symbol = "NVDA"
        await PerformanceBenchmark.shared.recordDataLoad(symbol: symbol, group: .taxLots, duration: 1.0, fromCache: false)
        await PerformanceBenchmark.shared.recordDataLoad(symbol: symbol, group: .taxLots, duration: 2.0, fromCache: false)
        await PerformanceBenchmark.shared.recordDataLoad(symbol: symbol, group: .taxLots, duration: 3.0, fromCache: false)

        guard let exportData = await PerformanceBenchmark.shared.exportSessionData(),
              let export = try? JSONSerialization.jsonObject(with: exportData) as? [String: Any] else {
            XCTFail("exportSessionData returned nil")
            return
        }

        let events = export["dataLoadEvents"] as? [[String: Any]]
        XCTAssertNotNil(events)
        XCTAssertEqual(events?.count, 3, "All three loads must appear; previously the dict overwrote earlier entries.")

        let grouped = export["dataLoads"] as? [String: Any]
        XCTAssertNotNil(grouped)
        let key = "\(symbol)_taxLots"
        let bucket = grouped?[key] as? [[String: Any]]
        XCTAssertEqual(bucket?.count, 3)

        let durations = bucket?.compactMap { $0["duration"] as? Double }.sorted()
        XCTAssertEqual(durations, [1.0, 2.0, 3.0])
    }

    func testEndTimingForLoadOperationAppendsEvents() async {
        await PerformanceBenchmark.shared.startTiming("load_taxLots_AAPL", metadata: ["symbol": "AAPL", "group": "taxLots"])
        _ = await PerformanceBenchmark.shared.endTiming("load_taxLots_AAPL")
        await PerformanceBenchmark.shared.startTiming("load_taxLots_AAPL", metadata: ["symbol": "AAPL", "group": "taxLots"])
        _ = await PerformanceBenchmark.shared.endTiming("load_taxLots_AAPL")

        guard let exportData = await PerformanceBenchmark.shared.exportSessionData(),
              let export = try? JSONSerialization.jsonObject(with: exportData) as? [String: Any],
              let events = export["dataLoadEvents"] as? [[String: Any]] else {
            XCTFail("Missing dataLoadEvents")
            return
        }
        XCTAssertEqual(events.count, 2)
    }

    func testRecordNetworkRequestAppearsInExport() async {
        await PerformanceBenchmark.shared.recordNetworkRequest(operation: "fetch_quotes_batch", duration: 0.42, metadata: ["count": "5"])

        guard let exportData = await PerformanceBenchmark.shared.exportSessionData(),
              let export = try? JSONSerialization.jsonObject(with: exportData) as? [String: Any],
              let nets = export["networkRequests"] as? [[String: Any]] else {
            XCTFail("networkRequests missing")
            return
        }
        XCTAssertEqual(nets.count, 1)
        XCTAssertEqual(nets.first?["operation"] as? String, "fetch_quotes_batch")
        let duration = nets.first?["duration"] as? Double
        XCTAssertEqual(duration ?? -1, 0.42, accuracy: 0.001)
    }
}
