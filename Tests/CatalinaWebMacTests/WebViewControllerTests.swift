#if os(macOS)
import AppKit
import WebKit
import XCTest
@testable import CatalinaWebApp
@testable import CatalinaWebCore

final class WebViewControllerTests: XCTestCase {
    func testStartCreatesExactlyOnePersistentWebView() {
        let store = RecordingWorkspaceStateStore(state: .initial)
        let builder = RecordingWebViewBuilder()
        let controller = WebViewController(stateStore: store, webViewBuilder: builder)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        controller.start(in: container, workspace: .chatGPT)

        XCTAssertEqual(controller.liveWebViewCount, 1)
        XCTAssertEqual(builder.createdViews.count, 1)
        XCTAssertTrue(builder.configurations[0].websiteDataStore === WKWebsiteDataStore.default())
        XCTAssertTrue(controller.currentWebView === builder.createdViews[0])
    }

    func testChatGPTWebViewUsesExactObservedOrionUserAgent() {
        let store = RecordingWorkspaceStateStore(state: .initial)
        let builder = RecordingWebViewBuilder()
        let controller = WebViewController(stateStore: store, webViewBuilder: builder)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        controller.start(in: container, workspace: .chatGPT)

        XCTAssertEqual(
            builder.createdViews[0].customUserAgent,
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
        )
    }

    func testGitHubWebViewKeepsDefaultUserAgent() {
        var initial = PersistedWorkspaceState.initial
        initial.activeWorkspace = .github
        let store = RecordingWorkspaceStateStore(state: initial)
        let builder = RecordingWebViewBuilder()
        let controller = WebViewController(stateStore: store, webViewBuilder: builder)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        controller.start(in: container, workspace: .github)

        XCTAssertNil(builder.createdViews[0].customUserAgent)
    }

    func testSwitchPersistsCurrentURLBeforeTeardownAndRestoresDestinationURL() {
        let githubURL = URL(string: "https://github.com/79cbd8hmgj-wq/CatalinaWeb/issues")!
        var initial = PersistedWorkspaceState.initial
        initial.lastGitHubURL = githubURL
        let store = RecordingWorkspaceStateStore(state: initial)
        let builder = RecordingWebViewBuilder()
        let controller = WebViewController(stateStore: store, webViewBuilder: builder)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        controller.start(in: container, workspace: .chatGPT)
        let oldView = builder.createdViews[0]
        let chatURL = URL(string: "https://chatgpt.com/c/abc123")!
        oldView.load(URLRequest(url: chatURL))

        controller.currentCommittedURL = chatURL
        controller.switchWorkspace(to: .github)

        XCTAssertEqual(store.state.lastChatGPTURL, chatURL)
        XCTAssertEqual(store.state.activeWorkspace, .github)
        XCTAssertEqual(controller.liveWebViewCount, 1)
        XCTAssertNil(oldView.navigationDelegate)
        XCTAssertNil(oldView.uiDelegate)
        XCTAssertNil(oldView.superview)
        XCTAssertFalse(controller.currentWebView === oldView)
        XCTAssertEqual(builder.requestedURLs.last, githubURL)
    }

    func testDestinationFallsBackToWorkspaceHomeWhenNoSavedURLExists() {
        let store = RecordingWorkspaceStateStore(state: .initial)
        let builder = RecordingWebViewBuilder()
        let controller = WebViewController(stateStore: store, webViewBuilder: builder)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        controller.start(in: container, workspace: .chatGPT)
        controller.switchWorkspace(to: .github)

        XCTAssertEqual(builder.requestedURLs.last, Workspace.github.homeURL)
    }

    func testSwitchingToAlreadyActiveWorkspaceDoesNotCreateAnotherView() {
        let store = RecordingWorkspaceStateStore(state: .initial)
        let builder = RecordingWebViewBuilder()
        let controller = WebViewController(stateStore: store, webViewBuilder: builder)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        controller.start(in: container, workspace: .chatGPT)
        controller.switchWorkspace(to: .chatGPT)

        XCTAssertEqual(builder.createdViews.count, 1)
        XCTAssertEqual(controller.liveWebViewCount, 1)
    }

