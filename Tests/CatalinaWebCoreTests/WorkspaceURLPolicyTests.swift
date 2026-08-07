import XCTest
@testable import CatalinaWebCore

final class WorkspaceURLPolicyTests: XCTestCase {
    func testChatGPTURLIsInternalOnlyForChatGPTWorkspace() {
        let policy = WorkspaceURLPolicy()
        let url = URL(string: "https://chatgpt.com/c/abc")!

        XCTAssertEqual(policy.classification(of: url, for: .chatGPT), .workspaceInternal)
        XCTAssertEqual(policy.classification(of: url, for: .github), .external)
    }

    func testChatGPTSubdomainIsInternalForChatGPTWorkspace() {
        let policy = WorkspaceURLPolicy()
        let url = URL(string: "https://foo.chatgpt.com/path")!

        XCTAssertEqual(policy.classification(of: url, for: .chatGPT), .workspaceInternal)
    }

    func testGitHubURLIsInternalOnlyForGitHubWorkspace() {
        let policy = WorkspaceURLPolicy()
        let url = URL(string: "https://github.com/79cbd8hmgj-wq/CatalinaWeb/pull/1")!

        XCTAssertEqual(policy.classification(of: url, for: .github), .workspaceInternal)
        XCTAssertEqual(policy.classification(of: url, for: .chatGPT), .external)
    }

    func testHTTPAndUnsupportedSchemesAreNeverWorkspaceInternal() {
        let policy = WorkspaceURLPolicy()

        XCTAssertEqual(
            policy.classification(of: URL(string: "http://github.com")!, for: .github),
            .external
        )
        XCTAssertEqual(
            policy.classification(of: URL(string: "javascript:alert(1)")!, for: .github),
            .unsupported
        )
    }

    func testEvidenceDrivenAuthenticationHostsAreExplicit() {
        let policy = WorkspaceURLPolicy(
            chatGPTAuthenticationHosts: ["auth.example.test"],
            githubAuthenticationHosts: ["github-auth.example.test"]
        )

        XCTAssertEqual(
            policy.classification(of: URL(string: "https://auth.example.test/login")!, for: .chatGPT),
            .authentication
        )
        XCTAssertEqual(
            policy.classification(of: URL(string: "https://auth.example.test/login")!, for: .github),
            .external
        )
        XCTAssertEqual(
            policy.classification(of: URL(string: "https://github-auth.example.test/login")!, for: .github),
            .authentication
        )
    }

    func testSavedURLMustBeHTTPSWorkspaceInternalNotAuthentication() {
        let policy = WorkspaceURLPolicy(chatGPTAuthenticationHosts: ["auth.example.test"])

        XCTAssertTrue(
            policy.isValidSavedURL(URL(string: "https://chatgpt.com/c/abc")!, for: .chatGPT)
        )
        XCTAssertFalse(
            policy.isValidSavedURL(URL(string: "https://auth.example.test/login")!, for: .chatGPT)
        )
        XCTAssertFalse(
            policy.isValidSavedURL(URL(string: "http://chatgpt.com/c/abc")!, for: .chatGPT)
        )
    }

    func testHostMatchingDoesNotAcceptSuffixConfusion() {
        let policy = WorkspaceURLPolicy()

        XCTAssertEqual(
            policy.classification(of: URL(string: "https://notchatgpt.com/")!, for: .chatGPT),
            .external
        )
        XCTAssertEqual(
            policy.classification(of: URL(string: "https://github.com.example.test/")!, for: .github),
            .external
        )
    }
}
