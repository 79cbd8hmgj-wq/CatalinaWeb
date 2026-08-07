#if os(macOS)
import XCTest
@testable import CatalinaWebApp
@testable import CatalinaWebCore

final class DiagnosticsCollectorTests: XCTestCase {
    func testSnapshotUsesOnlyMetricsReturnedByStrictProcessReader() {
        let pressure = FakeMemoryPressureReader(level: .warning)
        let reader = FakeProcessMetricsReader(
            measurement: ProcessFamilyMeasurement(
                rootResidentBytes: 123,
                attributableChildProcessCount: 2,
                attributableFamilyResidentBytes: 456
            )
        )
        let collector = DiagnosticsCollector(
            contextProvider: { (.github, 1) },
            processMetricsReader: reader,
            memoryPressureReader: pressure
        )

        let snapshot = collector.currentSnapshot()

        XCTAssertEqual(snapshot.activeWorkspace, .github)
        XCTAssertEqual(snapshot.liveWebViewCount, 1)
        XCTAssertEqual(snapshot.appResidentBytes, 123)
        XCTAssertEqual(snapshot.attributableChildProcessCount, 2)
        XCTAssertEqual(snapshot.attributableFamilyResidentBytes, 456)
        XCTAssertEqual(snapshot.memoryPressure, .warning)
    }

    func testUnavailableDescendantMetricsStayUnavailable() {
        let reader = FakeProcessMetricsReader(
            measurement: ProcessFamilyMeasurement(
                rootResidentBytes: 789,
                attributableChildProcessCount: nil,
                attributableFamilyResidentBytes: nil
            )
        )
        let collector = DiagnosticsCollector(
            contextProvider: { (.chatGPT, 1) },
            processMetricsReader: reader,
            memoryPressureReader: FakeMemoryPressureReader(level: .normal)
        )

        let snapshot = collector.currentSnapshot()

        XCTAssertEqual(snapshot.appResidentBytes, 789)
        XCTAssertNil(snapshot.attributableChildProcessCount)
        XCTAssertNil(snapshot.attributableFamilyResidentBytes)
    }

    func testBrowserEventBufferKeepsOnlyMostRecentTwoHundredEvents() {
        let collector = DiagnosticsCollector(
            contextProvider: { (.chatGPT, 1) },
            processMetricsReader: FakeProcessMetricsReader(measurement: .unavailable),
            memoryPressureReader: FakeMemoryPressureReader(level: .normal)
        )

        for index in 0..<205 {
            let url = URL(string: "https://chatgpt.com/c/\(index)")!
            collector.record(.navigationCommitted(url: url, workspace: .chatGPT))
        }

        let events = collector.recentEvents()
        XCTAssertEqual(events.count, 200)
        XCTAssertEqual(
            events.first,
            .navigationCommitted(url: URL(string: "https://chatgpt.com/c/5")!, workspace: .chatGPT)
        )
    }
}

private final class FakeProcessMetricsReader: ProcessFamilyMetricsReading {
    let measurement: ProcessFamilyMeasurement

    init(measurement: ProcessFamilyMeasurement) {
        self.measurement = measurement
    }

    func readCurrentProcessFamily() -> ProcessFamilyMeasurement {
        measurement
    }
}

private final class FakeMemoryPressureReader: MemoryPressureReading {
    var currentLevel: MemoryPressureLevel

    init(level: MemoryPressureLevel) {
        self.currentLevel = level
    }

    func start() {}
    func stop() {}
}
#endif
