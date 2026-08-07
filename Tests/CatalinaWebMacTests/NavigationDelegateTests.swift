#if os(macOS)
import WebKit
import XCTest
@testable import CatalinaWebApp
@testable import CatalinaWebCore

final class NavigationDelegateTests: XCTestCase {
    func testSameWorkspaceTopLevelURLIsAllowed() {
        let harness = makeHarness(workspace: .chatGPT)
        let decision = harness.delegate.decisionForTesting(
            destinationURL: URL(string: "https://chatgpt.com/c/123")!,
            sourceURL: URL(string: "https://chatgpt.com/")!,
            isMainFrame: true,
            isUserInitiated: true
        )

        XCTAssertEqual(decision, .allow)
        XCTAssertTrue(harness.opener.urls.isEmpty)
        XCTAssertTrue(harness.events.events.isEmpty)
    }

    func testUnrelatedTopLevelURLOpensExternallyAndCancelsWebKitNavigation() {
        let harness = makeHarness(workspace: .chatGPT)
        let url = URL(string: "https://example.com/docs")!

        let decision = harness.delegate.decisionForTesting(
            destinationURL: url,
            sourceURL: URL(string: "https://chatgpt.com/")!,
            isMainFrame: true,
            isUserInitiated: true
        )

        XCTAssertEqual(decision, .cancel)
        XCTAssertEqual(harness.opener.urls, [url])
        XCTAssertEqual(harness.events.events, [.externalNavigationBlocked(url: url, workspace: .chatGPT)])
    }

    func testCrossWorkspaceLinksOpenInOrionInsteadOfSwitchingWorkspaces() {
        let chatHarness = makeHarness(workspace: .chatGPT)
        let githubURL = URL(string: "https://github.com/79cbd8hmgj-wq/CatalinaWeb")!
        XCTAssertEqual(
            chatHarness.delegate.decisionForTesting(
                destinationURL: githubURL,
                sourceURL: Workspace.chatGPT.homeURL,
                isMainFrame: true,
                isUserInitiated: true
            ),
            .cancel
        )
        XCTAssertEqual(chatHarness.opener.urls, [githubURL])

        let githubHarness = makeHarness(workspace: .github)
        let chatURL = URL(string: "https://chatgpt.com/")!
        XCTAssertEqual(
            githubHarness.delegate.decisionForTesting(
                destinationURL: chatURL,
                sourceURL: Workspace.github.homeURL,
                isMainFrame: true,
                isUserInitiated: true
            ),
            .cancel
        )
        XCTAssertEqual(githubHarness.opener.urls, [chatURL])
    }

    func testCommittedURLPersistsExactlyForActiveWorkspace() {
        let harness = makeHarness(workspace: .github)
        let url = URL(string: "https://github.com/79cbd8hmgj-wq/CatalinaWeb/pulls?q=is%3Apr")!

        harness.delegate.commitForTesting(url: url)

        XCTAssertEqual(harness.store.state.lastGitHubURL, url)
        XCTAssertEqual(harness.committedURLs, [url])
        XCTAssertEqual(harness.events.events, [.navigationCommitted(url: url, workspace: .github)])
    }

    func testNavigationFailureRecordsNSErrorWithoutChangingPolicy() {
        let harness = makeHarness(workspace: .chatGPT)
        let url = URL(string: "https://chatgpt.com/")!
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSLocalizedDescriptionKey: "Timed out"])

        harness.delegate.recordFailureForTesting(url: url, error: error)

        XCTAssertEqual(
            harness.events.events,
            [.navigationFailed(url: url, code: NSURLErrorTimedOut, description: "Timed out")]
        )
    }

    private func makeHarness(workspace: Workspace) -> Harness {
        let opener = RecordingExternalBrowserOpener()
        let store = RecordingNavigationStateStore(state: .initial)
        let events = RecordingBrowserEventRecorder()
        var committedURLs: [URL] = []
        let delegate = WebViewNavigationDelegate(
            workspace: workspace,
            policy: NavigationPolicy(),
            externalOpener: opener,
            stateStore: store,
            eventRecorder: events,
            onCommittedURL: { committedURLs.append($0) }
        )
        return Harness(
            delegate: delegate,
            opener: opener,
            store: store,
            events: events,
            committedURLsProvider: { committedURLs }
        )
    }
}

private struct Harness {
    let delegate: WebViewNavigationDelegate
    let opener: RecordingExternalBrowserOpener
    let store: RecordingNavigationStateStore
    let events: RecordingBrowserEventRecorder
    let committedURLsProvider: () -> [URL]

    var committedURLs: [URL] { committedURLsProvider() }
}

private final class RecordingExternalBrowserOpener: ExternalBrowserOpening {
    var urls: [URL] = []
    func openExternally(_ url: URL) { urls.append(url) }
}

private final class RecordingNavigationStateStore: WorkspaceStateStoring {
    var state: PersistedWorkspaceState
    init(state: PersistedWorkspaceState) { self.state = state }
    func load() -> PersistedWorkspaceState { state }
    func save(_ state: PersistedWorkspaceState) { self.state = state }
}

private final class RecordingBrowserEventRecorder: BrowserEventRecording {
    var events: [BrowserEvent] = []
    func record(_ event: BrowserEvent) { events.append(event) }
}
#endif
