#if os(macOS)
import WebKit
import XCTest
@testable import CatalinaWebApp
@testable import CatalinaWebCore

final class WebViewUIDelegateTests: XCTestCase {
    func testSameWorkspacePopupLoadsInCurrentViewAndNeverReturnsSecondWebView() {
        let runner = RecordingOpenPanelRunner()
        let opener = RecordingPopupExternalOpener()
        var internalLoads: [URL] = []
        let delegate = WebViewUIDelegate(
            workspace: .chatGPT,
            policy: NavigationPolicy(),
            externalOpener: opener,
            panelRunner: runner,
            loadInCurrentWebView: { internalLoads.append($0) }
        )
        let url = URL(string: "https://chatgpt.com/c/new")!

        let result = delegate.handlePopupForTesting(url: url)

        XCTAssertNil(result)
        XCTAssertEqual(internalLoads, [url])
        XCTAssertTrue(opener.urls.isEmpty)
    }

    func testCrossWorkspaceAndUnrelatedPopupsOpenExternally() {
        let runner = RecordingOpenPanelRunner()
        let opener = RecordingPopupExternalOpener()
        var internalLoads: [URL] = []
        let delegate = WebViewUIDelegate(
            workspace: .github,
            policy: NavigationPolicy(),
            externalOpener: opener,
            panelRunner: runner,
            loadInCurrentWebView: { internalLoads.append($0) }
        )
        let chatURL = URL(string: "https://chatgpt.com/")!
        let unrelatedURL = URL(string: "https://example.com/")!

        XCTAssertNil(delegate.handlePopupForTesting(url: chatURL))
        XCTAssertNil(delegate.handlePopupForTesting(url: unrelatedURL))
        XCTAssertEqual(opener.urls, [chatURL, unrelatedURL])
        XCTAssertTrue(internalLoads.isEmpty)
    }

    func testGitHubPopupLoadsInCurrentGitHubWorkspace() {
        let runner = RecordingOpenPanelRunner()
        let opener = RecordingPopupExternalOpener()
        var internalLoads: [URL] = []
        let delegate = WebViewUIDelegate(
            workspace: .github,
            policy: NavigationPolicy(),
            externalOpener: opener,
            panelRunner: runner,
            loadInCurrentWebView: { internalLoads.append($0) }
        )
        let url = URL(string: "https://github.com/79cbd8hmgj-wq/CatalinaWeb/issues")!

        XCTAssertNil(delegate.handlePopupForTesting(url: url))
        XCTAssertEqual(internalLoads, [url])
        XCTAssertTrue(opener.urls.isEmpty)
    }

    func testOpenPanelForwardsSelectionParametersAndSelectedURLsExactlyOnce() {
        let runner = RecordingOpenPanelRunner()
        let opener = RecordingPopupExternalOpener()
        let delegate = WebViewUIDelegate(
            workspace: .chatGPT,
            policy: NavigationPolicy(),
            externalOpener: opener,
            panelRunner: runner,
            loadInCurrentWebView: { _ in }
        )
        let files = [
            URL(fileURLWithPath: "/tmp/image.png"),
            URL(fileURLWithPath: "/tmp/note.txt")
        ]
        var completions: [[URL]?] = []

        delegate.runOpenPanelForTesting(
            allowsMultipleSelection: true,
            allowsDirectories: false,
            completionHandler: { completions.append($0) }
        )
        runner.complete(with: files)

        XCTAssertEqual(runner.lastAllowsMultipleSelection, true)
        XCTAssertEqual(runner.lastAllowsDirectories, false)
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions[0], files)
    }

    func testOpenPanelCancellationCompletesOnceWithNil() {
        let runner = RecordingOpenPanelRunner()
        let delegate = WebViewUIDelegate(
            workspace: .chatGPT,
            policy: NavigationPolicy(),
            externalOpener: RecordingPopupExternalOpener(),
            panelRunner: runner,
            loadInCurrentWebView: { _ in }
        )
        var completions: [[URL]?] = []

        delegate.runOpenPanelForTesting(
            allowsMultipleSelection: false,
            allowsDirectories: false,
            completionHandler: { completions.append($0) }
        )
        runner.complete(with: nil)

        XCTAssertEqual(completions.count, 1)
        XCTAssertNil(completions[0])
    }
}

private final class RecordingOpenPanelRunner: OpenPanelRunning {
    var lastAllowsMultipleSelection: Bool?
    var lastAllowsDirectories: Bool?
    private var completion: (([URL]?) -> Void)?

    func runOpenPanel(
        allowsMultipleSelection: Bool,
        allowsDirectories: Bool,
        completion: @escaping ([URL]?) -> Void
    ) {
        lastAllowsMultipleSelection = allowsMultipleSelection
        lastAllowsDirectories = allowsDirectories
        self.completion = completion
    }

    func complete(with urls: [URL]?) {
        let callback = completion
        completion = nil
        callback?(urls)
    }
}

private final class RecordingPopupExternalOpener: ExternalBrowserOpening {
    var urls: [URL] = []
    func openExternally(_ url: URL) { urls.append(url) }
}
#endif
