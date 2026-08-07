import Foundation

public protocol WorkspaceStateStoring: AnyObject {
    func load() -> PersistedWorkspaceState
    func save(_ state: PersistedWorkspaceState)
}

public final class UserDefaultsWorkspaceStateStore: WorkspaceStateStoring {
    public static let storageKey = "CatalinaWeb.workspaceState.v2"
    public static let legacyStorageKey = "CatalinaWeb.workspaceState.v1"

    private struct LegacyPersistedWorkspaceStateV1: Codable {
        let lastChatGPTURL: URL?
        let lastGitHubURL: URL?
        let activeWorkspace: Workspace
        let windowFrame: String?

        private enum CodingKeys: String, CodingKey {
            case lastChatGPTURL
            case lastGitHubURL
            case activeWorkspace
            case windowFrame
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            lastChatGPTURL = try container.decodeIfPresent(URL.self, forKey: .lastChatGPTURL)
            lastGitHubURL = try container.decodeIfPresent(URL.self, forKey: .lastGitHubURL)
            activeWorkspace = try container.decodeIfPresent(Workspace.self, forKey: .activeWorkspace) ?? .chatGPT
            windowFrame = try container.decodeIfPresent(String.self, forKey: .windowFrame)
        }
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func load() -> PersistedWorkspaceState {
        if let data = defaults.data(forKey: Self.storageKey) {
            do {
                return try decoder.decode(PersistedWorkspaceState.self, from: data)
            } catch {
                return .initial
            }
        }

        guard let legacyData = defaults.data(forKey: Self.legacyStorageKey) else {
            return .initial
        }

        do {
            let legacy = try decoder.decode(LegacyPersistedWorkspaceStateV1.self, from: legacyData)
            let migrated = PersistedWorkspaceState(
                lastChatGPTURL: legacy.lastChatGPTURL,
                lastGitHubURL: legacy.lastGitHubURL,
                activeWorkspace: legacy.activeWorkspace,
                controllerWindowFrame: legacy.windowFrame,
                orionWindowFrame: nil,
                lastChatGPTActivatedAt: nil,
                lastGitHubActivatedAt: nil,
                setupStage: .notStarted,
                orionProfileIdentity: nil
            )
            save(migrated)
            return migrated
        } catch {
            return .initial
        }
    }

    public func save(_ state: PersistedWorkspaceState) {
        guard let data = try? encoder.encode(state) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}
