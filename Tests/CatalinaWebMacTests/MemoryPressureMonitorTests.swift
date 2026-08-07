#if os(macOS)
import XCTest
@testable import CatalinaWebApp
@testable import CatalinaWebCore

final class MemoryPressureMonitorTests: XCTestCase {
    func testRecordedPressureUpdatesCurrentLevelWithoutMutatingWebContent() {
        var observed: [MemoryPressureLevel] = []
        let monitor = MemoryPressureMonitor(
            normalResetDelay: 60,
            onLevelChange: { observed.append($0) }
        )

        monitor.recordForTesting(.warning)
        monitor.recordForTesting(.critical)

        XCTAssertEqual(monitor.currentLevel, .critical)
        XCTAssertEqual(observed, [.warning, .critical])
    }
}
#endif
