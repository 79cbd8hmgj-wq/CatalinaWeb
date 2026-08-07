import XCTest
@testable import CatalinaWebCore

final class NavigationPolicyTests: XCTestCase {
    private let policy = NavigationPolicy()

    func testChatGPTWorkspaceHostMatrix() {
        XCTAssertEqual(decision("https://chatgpt.com/c/123", workspace: .chatGPT), .allowInternal)
        XCTAssertEqual(decision("https://auth.openai.com/login", workspace: .chatGPT), .allowInternal)
        XCTAssertEqual(decision("https://github.com/79cbd8hmgj-wq/CatalinaWeb", workspace: .chatGPT), .openExternal)
    }

    func testGitHubWorkspaceHostMatrix() {
        XCTAssertEqual(decision("https://github.com/79cbd8hmgj-wq/CatalinaWeb", workspace: .github), .allowInternal)
        XCTAssertEqual(decision("https://raw.githubusercontent.com/79cbd8hmgj-wq/CatalinaWeb/main/README.md", workspace: .github), .allowInternal)
        XCTAssertEqual(decision("https://objects.githubusercontent.com/example/archive.zip", workspace: .github), .allowInternal)
        XCTAssertEqual(decision("https://chatgpt.com/", workspace: .github), .openExternal)
    }

    func testUnrelatedAndSpecialSchemes() {
        XCTAssertEqual(decision("https://example.com/", workspace: .chatGPT), .openExternal)
        XCTAssertEqual(decision("mailto:test@example.com", workspace: .github), .openExternal)
        XCTAssertEqual(decision("javascript:alert(1)", workspace: .chatGPT), .rejectUnsupportedScheme)
    }

    func testBlobRequiresTrustedSourceURL() {
        let trustedSource = URL(string: "https://chatgpt.com/c/123")!
        let blob = URL(string: "blob:https://chatgpt.com/7f45365b-943c-44f8-87c8-0ae6fa4da11b")!

        let trusted = NavigationContext(
            destinationURL: blob,
            sourceURL: trustedSource,
            workspace: .chatGPT,
            isMainFrame: true,
            isUserInitiated: true
        )
        XCTAssertEqual(policy.decision(for: trusted), .allowInternal)

        let untrusted = NavigationContext(
            destinationURL: blob,
            sourceURL: nil,
            workspace: .chatGPT,
            isMainFrame: true,
            isUserInitiated: true
        )
        XCTAssertEqual(policy.decision(for: untrusted), .rejectUnsupportedScheme)
    }

    func testNonMainFrameHTTPSIsAllowedWithoutTopLevelClassification() {
        let context = NavigationContext(
            destinationURL: URL(string: "https://cdn.example.com/resource")!,
            sourceURL: URL(string: "https://chatgpt.com/")!,
            workspace: .chatGPT,
            isMainFrame: false,
            isUserInitiated: false
        )
        XCTAssertEqual(policy.decision(for: context), .allowInternal)
    }

    func testHostMatchingIsSuffixSafe() {
        XCTAssertEqual(decision("https://evilchatgpt.com/", workspace: .chatGPT), .openExternal)
        XCTAssertEqual(decision("https://github.com.evil.example/", workspace: .github), .openExternal)
        XCTAssertEqual(decision("https://sub.chatgpt.com/", workspace: .chatGPT), .allowInternal)
        XCTAssertEqual(decision("https://api.github.com/", workspace: .github), .allowInternal)
    }

    private func decision(_ rawURL: String, workspace: Workspace) -> NavigationDecision {
        let context = NavigationContext(
            destinationURL: URL(string: rawURL)!,
            sourceURL: nil,
            workspace: workspace,
            isMainFrame: true,
            isUserInitiated: true
        )
        return policy.decision(for: context)
    }
}
