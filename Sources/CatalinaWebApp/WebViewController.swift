import AppKit
import CatalinaWebCore
import WebKit

protocol WebViewControlling: AnyObject {
    var activeWorkspace: Workspace { get }
    var liveWebViewCount: Int { get }
    func start(in containerView: NSView, workspace: Workspace)
    func switchWorkspace(to workspace: Workspace)
    func reloadCurrentWorkspace()
    func goBack()
    func goForward()
}

protocol WebViewBuilding: AnyObject {
    func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView
}

final class DefaultWebViewBuilder: WebViewBuilding {
    func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        WKWebView(frame: .zero, configuration: configuration)
    }
}

final class WebViewController: WebViewControlling {
    private let stateStore: WorkspaceStateStoring
    private let webViewBuilder: WebViewBuilding
    private let navigationPolicy: NavigationPolicy
    private let externalOpener: ExternalBrowserOpening
    private let eventRecorder: BrowserEventRecording
    private weak var containerView: NSView?
    private var state: PersistedWorkspaceState
    private var navigationDelegate: WebViewNavigationDelegate?
    private var uiDelegate: WebViewUIDelegate?
    private var failureOverlayView: FailureOverlayView?

    private(set) var activeWorkspace: Workspace
    private(set) var currentWebView: WKWebView?
    private(set) var recoveryState: WebViewRecoveryState = .healthy
    var currentCommittedURL: URL?

    var liveWebViewCount: Int {
        currentWebView == nil ? 0 : 1
    }

    init(
        stateStore: WorkspaceStateStoring = UserDefaultsWorkspaceStateStore(),
        webViewBuilder: WebViewBuilding = DefaultWebViewBuilder(),
        navigationPolicy: NavigationPolicy = NavigationPolicy(),
        externalOpener: ExternalBrowserOpening = OrionExternalBrowserOpener(),
        eventRecorder: BrowserEventRecording = NullBrowserEventRecorder()
    ) {
        self.stateStore = stateStore
        self.webViewBuilder = webViewBuilder
        self.navigationPolicy = navigationPolicy
        self.externalOpener = externalOpener
        self.eventRecorder = eventRecorder
        let loadedState = stateStore.load()
        self.state = loadedState
        self.activeWorkspace = loadedState.activeWorkspace
    }

    func start(in containerView: NSView, workspace: Workspace) {
        self.containerView = containerView
        hideFailureOverlay()
        recoveryState = .healthy
        if currentWebView != nil {
            teardownCurrentWebView()
        }
        activeWorkspace = workspace
        state.activeWorkspace = workspace
        stateStore.save(state)
        createAndAttachWebView(for: workspace)
    }

    func switchWorkspace(to workspace: Workspace) {
        guard workspace != activeWorkspace else {
            return
        }

        let previousWorkspace = activeWorkspace
        saveCurrentURL()
        teardownCurrentWebView()
        hideFailureOverlay()
        recoveryState = .healthy

        activeWorkspace = workspace
        state.activeWorkspace = workspace
        stateStore.save(state)
        eventRecorder.record(.workspaceSwitched(from: previousWorkspace, to: workspace))
        createAndAttachWebView(for: workspace)
    }

    func reloadCurrentWorkspace() {
        currentWebView?.reload()
    }

    func goBack() {
        currentWebView?.goBack()
    }

    func goForward() {
        currentWebView?.goForward()
    }

    func recreateCurrentWorkspaceAfterFailure() {
        guard case .terminated = recoveryState else {
            return
        }
        hideFailureOverlay()
        recoveryState.requestReload()
        createAndAttachWebView(for: activeWorkspace)
    }

    func handleWebContentProcessTerminationForTesting() {
        handleWebContentProcessTermination()
    }

    private func handleWebContentProcessTermination() {
        let lastURL = currentCommittedURL ?? currentWebView?.url ?? state.lastURL(for: activeWorkspace)
        if let lastURL = lastURL {
            state.setLastURL(lastURL, for: activeWorkspace)
            stateStore.save(state)
        }
        recoveryState.recordTermination(workspace: activeWorkspace, lastURL: lastURL)
        teardownCurrentWebView()
        showFailureOverlay()
    }

    private func saveCurrentURL() {
        guard let url = currentCommittedURL ?? currentWebView?.url else {
            return
        }
        state.setLastURL(url, for: activeWorkspace)
        stateStore.save(state)
    }

    private func teardownCurrentWebView() {
        currentWebView?.stopLoading()
        currentWebView?.navigationDelegate = nil
        currentWebView?.uiDelegate = nil
        currentWebView?.removeFromSuperview()
        currentWebView = nil
        navigationDelegate = nil
        uiDelegate = nil
        currentCommittedURL = nil
    }

    private func createAndAttachWebView(for workspace: Workspace) {
        guard let containerView = containerView else {
            return
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        let webView = webViewBuilder.makeWebView(configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        let delegate = WebViewNavigationDelegate(
            workspace: workspace,
            policy: navigationPolicy,
            externalOpener: externalOpener,
            stateStore: stateStore,
            eventRecorder: eventRecorder,
            onCommittedURL: { [weak self] url in
                self?.currentCommittedURL = url
            },
            onWebContentProcessTerminated: { [weak self] in
                self?.handleWebContentProcessTermination()
            }
        )
        navigationDelegate = delegate
        webView.navigationDelegate = delegate

        let webUIDelegate = WebViewUIDelegate(
            workspace: workspace,
            policy: navigationPolicy,
            externalOpener: externalOpener,
            loadInCurrentWebView: { [weak webView] url in
                webView?.load(URLRequest(url: url))
            }
        )
        uiDelegate = webUIDelegate
        webView.uiDelegate = webUIDelegate

        currentWebView = webView
        let destinationURL = state.lastURL(for: workspace) ?? workspace.homeURL
        webView.load(URLRequest(url: destinationURL))
    }

    private func showFailureOverlay() {
        guard let containerView = containerView else {
            return
        }
        hideFailureOverlay()
        let overlay = FailureOverlayView(reloadHandler: { [weak self] in
            self?.recreateCurrentWorkspaceAfterFailure()
        })
        failureOverlayView = overlay
        containerView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    private func hideFailureOverlay() {
        failureOverlayView?.removeFromSuperview()
        failureOverlayView = nil
    }
}
