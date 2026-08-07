import XCTest
@testable import CatalinaWebCore

final class DiagnosticsModelsTests: XCTestCase {
    func testUnavailableOptionalMetricsRemainNilAndFormatAsUnavailable() {
        let snapshot = DiagnosticsSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            activeWorkspace: .chatGPT,
            liveWebViewCount: 1,
            appResidentBytes: nil,
            attributableChildProcessCount: nil,
            attributableFamilyResidentBytes: nil,
            memoryPressure: .normal
        )

        XCTAssertNil(snapshot.appResidentBytes)
        XCTAssertNil(snapshot.attributableChildProcessCount)
        XCTAssertNil(snapshot.attributableFamilyResidentBytes)
        XCTAssertEqual(DiagnosticsFormatter.bytes(snapshot.appResidentBytes), "Unavailable")
        XCTAssertEqual(DiagnosticsFormatter.processCount(snapshot.attributableChildProcessCount), "Unavailable")
        XCTAssertEqual(DiagnosticsFormatter.bytes(snapshot.attributableFamilyResidentBytes), "Unavailable")
    }

    func testAvailableMetricsNeverFormatAsUnavailableOrZeroWhenNonzero() {
        XCTAssertEqual(DiagnosticsFormatter.bytes(1_073_741_824), "1.00 GB")
        XCTAssertEqual(DiagnosticsFormatter.bytes(1_048_576), "1.00 MB")
        XCTAssertEqual(DiagnosticsFormatter.processCount(3), "3")
    }

    func testMemoryPressureLabelsAreStable() {
        XCTAssertEqual(MemoryPressureLevel.normal.displayName, "Normal")
        XCTAssertEqual(MemoryPressureLevel.warning.displayName, "Warning")
        XCTAssertEqual(MemoryPressureLevel.critical.displayName, "Critical")
    }
}
