import Foundation

public struct NavigationContext: Equatable {
    public let destinationURL: URL
    public let sourceURL: URL?
    public let workspace: Workspace
    public let isMainFrame: Bool
    public let isUserInitiated: Bool

    public init(
        destinationURL: URL,
        sourceURL: URL?,
        workspace: Workspace,
        isMainFrame: Bool,
        isUserInitiated: Bool
    ) {
        self.destinationURL = destinationURL
        self.sourceURL = sourceURL
        self.workspace = workspace
        self.isMainFrame = isMainFrame
        self.isUserInitiated = isUserInitiated
    }
}

public enum NavigationDecision: Equatable {
    case allowInternal
    case openExternal
    case rejectUnsupportedScheme
}

public struct NavigationPolicy {
    public init() {}

    public func decision(for context: NavigationContext) -> NavigationDecision {
        guard let scheme = context.destinationURL.scheme?.lowercased() else {
            return .rejectUnsupportedScheme
        }

        if scheme == "blob" {
            return blobDecision(for: context)
        }

        if scheme == "javascript" || scheme == "data" || scheme == "file" {
            return .rejectUnsupportedScheme
        }

        if scheme == "mailto" || scheme == "tel" {
            return .openExternal
        }

        guard scheme == "https" || scheme == "http" else {
            return .rejectUnsupportedScheme
        }

        if !context.isMainFrame {
            return .allowInternal
        }

        guard scheme == "https" else {
            return .openExternal
        }

        return isAllowedTopLevelURL(context.destinationURL, for: context.workspace)
            ? .allowInternal
            : .openExternal
    }

    public func isAllowedTopLevelURL(_ url: URL, for workspace: Workspace) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return false
        }

        return allowedBaseHosts(for: workspace).contains { baseHost in
            host == baseHost || host.hasSuffix("." + baseHost)
        }
    }

    private func blobDecision(for context: NavigationContext) -> NavigationDecision {
        guard let sourceURL = context.sourceURL,
              isAllowedTopLevelURL(sourceURL, for: context.workspace) else {
            return .rejectUnsupportedScheme
        }
        return .allowInternal
    }

    private func allowedBaseHosts(for workspace: Workspace) -> [String] {
        switch workspace {
        case .chatGPT:
            return ["chatgpt.com", "openai.com"]
        case .github:
            return ["github.com", "githubusercontent.com"]
        }
    }
}