    func testProcessTerminationRemovesDeadViewAndWaitsForExplicitReload() {
        let store = RecordingWorkspaceStateStore(state: .initial)
        let builder = RecordingWebViewBuilder()
        let controller = WebViewController(stateStore: store, webViewBuilder: builder)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        controller.start(in: container, workspace: .chatGPT)
        let url = URL(string: "https://chatgpt.com/c/failure")!
        controller.currentCommittedURL = url
        controller.handleWebContentProcessTerminationForTesting()

        XCTAssertEqual(controller.liveWebViewCount, 0)
        XCTAssertEqual(controller.recoveryState, .terminated(workspace: .chatGPT, lastURL: url))
        XCTAssertEqual(builder.createdViews.count, 1, "Termination must not auto-create a replacement view")

        controller.recreateCurrentWorkspaceAfterFailure()

        XCTAssertEqual(controller.recoveryState, .healthy)
        XCTAssertEqual(controller.liveWebViewCount, 1)
        XCTAssertEqual(builder.createdViews.count, 2)
        XCTAssertEqual(builder.requestedURLs.last, url)
    }

    func testSwitchingAwayAfterTerminationPreservesFailedWorkspaceLastURL() {
        let store = RecordingWorkspaceStateStore(state: .initial)
        let builder = RecordingWebViewBuilder()
        let controller = WebViewController(stateStore: store, webViewBuilder: builder)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let url = URL(string: "https://chatgpt.com/c/preserved-after-crash")!

        controller.start(in: container, workspace: .chatGPT)
        controller.currentCommittedURL = url
        controller.handleWebContentProcessTerminationForTesting()
        controller.switchWorkspace(to: .github)

        XCTAssertEqual(store.state.lastChatGPTURL, url)
    }

    func testEveryCreatedConfigurationUsesPersistentDefaultWebsiteDataStore() {
        let store = RecordingWorkspaceStateStore(state: .initial)
        let builder = RecordingWebViewBuilder()
        let controller = WebViewController(stateStore: store, webViewBuilder: builder)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        controller.start(in: container, workspace: .chatGPT)
        controller.switchWorkspace(to: .github)
        controller.switchWorkspace(to: .chatGPT)

        XCTAssertEqual(builder.configurations.count, 3)
        XCTAssertTrue(builder.configurations.allSatisfy { $0.websiteDataStore === WKWebsiteDataStore.default() })
    }
}

private final class RecordingWorkspaceStateStore: WorkspaceStateStoring {
    var state: PersistedWorkspaceState

    init(state: PersistedWorkspaceState) {
        self.state = state
    }

    func load() -> PersistedWorkspaceState {
        state
    }

    func save(_ state: PersistedWorkspaceState) {
        self.state = state
    }
}

private final class RecordingWebViewBuilder: WebViewBuilding {
    var configurations: [WKWebViewConfiguration] = []
    var createdViews: [WKWebView] = []
    var requestedURLs: [URL] = []

    func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        configurations.append(configuration)
        let view = RecordingWKWebView(frame: .zero, configuration: configuration) { [weak self] url in
            self?.requestedURLs.append(url)
        }
        createdViews.append(view)
        return view
    }
}

private final class RecordingWKWebView: WKWebView {
    private let onLoadURL: (URL) -> Void

    init(frame: CGRect, configuration: WKWebViewConfiguration, onLoadURL: @escaping (URL) -> Void) {
        self.onLoadURL = onLoadURL
        super.init(frame: frame, configuration: configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func load(_ request: URLRequest) -> WKNavigation? {
        if let url = request.url {
            onLoadURL(url)
        }
        return nil
    }
}
#endif
