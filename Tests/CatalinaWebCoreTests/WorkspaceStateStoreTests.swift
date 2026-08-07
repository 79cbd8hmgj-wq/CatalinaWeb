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
        let profile = OrionProfileIdentity(
            applicationURL: URL(fileURLWithPath: "/Users/test/Applications/Orion/Orion Profiles/CatalinaWeb.app"),
            bundleIdentifier: "com.kagi.kagimacOS.CatalinaWeb",
            localizedName: "CatalinaWeb"
        )
        let expected = PersistedWorkspaceState(
            lastChatGPTURL: URL(string: "https://chatgpt.com/c/round-trip"),
            lastGitHubURL: URL(string: "https://github.com/79cbd8hmgj-wq/CatalinaWeb/tree/main"),
            activeWorkspace: .github,
            controllerWindowFrame: "{{10, 20}, {520, 120}}",
            orionWindowFrame: "{{40, 50}, {1100, 760}}",
            lastChatGPTActivatedAt: Date(timeIntervalSince1970: 100),
            lastGitHubActivatedAt: Date(timeIntervalSince1970: 200),
            setupStage: .profileVerified,
            orionProfileIdentity: profile
        )

        store.save(expected)

        XCTAssertEqual(store.load(), expected)
    }

    func testV1StateMigratesWindowFrameToControllerFrame() throws {
        let legacy = """
        {"activeWorkspace":"github","windowFrame":"{{10, 20}, {900, 700}}"}
        """.data(using: .utf8)!
        defaults.set(legacy, forKey: UserDefaultsWorkspaceStateStore.legacyStorageKey)

        let store = UserDefaultsWorkspaceStateStore(defaults: defaults)
        let state = store.load()

        XCTAssertEqual(state.activeWorkspace, .github)
        XCTAssertEqual(state.controllerWindowFrame, "{{10, 20}, {900, 700}}")
        XCTAssertNil(state.orionWindowFrame)
        XCTAssertEqual(state.setupStage, .notStarted)
        XCTAssertNotNil(defaults.data(forKey: UserDefaultsWorkspaceStateStore.storageKey))
        XCTAssertEqual(defaults.data(forKey: UserDefaultsWorkspaceStateStore.legacyStorageKey), legacy)
    }

    func testV2StateWinsWhenLegacyStateAlsoExists() throws {
        let store = UserDefaultsWorkspaceStateStore(defaults: defaults)
        var current = PersistedWorkspaceState.initial
        current.activeWorkspace = .chatGPT
        current.controllerWindowFrame = "{{1, 2}, {520, 120}}"
        store.save(current)

        let legacy = """
        {"activeWorkspace":"github","windowFrame":"{{10, 20}, {900, 700}}"}
        """.data(using: .utf8)!
        defaults.set(legacy, forKey: UserDefaultsWorkspaceStateStore.legacyStorageKey)

        XCTAssertEqual(store.load(), current)
    }

    func testCorruptV2DataReturnsInitialWithoutRewritingInvalidPayload() {
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
