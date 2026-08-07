import Foundation

public enum BrowserEvent: Equatable {
    case workspaceSwitched(from: Workspace, to: Workspace)
    case externalNavigationBlocked(url: URL, workspace: Workspace)
    case navigationFailed(url: URL?, code: Int, description: String)
    case navigationCommitted(url: URL, workspace: Workspace)
    case webContentProcessTerminated(workspace: Workspace)
    case downloadCandidate(url: URL?, mimeType: String?)
}

public protocol BrowserEventRecording: AnyObject {
    func record(_ event: BrowserEvent)
}

public final class NullBrowserEventRecorder: BrowserEventRecording {
    public init() {}
    public func record(_ event: BrowserEvent) {}
}
