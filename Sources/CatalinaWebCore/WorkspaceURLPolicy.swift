import Foundation

public enum WorkspaceURLClassification: Equatable {
    case workspaceInternal
    case authentication
    case external
    case unsupported
}

public struct WorkspaceURLPolicy {
    public let chatGPTAuthenticationHosts: Set<String>
    public let githubAuthenticationHosts: Set<String>

    public init(
        chatGPTAuthenticationHosts: Set<String> = [],
        githubAuthenticationHosts: Set<String> = []
    ) {
        self.chatGPTAuthenticationHosts = Set(chatGPTAuthenticationHosts.map { $0.lowercased() })
        self.githubAuthenticationHosts = Set(githubAuthenticationHosts.map { $0.lowercased() })
    }

    public func classification(
        of url: URL,
        for workspace: Workspace
    ) -> WorkspaceURLClassification {
        guard let scheme = url.scheme?.lowercased() else {
            return .unsupported
        }

        if scheme == "mailto" || scheme == "tel" {
            return .external
        }

        guard scheme == "https" || scheme == "http" else {
            return .unsupported
        }

        guard scheme == "https" else {
            return .external
        }

        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return .unsupported
        }

        if hostMatchesWorkspace(host, workspace: workspace) {
            return .workspaceInternal
        }

        if authenticationHosts(for: workspace).contains(where: { baseHost in
            Self.host(host, matchesBaseHost: baseHost)
        }) {
            return .authentication
        }

        return .external
    }

    public func isValidSavedURL(_ url: URL, for workspace: Workspace) -> Bool {
        classification(of: url, for: workspace) == .workspaceInternal
    }

    private func hostMatchesWorkspace(_ host: String, workspace: Workspace) -> Bool {
        switch workspace {
        case .chatGPT:
            return Self.host(host, matchesBaseHost: "chatgpt.com")
        case .github:
            return Self.host(host, matchesBaseHost: "github.com")
        }
    }

    private func authenticationHosts(for workspace: Workspace) -> Set<String> {
        switch workspace {
        case .chatGPT:
            return chatGPTAuthenticationHosts
        case .github:
            return githubAuthenticationHosts
        }
    }

    private static func host(_ host: String, matchesBaseHost baseHost: String) -> Bool {
        host == baseHost || host.hasSuffix("." + baseHost)
    }
}
