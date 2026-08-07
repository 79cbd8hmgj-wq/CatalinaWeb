#if os(macOS)
import ApplicationServices
import XCTest
@testable import CatalinaWebApp

final class AccessibilityAuthorizationTests: XCTestCase {
    func testProtocolCanRepresentTrustedAndUntrustedStates() {
        let trusted = FakeAccessibilityAuthorizer(isTrusted: true)
        let untrusted = FakeAccessibilityAuthorizer(isTrusted: false)

        XCTAssertTrue(trusted.isTrusted)
        XCTAssertFalse(untrusted.isTrusted)
    }

    func testFakeTracksPromptAndPreferencesRequests() {
        let authorizer = FakeAccessibilityAuthorizer(isTrusted: false)

        authorizer.requestTrustPrompt()
        authorizer.openAccessibilityPreferences()

        XCTAssertEqual(authorizer.promptRequestCount, 1)
        XCTAssertEqual(authorizer.preferencesRequestCount, 1)
    }
}

private final class FakeAccessibilityAuthorizer: AccessibilityAuthorizing {
    var isTrusted: Bool
    var promptRequestCount = 0
    var preferencesRequestCount = 0

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func requestTrustPrompt() {
        promptRequestCount += 1
    }

    func openAccessibilityPreferences() {
        preferencesRequestCount += 1
    }
}
#endif
