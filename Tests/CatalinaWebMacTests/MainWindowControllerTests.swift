#if os(macOS)
import AppKit
import XCTest
@testable import CatalinaWebApp
@testable import CatalinaWebCore

final class MainWindowControllerTests: XCTestCase {
    func testWindowContainsOnlyTwoFixedWorkspaceSegmentsAndNavigationControls() {
        let spy = WebViewControllerSpy(activeWorkspace: .chatGPT)
        let store = RecordingWindowStateStore(state: .initial)
        let controller = MainWindowController(webViewController: spy, stateStore: store)
        _ = controller.window

        XCTAssertEqual(controller.workspaceControl.segmentCount, 2)
        XCTAssertEqual(controller.workspaceControl.label(forSegment: 0), "ChatGPT")
        XCTAssertEqual(controller.workspaceControl.label(forSegment: 1), "GitHub")
        XCTAssertNotNil(controller.backButton)
        XCTAssertNotNil(controller.forwardButton)
        XCTAssertNotNil(controller.reloadButton)

        let textFields = descendants(of: controller.window!.contentView!).compactMap { $0 as? NSTextField }
        XCTAssertTrue(textFields.isEmpty, "Prototype 1 must not expose an address/search field")
    }

    func testSelectingGitHubForwardsIntentAndUpdatesSelectedSegment() {
        let spy = WebViewControllerSpy(activeWorkspace: .chatGPT)
        let store = RecordingWindowStateStore(state: .initial)
        let controller = MainWindowController(webViewController: spy, stateStore: store)
        _ = controller.window

        controller.workspaceControl.selectedSegment = 1
        controller.workspaceChanged(controller.workspaceControl)

        XCTAssertEqual(spy.switchRequests, [.github])
        XCTAssertEqual(controller.workspaceControl.selectedSegment, 1)
    }

    func testInitialWorkspaceSelectionTracksControllerState() {
        let spy = WebViewControllerSpy(activeWorkspace: .github)
        var state = PersistedWorkspaceState.initial
        state.activeWorkspace = .github
        let store = RecordingWindowStateStore(state: state)
        let controller = MainWindowController(webViewController: spy, stateStore: store)
        _ = controller.window

        XCTAssertEqual(controller.workspaceControl.selectedSegment, 1)
        XCTAssertEqual(spy.startRequests.map { $0.workspace }, [.github])
    }

    func testAppMenuContainsDiagnosticsCommand() {
        let spy = WebViewControllerSpy(activeWorkspace: .chatGPT)
        let store = RecordingWindowStateStore(state: .initial)
        let controller = MainWindowController(webViewController: spy, stateStore: store)
        let menu = AppMenuBuilder().makeMainMenu(target: controller)
        let items = allMenuItems(in: menu)

        XCTAssertTrue(items.contains { $0.title == "Diagnostics" })
    }

    func testAppMenuContainsRequiredShortcutsAndNoCommandL() {
        let spy = WebViewControllerSpy(activeWorkspace: .chatGPT)
        let store = RecordingWindowStateStore(state: .initial)
        let controller = MainWindowController(webViewController: spy, stateStore: store)
        let menu = AppMenuBuilder().makeMainMenu(target: controller)
        let items = allMenuItems(in: menu)

        XCTAssertTrue(items.contains { $0.keyEquivalent == "1" && $0.keyEquivalentModifierMask.contains(.command) })
        XCTAssertTrue(items.contains { $0.keyEquivalent == "2" && $0.keyEquivalentModifierMask.contains(.command) })
        XCTAssertTrue(items.contains { $0.keyEquivalent == "[" && $0.keyEquivalentModifierMask.contains(.command) })
        XCTAssertTrue(items.contains { $0.keyEquivalent == "]" && $0.keyEquivalentModifierMask.contains(.command) })
        XCTAssertTrue(items.contains { $0.keyEquivalent.lowercased() == "r" && $0.keyEquivalentModifierMask.contains(.command) })
        XCTAssertTrue(items.contains { $0.keyEquivalent.lowercased() == "w" && $0.keyEquivalentModifierMask.contains(.command) })
        XCTAssertFalse(items.contains { $0.keyEquivalent.lowercased() == "l" && $0.keyEquivalentModifierMask.contains(.command) })
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants(of:))
    }

    private func allMenuItems(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { item -> [NSMenuItem] in
            if let submenu = item.submenu {
                return [item] + allMenuItems(in: submenu)
            }
            return [item]
        }
    }
}

private final class WebViewControllerSpy: WebViewControlling {
    var activeWorkspace: Workspace
    var liveWebViewCount: Int = 0
    var switchRequests: [Workspace] = []
    var startRequests: [(view: NSView, workspace: Workspace)] = []
    var reloadCount = 0
    var backCount = 0
    var forwardCount = 0

    init(activeWorkspace: Workspace) {
        self.activeWorkspace = activeWorkspace
    }

    func start(in containerView: NSView, workspace: Workspace) {
        activeWorkspace = workspace
        liveWebViewCount = 1
        startRequests.append((containerView, workspace))
    }

    func switchWorkspace(to workspace: Workspace) {
        activeWorkspace = workspace
        switchRequests.append(workspace)
    }

    func reloadCurrentWorkspace() { reloadCount += 1 }
    func goBack() { backCount += 1 }
    func goForward() { forwardCount += 1 }
}

private final class RecordingWindowStateStore: WorkspaceStateStoring {
    var state: PersistedWorkspaceState

    init(state: PersistedWorkspaceState) {
        self.state = state
    }

    func load() -> PersistedWorkspaceState { state }
    func save(_ state: PersistedWorkspaceState) { self.state = state }
}
#endif
