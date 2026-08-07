import Foundation

public enum Workspace: String, Codable, CaseIterable {
    case chatGPT
    case github

    public var homeURL: URL {
        switch self {
        case .chatGPT:
            return URL(string: "https://chatgpt.com/")!
        case .github:
            return URL(string: "https://github.com/")!
        }
    }
}

public struct PersistedWorkspaceState: Codable, Equatable {
    public var lastChatGPTURL: URL?
    public var lastGitHubURL: URL?
    public var activeWorkspace: Workspace
    public var windowFrame: String?

    public init(
        lastChatGPTURL: URL?,
        lastGitHubURL: URL?,
        activeWorkspace: Workspace,
        windowFrame: String?
    ) {
        self.lastChatGPTURL = lastChatGPTURL
        self.lastGitHubURL = lastGitHubURL
        self.activeWorkspace = activeWorkspace
        self.windowFrame = windowFrame
    }

    public static let initial = PersistedWorkspaceState(
        lastChatGPTURL: nil,
        lastGitHubURL: nil,
        activeWorkspace: .chatGPT,
        windowFrame: nil
    )

    public func lastURL(for workspace: Workspace) -> URL? {
        switch workspace {
        case .chatGPT:
            return lastChatGPTURL
        case .github:
            return lastGitHubURL
        }
    }

    public mutating func setLastURL(_ url: URL?, for workspace: Workspace) {
        switch workspace {
        case .chatGPT:
            lastChatGPTURL = url
        case .github:
            lastGitHubURL = url
        }
    }
}
