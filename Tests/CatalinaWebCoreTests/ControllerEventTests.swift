import XCTest
@testable import CatalinaWebCore

final class ControllerEventTests: XCTestCase {
    func testControllerEventsPreserveOnlyApprovedAssociatedValues() {
        XCTAssertEqual(
            ControllerEvent.workspaceSwitched(from: .chatGPT, to: .github),
            .workspaceSwitched(from: .chatGPT, to: .github)
        )
        XCTAssertEqual(
            ControllerEvent.orionWindowConnected(pid: 123),
            .orionWindowConnected(pid: 123)
        )
        XCTAssertEqual(
            ControllerEvent.externalNavigationRerouted(host: "example.com", workspace: .chatGPT),
            .externalNavigationRerouted(host: "example.com", workspace: .chatGPT)
        )
        XCTAssertEqual(
            ControllerEvent.setupStageChanged(.profileVerified),
            .setupStageChanged(.profileVerified)
        )
    }

    func testNullRecorderAcceptsEveryEventWithoutSideEffects() {
        let recorder = NullControllerEventRecorder()

        recorder.record(.orionWindowDisconnected)
        recorder.record(.automationFailed(operation: "navigate", description: "failed"))
    }
}
