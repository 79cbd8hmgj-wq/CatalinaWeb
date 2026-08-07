import AppKit
import CatalinaWebCore

final class DiagnosticsWindowController: NSWindowController {
    private let collector: DiagnosticsCollector
    private let textView: NSTextView

    init(collector: DiagnosticsCollector) {
        self.collector = collector
        self.textView = NSTextView(frame: .zero)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CatalinaWeb Diagnostics"

        super.init(window: window)
        configureInterface(in: window)
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func showWindow(_ sender: Any?) {
        refresh()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    @objc func refreshDiagnostics(_ sender: Any?) {
        refresh()
    }

    private func configureInterface(in window: NSWindow) {
        let rootView = NSView(frame: .zero)
        rootView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = rootView

        let refreshButton = NSButton(
            title: "Refresh",
            target: self,
            action: #selector(refreshDiagnostics(_:))
        )
        refreshButton.bezelStyle = .rounded
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        scrollView.documentView = textView

        rootView.addSubview(refreshButton)
        rootView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            refreshButton.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 10),
            refreshButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),

            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -10)
        ])
    }

    private func refresh() {
        let snapshot = collector.currentSnapshot()
        let events = collector.recentEvents()

        var lines: [String] = [
            "CatalinaWeb Diagnostics",
            "",
            "Snapshot: \(Self.dateFormatter.string(from: snapshot.timestamp))",
            "Active workspace: \(Self.workspaceName(snapshot.activeWorkspace))",
            "Live WKWebViews: \(snapshot.liveWebViewCount)",
            "Application RSS: \(DiagnosticsFormatter.bytes(snapshot.appResidentBytes))",
            "Strict descendant processes: \(DiagnosticsFormatter.processCount(snapshot.attributableChildProcessCount))",
            "Attributable family RSS: \(DiagnosticsFormatter.bytes(snapshot.attributableFamilyResidentBytes))",
            "Memory pressure: \(snapshot.memoryPressure.displayName)",
            "",
            "Process attribution note:",
            "Only strict public parent/child relationships are counted. WebKit XPC processes that cannot be safely attributed are excluded rather than guessed.",
            "",
            "Recent lifecycle events (\(events.count)/200):"
        ]

        if events.isEmpty {
            lines.append("None")
        } else {
            lines.append(contentsOf: events.map(Self.describe))
        }

        textView.string = lines.joined(separator: "\n")
    }

    private static func describe(_ event: BrowserEvent) -> String {
        switch event {
        case let .workspaceSwitched(from, to):
            return "workspace switched: \(workspaceName(from)) -> \(workspaceName(to))"
        case let .externalNavigationBlocked(url, workspace):
            return "external navigation: \(workspaceName(workspace)) -> \(url.absoluteString)"
        case let .navigationFailed(url, code, description):
            return "navigation failed: \(url?.absoluteString ?? "unknown URL") [\(code)] \(description)"
        case let .navigationCommitted(url, workspace):
            return "navigation committed: \(workspaceName(workspace)) -> \(url.absoluteString)"
        case let .webContentProcessTerminated(workspace):
            return "web content terminated: \(workspaceName(workspace))"
        case let .downloadCandidate(url, mimeType):
            return "download candidate: \(url?.absoluteString ?? "unknown URL") [\(mimeType ?? "unknown MIME")]"
        }
    }

    private static func workspaceName(_ workspace: Workspace) -> String {
        switch workspace {
        case .chatGPT:
            return "ChatGPT"
        case .github:
            return "GitHub"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}
