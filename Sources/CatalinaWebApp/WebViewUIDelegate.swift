import AppKit
import CatalinaWebCore
import Foundation
import WebKit

protocol OpenPanelRunning: AnyObject {
    func runOpenPanel(
        allowsMultipleSelection: Bool,
        allowsDirectories: Bool,
        completion: @escaping ([URL]?) -> Void
    )
}

final class DefaultOpenPanelRunner: OpenPanelRunning {
    func runOpenPanel(
        allowsMultipleSelection: Bool,
        allowsDirectories: Bool,
        completion: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = allowsDirectories
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.begin { response in
            if response == .OK {
                completion(panel.urls)
            } else {
                completion(nil)
            }
        }
    }
}

final class WebViewUIDelegate: NSObject, WKUIDelegate {
    private let workspace: Workspace
    private let policy: NavigationPolicy
    private let externalOpener: ExternalBrowserOpening
    private let panelRunner: OpenPanelRunning
    private let loadInCurrentWebView: (URL) -> Void

    init(
        workspace: Workspace,
        policy: NavigationPolicy,
        externalOpener: ExternalBrowserOpening,
        panelRunner: OpenPanelRunning = DefaultOpenPanelRunner(),
        loadInCurrentWebView: @escaping (URL) -> Void
    ) {
        self.workspace = workspace
        self.policy = policy
        self.externalOpener = externalOpener
        self.panelRunner = panelRunner
        self.loadInCurrentWebView = loadInCurrentWebView
        super.init()
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        runOpenPanelForTesting(
            allowsMultipleSelection: parameters.allowsMultipleSelection,
            allowsDirectories: parameters.allowsDirectories,
            completionHandler: completionHandler
        )
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        handlePopupForTesting(url: navigationAction.request.url)
    }

    func handlePopupForTesting(url: URL?) -> WKWebView? {
        guard let url = url else {
            return nil
        }

        let context = NavigationContext(
            destinationURL: url,
            sourceURL: nil,
            workspace: workspace,
            isMainFrame: true,
            isUserInitiated: true
        )

        switch policy.decision(for: context) {
        case .allowInternal:
            loadInCurrentWebView(url)
        case .openExternal:
            externalOpener.openExternally(url)
        case .rejectUnsupportedScheme:
            break
        }

        return nil
    }

    func runOpenPanelForTesting(
        allowsMultipleSelection: Bool,
        allowsDirectories: Bool,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        panelRunner.runOpenPanel(
            allowsMultipleSelection: allowsMultipleSelection,
            allowsDirectories: allowsDirectories,
            completion: completionHandler
        )
    }
}
