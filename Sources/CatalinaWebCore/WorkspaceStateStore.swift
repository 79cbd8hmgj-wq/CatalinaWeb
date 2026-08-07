import Foundation

public protocol WorkspaceStateStoring: AnyObject {
    func load() -> PersistedWorkspaceState
    func save(_ state: PersistedWorkspaceState)
}

public final class UserDefaultsWorkspaceStateStore: WorkspaceStateStoring {
    public static let storageKey = "CatalinaWeb.workspaceState.v1"

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func load() -> PersistedWorkspaceState {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .initial
        }

        do {
            return try decoder.decode(PersistedWorkspaceState.self, from: data)
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
