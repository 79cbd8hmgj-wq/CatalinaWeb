import XCTest
@testable import CatalinaWebCore

final class WebViewRecoveryStateTests: XCTestCase {
    func testTerminationCapturesWorkspaceAndLastURL() {
        var state = WebViewRecoveryState.healthy
        let url = URL(string: "https://chatgpt.com/c/terminated")!

        state.recordTermination(workspace: .chatGPT, lastURL: url)

        XCTAssertEqual(state, .terminated(workspace: .chatGPT, lastURL: url))
    }

    func testOnlyExplicitReloadReturnsStateToHealthy() {
        var state = WebViewRecoveryState.terminated(
            workspace: .github,
            lastURL: URL(string: "https://github.com/79cbd8hmgj-wq/CatalinaWeb")
        )

        XCTAssertNotEqual(state, .healthy)
        state.requestReload()
        XCTAssertEqual(state, .healthy)
    }

    func testRepeatedTerminationDoesNotIntroduceRetryState() {
        var state = WebViewRecoveryState.healthy
        let first = URL(string: "https://chatgpt.com/c/first")!
        let second = URL(string: "https://chatgpt.com/c/second")!

        state.recordTermination(workspace: .chatGPT, lastURL: first)
        state.recordTermination(workspace: .chatGPT, lastURL: second)

        XCTAssertEqual(state, .terminated(workspace: .chatGPT, lastURL: second))
    }
}
