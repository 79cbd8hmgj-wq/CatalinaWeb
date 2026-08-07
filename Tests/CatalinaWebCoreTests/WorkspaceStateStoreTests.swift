import XCTest
@testable import CatalinaWebCore

final class WorkspaceStateStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "CatalinaWebTests.WorkspaceStateStore.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testExactStateRoundTrips() {
        let store = UserDefaultsWorkspaceStateStore(defaults: defaults)
        let expected = PersistedWorkspaceState(
            lastChatGPTURL: URL(string: "https://chatgpt.com/c/round-trip"),
            lastGitHubURL: URL(string: "https://github.com/79cbd8hmgj-wq/CatalinaWeb/tree/main"),
            activeWorkspace: .github,
            windowFrame: "{{10, 20}, {1100, 760}}"
        )

        store.save(expected)

        XCTAssertEqual(store.load(), expected)
    }

    func testCorruptDataReturnsInitialWithoutRewritingInvalidPayload() {
        let store = UserDefaultsWorkspaceStateStore(defaults: defaults)
        let corrupt = Data([0x00, 0x01, 0x02, 0x03])
        defaults.set(corrupt, forKey: UserDefaultsWorkspaceStateStore.storageKey)

        XCTAssertEqual(store.load(), .initial)
        XCTAssertEqual(defaults.data(forKey: UserDefaultsWorkspaceStateStore.storageKey), corrupt)
    }

    func testStoreWritesOnlyApprovedEncodedStateKey() {
        let store = UserDefaultsWorkspaceStateStore(defaults: defaults)
        store.save(.initial)

        let domain = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertEqual(Set(domain.keys), [UserDefaultsWorkspaceStateStore.storageKey])
    }
}
