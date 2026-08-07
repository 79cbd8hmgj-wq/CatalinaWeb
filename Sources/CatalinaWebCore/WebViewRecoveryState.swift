import Foundation

public enum WebViewRecoveryState: Equatable {
    case healthy
    case terminated(workspace: Workspace, lastURL: URL?)

    public mutating func recordTermination(workspace: Workspace, lastURL: URL?) {
        self = .terminated(workspace: workspace, lastURL: lastURL)
    }

    public mutating func requestReload() {
        self = .healthy
    }
}
