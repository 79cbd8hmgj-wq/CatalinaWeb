import AppKit
import CatalinaWebCore

final class MainWindowController: NSWindowController, NSWindowDelegate {
    let workspaceControl: NSSegmentedControl
    let backButton: NSButton
    let forwardButton: NSButton
    let reloadButton: NSButton
    let webContentContainerView: NSView

    private let webViewController: WebViewControlling
    private let stateStore: WorkspaceStateStoring
    private let diagnosticsCollector: DiagnosticsCollector?
    private var diagnosticsWindowController: DiagnosticsWindowController?

    convenience init() {
        let store = UserDefaultsWorkspaceStateStore()
        let context = DiagnosticsWebViewContext()
        let collector = DiagnosticsCollector(
            contextProvider: { context.snapshot() }
        )
        let webViewController = WebViewController(
            stateStore: store,
            eventRecorder: collector
        )
        context.webViewController = webViewController
        self.init(
            webViewController: webViewController,
            stateStore: store,
            diagnosticsCollector: collector
        )
    }

    init(
        webViewController: WebViewControlling,
        stateStore: WorkspaceStateStoring,
        diagnosticsCollector: DiagnosticsCollector? = nil
    ) {
        self.webViewController = webViewController
        self.stateStore = stateStore
        self.diagnosticsCollector = diagnosticsCollector
        self.workspaceControl = NSSegmentedControl(
            labels: ["ChatGPT", "GitHub"],
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )
        self.backButton = NSButton(title: "←", target: nil, action: nil)
        self.forwardButton = NSButton(title: "→", target: nil, action: nil)
        self.reloadButton = NSButton(title: "↻", target: nil, action: nil)
        self.webContentContainerView = NSView(frame: .zero)

        let defaultFrame = NSRect(x: 0, y: 0, width: 1100, height: 760)
        let window = NSWindow(
            contentRect: defaultFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CatalinaWeb"

        super.init(window: window)

        window.delegate = self
        configureInterface(in: window)
        restoreWindowFrameOrCenter(window)

        let initialWorkspace = stateStore.load().activeWorkspace
        workspaceControl.selectedSegment = segmentIndex(for: initialWorkspace)
        webViewController.start(in: webContentContainerView, workspace: initialWorkspace)
        updateWorkspaceSelection()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc func workspaceChanged(_ sender: NSSegmentedControl) {
        guard let workspace = workspace(forSegment: sender.selectedSegment) else {
            updateWorkspaceSelection()
            return
        }
        webViewController.switchWorkspace(to: workspace)
        updateWorkspaceSelection()
        persistWindowAndWorkspaceState()
    }

    @objc func switchToChatGPT(_ sender: Any?) {
        webViewController.switchWorkspace(to: .chatGPT)
        updateWorkspaceSelection()
        persistWindowAndWorkspaceState()
    }

    @objc func switchToGitHub(_ sender: Any?) {
        webViewController.switchWorkspace(to: .github)
        updateWorkspaceSelection()
        persistWindowAndWorkspaceState()
    }

    @objc func goBack(_ sender: Any?) {
        webViewController.goBack()
    }

    @objc func goForward(_ sender: Any?) {
        webViewController.goForward()
    }

    @objc func reload(_ sender: Any?) {
        webViewController.reloadCurrentWorkspace()
    }

    @objc func showDiagnostics(_ sender: Any?) {
        guard let collector = diagnosticsCollector else {
            return
        }

        let controller: DiagnosticsWindowController
        if let existing = diagnosticsWindowController {
            controller = existing
        } else {
            let created = DiagnosticsWindowController(collector: collector)
            diagnosticsWindowController = created
            controller = created
        }
        controller.showWindow(sender)
    }

    func windowDidMove(_ notification: Notification) {
        persistWindowAndWorkspaceState()
    }

    func windowDidResize(_ notification: Notification) {
        persistWindowAndWorkspaceState()
    }

    func windowWillClose(_ notification: Notification) {
        persistWindowAndWorkspaceState()
    }

    private func configureInterface(in window: NSWindow) {
        let rootView = NSView(frame: .zero)
        rootView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = rootView

        workspaceControl.segmentStyle = .texturedRounded
        workspaceControl.target = self
        workspaceControl.action = #selector(workspaceChanged(_:))

        backButton.bezelStyle = .texturedRounded
        backButton.target = self
        backButton.action = #selector(goBack(_:))
        backButton.toolTip = "Back"

        forwardButton.bezelStyle = .texturedRounded
        forwardButton.target = self
        forwardButton.action = #selector(goForward(_:))
        forwardButton.toolTip = "Forward"

        reloadButton.bezelStyle = .texturedRounded
        reloadButton.target = self
        reloadButton.action = #selector(reload(_:))
        reloadButton.toolTip = "Reload"

        let spacer = NSView(frame: .zero)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let topBar = NSStackView(views: [
            workspaceControl,
            spacer,
            backButton,
            forwardButton,
            reloadButton
        ])
        topBar.orientation = .horizontal
        topBar.alignment = .centerY
        topBar.spacing = 8
        topBar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        topBar.translatesAutoresizingMaskIntoConstraints = false

        webContentContainerView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(topBar)
        rootView.addSubview(webContentContainerView)

        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: rootView.topAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            webContentContainerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            webContentContainerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            webContentContainerView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            webContentContainerView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])
    }

    private func restoreWindowFrameOrCenter(_ window: NSWindow) {
        let state = stateStore.load()
        if let frameString = state.windowFrame {
            let frame = NSRectFromString(frameString)
            let intersectsCurrentScreen = !frame.isEmpty && NSScreen.screens.contains { screen in
                screen.frame.intersects(frame)
            }
            if intersectsCurrentScreen {
                window.setFrame(frame, display: false)
                return
            }
        }
        window.center()
    }

    private func persistWindowAndWorkspaceState() {
        guard let window = window else {
            return
        }
        var state = stateStore.load()
        state.activeWorkspace = webViewController.activeWorkspace
        state.windowFrame = NSStringFromRect(window.frame)
        stateStore.save(state)
    }

    private func updateWorkspaceSelection() {
        workspaceControl.selectedSegment = segmentIndex(for: webViewController.activeWorkspace)
    }

    private func segmentIndex(for workspace: Workspace) -> Int {
        switch workspace {
        case .chatGPT:
            return 0
        case .github:
            return 1
        }
    }

    private func workspace(forSegment segment: Int) -> Workspace? {
        switch segment {
        case 0:
            return .chatGPT
        case 1:
            return .github
        default:
            return nil
        }
    }
}

private final class DiagnosticsWebViewContext {
    weak var webViewController: WebViewControlling?

    func snapshot() -> (workspace: Workspace, liveWebViewCount: Int) {
        guard let controller = webViewController else {
            return (.chatGPT, 0)
        }
        return (controller.activeWorkspace, controller.liveWebViewCount)
    }
}
