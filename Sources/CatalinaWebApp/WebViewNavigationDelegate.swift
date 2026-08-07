import CatalinaWebCore
import Foundation
import WebKit

final class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private let workspace: Workspace
    private let policy: NavigationPolicy
    private let externalOpener: ExternalBrowserOpening
    private let stateStore: WorkspaceStateStoring
    private let eventRecorder: BrowserEventRecording
    private let onCommittedURL: (URL) -> Void
    private let onWebContentProcessTerminated: () -> Void

    init(
        workspace: Workspace,
        policy: NavigationPolicy,
        externalOpener: ExternalBrowserOpening,
        stateStore: WorkspaceStateStoring,
        eventRecorder: BrowserEventRecording,
        onCommittedURL: @escaping (URL) -> Void,
        onWebContentProcessTerminated: @escaping () -> Void = {}
    ) {
        self.workspace = workspace
        self.policy = policy
        self.externalOpener = externalOpener
        self.stateStore = stateStore
        self.eventRecorder = eventRecorder
        self.onCommittedURL = onCommittedURL
        self.onWebContentProcessTerminated = onWebContentProcessTerminated
        super.init()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let destinationURL = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let decision = decisionForTesting(
            destinationURL: destinationURL,
            sourceURL: webView.url,
            isMainFrame: navigationAction.targetFrame?.isMainFrame ?? true,
            isUserInitiated: Self.isUserInitiated(navigationAction.navigationType)
        )
        decisionHandler(decision)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(observeResponseForTesting(
            response: navigationResponse.response,
            canShowMIMEType: navigationResponse.canShowMIMEType
        ))
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard let url = webView.url else {
            return
        }
        commitForTesting(url: url)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        recordFailureForTesting(url: webView.url, error: error as NSError)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        recordFailureForTesting(url: webView.url, error: error as NSError)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        eventRecorder.record(.webContentProcessTerminated(workspace: workspace))
        onWebContentProcessTerminated()
    }

    func decisionForTesting(
        destinationURL: URL,
        sourceURL: URL?,
        isMainFrame: Bool,
        isUserInitiated: Bool
    ) -> WKNavigationActionPolicy {
        let context = NavigationContext(
            destinationURL: destinationURL,
            sourceURL: sourceURL,
            workspace: workspace,
            isMainFrame: isMainFrame,
            isUserInitiated: isUserInitiated
        )

        switch policy.decision(for: context) {
        case .allowInternal:
            return .allow
        case .openExternal:
            externalOpener.openExternally(destinationURL)
            eventRecorder.record(.externalNavigationBlocked(url: destinationURL, workspace: workspace))
            return .cancel
        case .rejectUnsupportedScheme:
            return .cancel
        }
    }

    func commitForTesting(url: URL) {
        var state = stateStore.load()
        state.setLastURL(url, for: workspace)
        stateStore.save(state)
        onCommittedURL(url)
        eventRecorder.record(.navigationCommitted(url: url, workspace: workspace))
    }

    func recordFailureForTesting(url: URL?, error: NSError) {
        eventRecorder.record(.navigationFailed(
            url: url,
            code: error.code,
            description: error.localizedDescription
        ))
    }

    func observeResponseForTesting(
        response: URLResponse,
        canShowMIMEType: Bool
    ) -> WKNavigationResponsePolicy {
        let mimeType = response.mimeType
        let isAttachment = Self.isAttachmentResponse(response)
        if let mimeType = mimeType, !canShowMIMEType || isAttachment {
            eventRecorder.record(.downloadCandidate(url: response.url, mimeType: mimeType))
        }
        return .allow
    }

    private static func isAttachmentResponse(_ response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        for (key, value) in httpResponse.allHeaderFields {
            guard String(describing: key).lowercased() == "content-disposition" else {
                continue
            }
            return String(describing: value).lowercased().contains("attachment")
        }
        return false
    }

    private static func isUserInitiated(_ type: WKNavigationType) -> Bool {
        switch type {
        case .linkActivated, .formSubmitted, .formResubmitted, .backForward, .reload:
            return true
        case .other:
            return false
        @unknown default:
            return false
        }
    }
}
