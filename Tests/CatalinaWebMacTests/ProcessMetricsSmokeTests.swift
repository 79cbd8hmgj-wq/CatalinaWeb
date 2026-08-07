#if os(macOS)
import Darwin
import XCTest
import CatalinaProcessMetrics

final class ProcessMetricsSmokeTests: XCTestCase {
    func testCurrentProcessHasReadableResidentMemory() {
        var metrics = CWProcessFamilyMetrics()

        let result = cw_read_process_family_metrics(Int32(getpid()), &metrics)

        XCTAssertEqual(result, 0)
        XCTAssertEqual(metrics.status, 0)
        XCTAssertGreaterThan(metrics.root_resident_bytes, 0)
    }
}
#endif
