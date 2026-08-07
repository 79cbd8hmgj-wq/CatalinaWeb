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
    public var controllerWindowFrame: String?
    public var orionWindowFrame: String?
    public var lastChatGPTActivatedAt: Date?
    public var lastGitHubActivatedAt: Date?
    public var setupStage: OrionSetupStage
    public var orionProfileIdentity: OrionProfileIdentity?

    public init(
        lastChatGPTURL: URL?,
        lastGitHubURL: URL?,
        activeWorkspace: Workspace,
        controllerWindowFrame: String?,
        orionWindowFrame: String?,
        lastChatGPTActivatedAt: Date?,
        lastGitHubActivatedAt: Date?,
        setupStage: OrionSetupStage,
        orionProfileIdentity: OrionProfileIdentity?
    ) {
        self.lastChatGPTURL = lastChatGPTURL
        self.lastGitHubURL = lastGitHubURL
        self.activeWorkspace = activeWorkspace
        self.controllerWindowFrame = controllerWindowFrame
        self.orionWindowFrame = orionWindowFrame
        self.lastChatGPTActivatedAt = lastChatGPTActivatedAt
        self.lastGitHubActivatedAt = lastGitHubActivatedAt
        self.setupStage = setupStage
        self.orionProfileIdentity = orionProfileIdentity
    }

    // Transitional source compatibility for Prototype 1 callers. Prototype 2 callers
    // use controllerWindowFrame explicitly; this alias is removed with the old UI.
    public init(
        lastChatGPTURL: URL?,
        lastGitHubURL: URL?,
        activeWorkspace: Workspace,
        windowFrame: String?
    ) {
        self.init(
            lastChatGPTURL: lastChatGPTURL,
            lastGitHubURL: lastGitHubURL,
            activeWorkspace: activeWorkspace,
            controllerWindowFrame: windowFrame,
            orionWindowFrame: nil,
            lastChatGPTActivatedAt: nil,
            lastGitHubActivatedAt: nil,
            setupStage: .notStarted,
            orionProfileIdentity: nil
        )
    }

    public static let initial = PersistedWorkspaceState(
        lastChatGPTURL: nil,
        lastGitHubURL: nil,
        activeWorkspace: .chatGPT,
        controllerWindowFrame: nil,
        orionWindowFrame: nil,
        lastChatGPTActivatedAt: nil,
        lastGitHubActivatedAt: nil,
        setupStage: .notStarted,
        orionProfileIdentity: nil
    )

    // Transitional source compatibility for Prototype 1 UI code.
    public var windowFrame: String? {
        get { controllerWindowFrame }
        set { controllerWindowFrame = newValue }
    }

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

    public mutating func markActivated(_ workspace: Workspace, at date: Date) {
        switch workspace {
        case .chatGPT:
            lastChatGPTActivatedAt = date
        case .github:
            lastGitHubActivatedAt = date
        }
    }
}
