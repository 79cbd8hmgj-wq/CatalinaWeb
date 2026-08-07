import XCTest
@testable import CatalinaWebCore

final class WorkspaceTests: XCTestCase {
    func testFixedWorkspaceHomeURLsAndOrdering() {
        XCTAssertEqual(Workspace.chatGPT.homeURL.absoluteString, "https://chatgpt.com/")
        XCTAssertEqual(Workspace.github.homeURL.absoluteString, "https://github.com/")
        XCTAssertEqual(Workspace.allCases, [.chatGPT, .github])
    }

    func testInitialPersistedStateContainsOnlyDefaults() {
        let state = PersistedWorkspaceState.initial
        XCTAssertNil(state.lastChatGPTURL)
        XCTAssertNil(state.lastGitHubURL)
        XCTAssertEqual(state.activeWorkspace, .chatGPT)
        XCTAssertNil(state.windowFrame)
    }

    func testLastURLHelpersAddressEachWorkspaceIndependently() {
        var state = PersistedWorkspaceState.initial
        let chatURL = URL(string: "https://chatgpt.com/c/123")!
        let githubURL = URL(string: "https://github.com/example/repo")!

        state.setLastURL(chatURL, for: .chatGPT)
        state.setLastURL(githubURL, for: .github)

        XCTAssertEqual(state.lastURL(for: .chatGPT), chatURL)
        XCTAssertEqual(state.lastURL(for: .github), githubURL)
    }
}
