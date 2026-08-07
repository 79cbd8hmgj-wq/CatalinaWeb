# CatalinaWeb Prototype 2 — Orion-Backed Controller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace CatalinaWeb's failed embedded-WebKit prototype with a lightweight AppKit controller that owns exactly two logical workspaces while a dedicated persistent Orion profile performs all web rendering.

**Architecture:** Keep pure workspace/setup/routing state in `CatalinaWebCore`, put all macOS Accessibility and Orion process/window automation behind narrow protocols in `CatalinaWebApp`, and keep the controller UI ignorant of AX implementation details. Prototype 2 uses one dedicated Orion profile, one Orion window, and one active page; every automation action follows identify → act → verify → persist, with explicit refusal when the target cannot be verified.

**Tech Stack:** Swift 5.3, Swift Package Manager, AppKit, ApplicationServices Accessibility (`AXUIElement`), Foundation, `NSWorkspace`, `NSPasteboard`, Dispatch, libproc C shim, POSIX shell; macOS Catalina 10.15.7 / Xcode 12.4 baseline.

## Global Constraints

- Minimum supported OS is macOS Catalina 10.15.7.
- Swift tools version remains 5.3; do not use async/await, actors, modern Observation, or APIs introduced after Catalina without availability guards.
- CatalinaWeb performs no web rendering: no `WKWebView`, legacy `WebView`, hidden browser view, JavaScript injection, or browser extension.
- Use one persistent Orion profile named exactly `CatalinaWeb`.
- Use one dedicated Orion window and one active page at a time.
- Preserve exact valid per-workspace URLs for ChatGPT and GitHub.
- ChatGPT home is `https://chatgpt.com/`; GitHub home is `https://github.com/`.
- Preserve the approved tradeoff that unsent ChatGPT drafts and unsaved GitHub form state may be lost when switching workspaces.
- Primary automation is native Accessibility API (`AXUIElement`); keyboard shortcuts are a fallback only after the dedicated Orion window is positively verified.
- No coordinate-based click automation as a primary mechanism.
- No private Orion APIs, direct Orion profile-file mutation, TLS weakening, privileged/root helper, daemon, or force-killing Orion.
- Accessibility permission is used only for Orion setup/window control.
- CatalinaWeb must never send navigation commands to an unverified Orion window.
- Closing CatalinaWeb must close only the dedicated CatalinaWeb Orion window and must not disturb normal Orion windows.
- External unrelated top-level URLs are rerouted to normal Orion only when that can be done safely.
- Prefer Accessibility notifications; any fallback polling must be low-frequency (1 second or slower) and stop when no dedicated window is connected.
- Diagnostics must not persist page text, messages, form values, credentials, cookies, or authentication tokens.
- Performance success is measured as `CatalinaWeb controller + dedicated Orion profile/window`, not controller RSS alone.

---

## File Structure

### Core model files

- `Sources/CatalinaWebCore/Workspace.swift` — workspace identity and home URLs.
- `Sources/CatalinaWebCore/WorkspaceStateStore.swift` — v2 persistence and v1 migration.
- `Sources/CatalinaWebCore/WorkspaceURLPolicy.swift` — workspace URL validation and external-routing classification.
- `Sources/CatalinaWebCore/OrionSetupState.swift` — first-run setup state machine and persisted profile identity.
- `Sources/CatalinaWebCore/ControllerEvent.swift` — privacy-safe controller/automation events.
- `Sources/CatalinaWebCore/DiagnosticsModels.swift` — Prototype 2 diagnostics snapshot.

### macOS adapter files

- `Sources/CatalinaWebApp/AccessibilityAuthorization.swift` — trust check and System Preferences prompt/opening.
- `Sources/CatalinaWebApp/OrionApplicationLocator.swift` — default Orion and profile-app discovery.
- `Sources/CatalinaWebApp/OrionAccessibilityCatalog.swift` — allowlisted semantic AX menu/control selectors verified on Catalina.
- `Sources/CatalinaWebApp/OrionAccessibilityClient.swift` — typed AX read/action wrapper.
- `Sources/CatalinaWebApp/PasteboardSnapshot.swift` — clipboard-preserving URL fallback support.
- `Sources/CatalinaWebApp/OrionWindowSession.swift` — verified dedicated-window discovery, URL I/O, navigation, close, and geometry.
- `Sources/CatalinaWebApp/OrionProfileSetupCoordinator.swift` — verified first-run profile creation/resume.
- `Sources/CatalinaWebApp/OrionWorkspaceCoordinator.swift` — workspace switching, external routing, Focus Mode, recovery, shutdown.
- `Sources/CatalinaWebApp/ControllerWindowLevelManager.swift` — controller-above-Orion behavior without global floating.
- `Sources/CatalinaWebApp/MainWindowController.swift` — small controller UI only.
- `Sources/CatalinaWebApp/AppDelegate.swift` — lifecycle wiring.
- `Sources/CatalinaWebApp/DiagnosticsCollector.swift` — controller + dedicated Orion metrics.
- `Sources/CatalinaWebApp/ExternalBrowserOpener.swift` — normal/default Orion external opening.

### Scripts and docs

- `scripts/orion_accessibility_probe.swift` — read-only Catalina AX evidence probe.
- `scripts/tests/test_orion_accessibility_probe_source.sh` — probe safety contract.
- `scripts/tests/test_orion_controller_security_contract.sh` — forbids embedded WebKit/private automation/privileged browser control.
- `scripts/benchmark_snapshot.sh` — Prototype 2 process-family measurement.
- `docs/testing/orion-backed-validation-procedure.md` — functional/lifecycle/performance gate.

### Prototype 1 files removed from production at the cleanup task

- `Sources/CatalinaWebApp/WebViewController.swift`
- `Sources/CatalinaWebApp/WebViewNavigationDelegate.swift`
- `Sources/CatalinaWebApp/WebViewUIDelegate.swift`
- `Sources/CatalinaWebApp/FailureOverlayView.swift`
- `Sources/CatalinaWebCore/WebViewRecoveryState.swift`
- corresponding WebKit-specific macOS/core tests and obsolete WebKit source-contract script.

---

### Task 1: Persist Prototype 2 workspace, setup, and geometry state

**Files:**
- Modify: `Sources/CatalinaWebCore/Workspace.swift`
- Modify: `Sources/CatalinaWebCore/WorkspaceStateStore.swift`
- Create: `Sources/CatalinaWebCore/OrionSetupState.swift`
- Modify: `Tests/CatalinaWebCoreTests/WorkspaceTests.swift`
- Modify: `Tests/CatalinaWebCoreTests/WorkspaceStateStoreTests.swift`
- Create: `Tests/CatalinaWebCoreTests/OrionSetupStateTests.swift`

**Interfaces:**
- Produces: `OrionSetupStage`, `OrionProfileIdentity`, `PersistedWorkspaceState` v2 fields, and v1 → v2 migration.
- Consumes: existing `Workspace` and `WorkspaceStateStoring` APIs.

- [ ] **Step 1: Write failing v2 state and migration tests**

Add tests that assert the initial state and v1 migration:

```swift
func testInitialStateStartsUnconfiguredWithChatGPTHomeFallback() {
    let state = PersistedWorkspaceState.initial
    XCTAssertEqual(state.activeWorkspace, .chatGPT)
    XCTAssertEqual(state.setupStage, .notStarted)
    XCTAssertNil(state.orionProfileIdentity)
    XCTAssertNil(state.controllerWindowFrame)
    XCTAssertNil(state.orionWindowFrame)
}

func testV1StateMigratesWindowFrameToControllerFrame() throws {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let legacy = """
    {"activeWorkspace":"github","windowFrame":"{{10, 20}, {900, 700}}"}
    """.data(using: .utf8)!
    defaults.set(legacy, forKey: UserDefaultsWorkspaceStateStore.legacyStorageKey)

    let store = UserDefaultsWorkspaceStateStore(defaults: defaults)
    let state = store.load()

    XCTAssertEqual(state.activeWorkspace, .github)
    XCTAssertEqual(state.controllerWindowFrame, "{{10, 20}, {900, 700}}")
    XCTAssertEqual(state.setupStage, .notStarted)
}
```

- [ ] **Step 2: Run the core tests and verify failure**

Run:

```bash
swift test --filter WorkspaceTests
swift test --filter WorkspaceStateStoreTests
swift test --filter OrionSetupStateTests
```

Expected: compile/test failures because the v2 setup and geometry fields do not yet exist.

- [ ] **Step 3: Add the v2 setup models**

Create:

```swift
public enum OrionSetupStage: String, Codable, Equatable {
    case notStarted
    case accessibilityAuthorized
    case profileCreated
    case profileVerified
    case windowVerified
    case focusModeVerified
    case complete
}

public struct OrionProfileIdentity: Codable, Equatable {
    public let applicationURL: URL
    public let bundleIdentifier: String?
    public let localizedName: String

    public init(applicationURL: URL, bundleIdentifier: String?, localizedName: String) {
        self.applicationURL = applicationURL
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
    }
}
```

Expand `PersistedWorkspaceState` with:

```swift
public var controllerWindowFrame: String?
public var orionWindowFrame: String?
public var lastChatGPTActivatedAt: Date?
public var lastGitHubActivatedAt: Date?
public var setupStage: OrionSetupStage
public var orionProfileIdentity: OrionProfileIdentity?
```

Add:

```swift
public mutating func markActivated(_ workspace: Workspace, at date: Date)
```

- [ ] **Step 4: Implement explicit v1 migration in the state store**

Use two keys:

```swift
public static let storageKey = "CatalinaWeb.workspaceState.v2"
public static let legacyStorageKey = "CatalinaWeb.workspaceState.v1"
```

Load v2 first. If absent, decode a private `LegacyPersistedWorkspaceStateV1`, translate `windowFrame` into `controllerWindowFrame`, save v2 once, and leave the legacy key untouched for rollback/debugging.

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter Workspace
swift test --filter OrionSetupState
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/CatalinaWebCore Tests/CatalinaWebCoreTests
git commit -m "feat: add Orion-backed persistent state"
```

---

### Task 2: Replace embedded-browser navigation policy with workspace URL policy and controller events

**Files:**
- Create: `Sources/CatalinaWebCore/WorkspaceURLPolicy.swift`
- Create: `Sources/CatalinaWebCore/ControllerEvent.swift`
- Create: `Tests/CatalinaWebCoreTests/WorkspaceURLPolicyTests.swift`
- Create: `Tests/CatalinaWebCoreTests/ControllerEventTests.swift`
- Modify: `Sources/CatalinaWebCore/NavigationPolicy.swift` only to deprecate/remove after callers migrate in Task 12.

**Interfaces:**
- Produces: `WorkspaceURLPolicy.classification(of:for:) -> WorkspaceURLClassification`, `ControllerEvent`, `ControllerEventRecording`.
- Consumes: `Workspace`.

- [ ] **Step 1: Write failing policy tests**

Cover exact workspace URL classification:

```swift
func testChatGPTURLIsInternalOnlyForChatGPTWorkspace() {
    let policy = WorkspaceURLPolicy()
    let url = URL(string: "https://chatgpt.com/c/abc")!
    XCTAssertEqual(policy.classification(of: url, for: .chatGPT), .workspaceInternal)
    XCTAssertEqual(policy.classification(of: url, for: .github), .external)
}

func testGitHubURLIsInternalOnlyForGitHubWorkspace() {
    let policy = WorkspaceURLPolicy()
    let url = URL(string: "https://github.com/79cbd8hmgj-wq/CatalinaWeb/pull/1")!
    XCTAssertEqual(policy.classification(of: url, for: .github), .workspaceInternal)
    XCTAssertEqual(policy.classification(of: url, for: .chatGPT), .external)
}

func testHTTPAndUnsupportedSchemesAreNeverWorkspaceInternal() {
    let policy = WorkspaceURLPolicy()
    XCTAssertEqual(policy.classification(of: URL(string: "http://github.com")!, for: .github), .external)
    XCTAssertEqual(policy.classification(of: URL(string: "javascript:alert(1)")!, for: .github), .unsupported)
}
```

Also cover evidence-driven auth hosts as explicit constructor input rather than hardcoded broad domains.

- [ ] **Step 2: Run the test and verify failure**

```bash
swift test --filter WorkspaceURLPolicyTests
```

Expected: FAIL because `WorkspaceURLPolicy` does not exist.

- [ ] **Step 3: Implement the policy**

Create:

```swift
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
        self.chatGPTAuthenticationHosts = chatGPTAuthenticationHosts
        self.githubAuthenticationHosts = githubAuthenticationHosts
    }

    public func classification(of url: URL, for workspace: Workspace) -> WorkspaceURLClassification
    public func isValidSavedURL(_ url: URL, for workspace: Workspace) -> Bool
}
```

Only HTTPS URLs under `chatgpt.com` or `github.com` count as workspace-internal. Auth hosts must be passed explicitly from verified Catalina testing; they are not guessed in core code.

Add privacy-safe events now so later coordinators do not depend on Prototype 1 browser events:

```swift
public enum ControllerEvent: Equatable {
    case workspaceSwitched(from: Workspace, to: Workspace)
    case orionWindowConnected(pid: Int32)
    case orionWindowDisconnected
    case externalNavigationRerouted(host: String, workspace: Workspace)
    case automationFailed(operation: String, description: String)
    case setupStageChanged(OrionSetupStage)
}

public protocol ControllerEventRecording: AnyObject {
    func record(_ event: ControllerEvent)
}

public final class NullControllerEventRecorder: ControllerEventRecording {
    public init() {}
    public func record(_ event: ControllerEvent) {}
}
```

- [ ] **Step 4: Run tests and commit**

```bash
swift test --filter WorkspaceURLPolicyTests
swift test --filter ControllerEventTests
git add Sources/CatalinaWebCore Tests/CatalinaWebCoreTests
git commit -m "feat: add workspace URL policy"
```

---

### Task 3: Add Accessibility authorization and Orion application discovery boundaries

**Files:**
- Create: `Sources/CatalinaWebApp/AccessibilityAuthorization.swift`
- Create: `Sources/CatalinaWebApp/OrionApplicationLocator.swift`
- Create: `Tests/CatalinaWebMacTests/AccessibilityAuthorizationTests.swift`
- Create: `Tests/CatalinaWebMacTests/OrionApplicationLocatorTests.swift`

**Interfaces:**
- Produces: `AccessibilityAuthorizing`, `OrionApplicationLocating`, `LocatedOrionApplication`.
- Consumes: AppKit/Foundation only; no AX navigation yet.

- [ ] **Step 1: Write protocol-level tests with fakes**

Define expected APIs in the tests:

```swift
protocol AccessibilityAuthorizing: AnyObject {
    var isTrusted: Bool { get }
    func requestTrustPrompt()
    func openAccessibilityPreferences()
}

struct LocatedOrionApplication: Equatable {
    let url: URL
    let bundleIdentifier: String?
    let localizedName: String
}

protocol OrionApplicationLocating: AnyObject {
    func locateDefaultOrion() -> LocatedOrionApplication?
    func locateDedicatedProfile(matching identity: OrionProfileIdentity?) -> LocatedOrionApplication?
}
```

Test `/Applications/Orion.app` before `~/Applications/Orion.app`, and test that a dedicated profile lookup refuses a normal Orion app when a persisted identity is present but does not match.

- [ ] **Step 2: Run macOS tests and verify failure**

```bash
swift test --filter AccessibilityAuthorizationTests
swift test --filter OrionApplicationLocatorTests
```

Expected: FAIL because adapters do not exist.

- [ ] **Step 3: Implement Catalina-safe authorization**

Use `AXIsProcessTrusted()` for passive checks and `AXIsProcessTrustedWithOptions` only from `requestTrustPrompt()`:

```swift
final class SystemAccessibilityAuthorizer: AccessibilityAuthorizing {
    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestTrustPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 4: Implement Orion discovery without mutating profile files**

`SystemOrionApplicationLocator` may inspect app bundles and running applications, but it must not edit Orion profile storage. Match persisted dedicated identity by resolved application URL first, then bundle identifier + localized name as corroborating signals.

- [ ] **Step 5: Run tests and commit**

```bash
swift test --filter AccessibilityAuthorizationTests
swift test --filter OrionApplicationLocatorTests
git add Sources/CatalinaWebApp Tests/CatalinaWebMacTests
git commit -m "feat: add Orion discovery and accessibility authorization"
```

---

### Task 4: Build a read-only Orion Accessibility probe and freeze the semantic selector catalog

**Files:**
- Create: `scripts/orion_accessibility_probe.swift`
- Create: `scripts/tests/test_orion_accessibility_probe_source.sh`
- Create: `docs/testing/orion-accessibility-probe.md`
- Create after Catalina capture: `Tests/Fixtures/orion-catalina-accessibility-summary.txt`

**Interfaces:**
- Produces: verified role/title/menu evidence for `OrionAccessibilityCatalog` in Task 5.
- Consumes: a running normal Orion instance; makes no AX actions.

- [ ] **Step 1: Write the source safety test first**

The shell test must fail if the probe contains mutation APIs:

```sh
PROHIBITED='AXUIElementPerformAction|CGEventPost|NSPasteboard|setAttributeValue|defaults write|killall|pkill'
if grep -En "$PROHIBITED" scripts/orion_accessibility_probe.swift; then
  echo "FAIL: probe contains mutation behavior" >&2
  exit 1
fi

grep -Fq 'kAXRoleAttribute' scripts/orion_accessibility_probe.swift
grep -Fq 'kAXTitleAttribute' scripts/orion_accessibility_probe.swift
grep -Fq 'kAXWindowsAttribute' scripts/orion_accessibility_probe.swift
```

- [ ] **Step 2: Run test and verify failure**

```bash
/bin/sh scripts/tests/test_orion_accessibility_probe_source.sh
```

Expected: FAIL because the probe is absent.

- [ ] **Step 3: Implement the read-only probe**

The probe must:

```swift
let app = AXUIElementCreateApplication(pid)
// Read only: role, subrole, title, description, identifier, enabled, children,
// menu bar items, windows, toolbar/address-like elements, and menu item titles.
```

Print a bounded tree depth and redact all `AXValue` text fields except values that parse as `http`/`https` URLs; never print webpage static text.

- [ ] **Step 4: Run source contract and compile probe**

```bash
/bin/sh scripts/tests/test_orion_accessibility_probe_source.sh
xcrun swiftc scripts/orion_accessibility_probe.swift -o /tmp/orion_accessibility_probe -framework AppKit -framework ApplicationServices
```

Expected: PASS and successful compile on Catalina/Xcode 12.4.

- [ ] **Step 5: Catalina evidence checkpoint**

On the Catalina Mac, launch Orion normally and run:

```bash
/tmp/orion_accessibility_probe > "$HOME/Desktop/orion-catalina-accessibility.txt"
```

Before Task 5 proceeds, manually verify the capture contains semantic evidence for:

- `File` → `Profiles` profile-management path;
- a profile-creation command/control;
- profile-name field and confirmation control;
- `View` menu with either `Enable Focus Mode` or `Disable Focus Mode`;
- Orion browser window identity;
- an address/location element if Orion exposes one.

If any item is absent, Task 5 must encode that capability as unavailable and use only the approved fallback paths; do not invent AX titles.

- [ ] **Step 6: Save only the redacted structural summary fixture and commit**

```bash
git add scripts/orion_accessibility_probe.swift scripts/tests/test_orion_accessibility_probe_source.sh docs/testing/orion-accessibility-probe.md Tests/Fixtures/orion-catalina-accessibility-summary.txt
git commit -m "test: capture Orion accessibility structure"
```

---

### Task 5: Implement typed AX operations and verified dedicated-profile setup

**Files:**
- Create: `Sources/CatalinaWebApp/OrionAccessibilityCatalog.swift`
- Create: `Sources/CatalinaWebApp/OrionAccessibilityClient.swift`
- Create: `Sources/CatalinaWebApp/OrionProfileSetupCoordinator.swift`
- Create: `Tests/CatalinaWebMacTests/OrionAccessibilityClientTests.swift`
- Create: `Tests/CatalinaWebMacTests/OrionProfileSetupCoordinatorTests.swift`

**Interfaces:**
- Consumes: `AccessibilityAuthorizing`, `OrionApplicationLocating`, `WorkspaceStateStoring`, Task 4 verified catalog evidence.
- Produces: `OrionProfileSettingUp.startOrResume(completion:)` and typed AX query/action methods.

- [ ] **Step 1: Write failing setup-state tests**

Use fakes so no test controls real Orion:

```swift
func testSetupStopsBeforeAutomationWhenAccessibilityIsMissing() {
    let authorizer = FakeAccessibilityAuthorizer(isTrusted: false)
    let coordinator = OrionProfileSetupCoordinator(/* fakes */)

    let result = coordinator.startOrResumeSynchronouslyForTesting()

    XCTAssertEqual(result, .needsAccessibilityPermission)
    XCTAssertEqual(fakeAX.actions, [])
}

func testVerifiedExistingProfileSkipsCreation() {
    // persisted identity resolves to the dedicated profile app
    // expected: no File→Profiles creation action
}

func testFailedCreationVerificationDoesNotAdvanceStage() {
    // AX action reports success but profile locator still cannot find CatalinaWeb
    // expected setupStage remains .accessibilityAuthorized
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
swift test --filter OrionProfileSetupCoordinatorTests
```

- [ ] **Step 3: Implement a narrow AX client**

Expose only operations required by the design:

```swift
protocol OrionAccessibilityControlling: AnyObject {
    func findMenuItem(path: [String], in application: AXUIElement) -> AXUIElement?
    func press(_ element: AXUIElement) -> Bool
    func stringValue(of element: AXUIElement, attribute: CFString) -> String?
    func setStringValue(_ value: String, on element: AXUIElement) -> Bool
    func windows(of application: AXUIElement) -> [AXUIElement]
}
```

The production implementation wraps `AXUIElementCopyAttributeValue`, `AXUIElementSetAttributeValue`, and `AXUIElementPerformAction`. Do not expose arbitrary scripting/evaluation.

- [ ] **Step 4: Freeze `OrionAccessibilityCatalog` to verified semantic labels**

At minimum the catalog includes only labels confirmed by the Task 4 fixture. Kagi's documented paths may be represented as:

```swift
struct OrionAccessibilityCatalog {
    let fileMenuTitle = "File"
    let profilesMenuTitle = "Profiles"
    let viewMenuTitle = "View"
    let enableFocusModeTitle = "Enable Focus Mode"
    let disableFocusModeTitle = "Disable Focus Mode"
    let dedicatedProfileName = "CatalinaWeb"
}
```

Profile-creation control titles must come from the saved Catalina fixture; if the fixture did not expose a stable semantic title, automatic creation must return `.profileCreationUnsupported` rather than use coordinates.

- [ ] **Step 5: Implement verified setup transitions**

`startOrResume` performs one transition at a time and saves only after verification:

```swift
switch state.setupStage {
case .notStarted:
    guard authorizer.isTrusted else { return .needsAccessibilityPermission }
    advance(to: .accessibilityAuthorized)
case .accessibilityAuthorized:
    createProfileIfNeeded()
    guard locator.locateDedicatedProfile(matching: nil) != nil else { return .failed(.profileNotVerified) }
    advance(to: .profileCreated)
// continue through profileVerified/windowVerified/focusModeVerified/complete
}
```

Creation sets profile name to exactly `CatalinaWeb`; it does not import extensions/history or modify Orion internal files.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter OrionAccessibilityClientTests
swift test --filter OrionProfileSetupCoordinatorTests
git add Sources/CatalinaWebApp Tests/CatalinaWebMacTests
git commit -m "feat: automate verified Orion profile setup"
```

---

### Task 6: Implement verified dedicated-window identity, URL I/O, and clipboard-preserving fallback

**Files:**
- Create: `Sources/CatalinaWebApp/PasteboardSnapshot.swift`
- Create: `Sources/CatalinaWebApp/OrionWindowSession.swift`
- Create: `Tests/CatalinaWebMacTests/PasteboardSnapshotTests.swift`
- Create: `Tests/CatalinaWebMacTests/OrionWindowSessionTests.swift`

**Interfaces:**
- Produces: `OrionWindowSessionControlling`.
- Consumes: persisted `OrionProfileIdentity`, AX client, `NSRunningApplication`, `WorkspaceURLPolicy`.

- [ ] **Step 1: Write failing identity/refusal tests**

Define:

```swift
struct VerifiedOrionWindow {
    let applicationPID: pid_t
    let applicationURL: URL
    let element: AXUIElement
}

protocol OrionWindowSessionControlling: AnyObject {
    var verifiedWindow: VerifiedOrionWindow? { get }
    func reacquire() -> Bool
    func currentURL() -> URL?
    func navigate(to url: URL) -> Bool
    func perform(_ command: OrionNavigationCommand) -> Bool
    func readFrame() -> String?
    func setFrame(from string: String) -> Bool
    func requestClose() -> Bool
}
```

Tests must prove ambiguous normal/dedicated windows cause `reacquire()` to return false and that no keyboard event is emitted after failed verification.

- [ ] **Step 2: Write clipboard round-trip tests**

`PasteboardSnapshot` captures every pasteboard item/type as `Data` and restores them in the same item order. Test plain text plus a second arbitrary type; do not preserve only `.string`.

- [ ] **Step 3: Implement stable dedicated-window verification**

Verification must require the running app to match persisted dedicated `OrionProfileIdentity` and then select one browser window. Window title alone is insufficient. Persisted application URL is the strongest signal.

- [ ] **Step 4: Implement URL reading**

Preferred path: read the verified address/location AX element from Task 4 evidence.

Fallback path:

```swift
let snapshot = PasteboardSnapshot.capture(.general)
defer { snapshot.restore(to: .general) }

focusVerifiedWindow()
sendCommandL()
sendCommandC()
let candidate = NSPasteboard.general.string(forType: .string)
return candidate.flatMap(URL.init(string:))
```

Never run this fallback until `verifiedWindow != nil`.

- [ ] **Step 5: Implement navigation and browser commands**

`navigate(to:)` uses the verified location element if writable; otherwise use `Cmd-L`, type/paste the URL, and Return. `perform(.back/.forward/.reload)` uses the approved shortcuts only after verification.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter PasteboardSnapshotTests
swift test --filter OrionWindowSessionTests
git add Sources/CatalinaWebApp Tests/CatalinaWebMacTests
git commit -m "feat: control verified Orion window"
```

---

### Task 7: Implement workspace switching and external-navigation rerouting

**Files:**
- Create: `Sources/CatalinaWebApp/OrionWorkspaceCoordinator.swift`
- Create: `Tests/CatalinaWebMacTests/OrionWorkspaceCoordinatorTests.swift`
- Modify: `Sources/CatalinaWebApp/ExternalBrowserOpener.swift`
- Modify: `Tests/CatalinaWebMacTests/ExternalBrowserOpenerTests.swift` if absent, create it.

**Interfaces:**
- Consumes: `OrionWindowSessionControlling`, `WorkspaceStateStoring`, `WorkspaceURLPolicy`, `ExternalBrowserOpening`, `ControllerEventRecording`.
- Produces: `OrionWorkspaceControlling` used by `MainWindowController`.

- [ ] **Step 1: Write failing workspace-switch tests**

Define:

```swift
protocol OrionWorkspaceControlling: AnyObject {
    var activeWorkspace: Workspace { get }
    var connectionState: OrionConnectionState { get }
    func start()
    func switchWorkspace(to workspace: Workspace)
    func goBack()
    func goForward()
    func reload()
    func reopenWorkspace()
    func prepareForShutdown()
}
```

Test exact URL preservation:

```swift
func testSwitchSavesCurrentExactURLBeforeNavigatingDestination() {
    fakeSession.url = URL(string: "https://chatgpt.com/c/abc123")!
    coordinator.switchWorkspace(to: .github)

    XCTAssertEqual(store.state.lastChatGPTURL, URL(string: "https://chatgpt.com/c/abc123")!)
    XCTAssertEqual(fakeSession.navigatedURLs.last, Workspace.github.homeURL)
}
```

Test failed navigation retains the previous destination state and does not mark the new workspace active.

- [ ] **Step 2: Add external-navigation tests**

When active ChatGPT observes `https://example.com/article`:

- save no external URL into ChatGPT state;
- navigate dedicated Orion back to the previous valid ChatGPT URL;
- call `ExternalBrowserOpening.openExternally(exampleURL)` once.

If dedicated-window verification is lost, assert no reroute action occurs.

- [ ] **Step 3: Implement coordinator with notification-first observation**

Use AX value/window notifications when Task 4/6 expose them. Provide a 1-second `DispatchSourceTimer` fallback only while connected and stop it on disconnect/shutdown.

`observeCurrentURL()` must classify the URL through `WorkspaceURLPolicy`, never by substring matching.

- [ ] **Step 4: Make external opening explicitly target normal Orion**

`OrionExternalBrowserOpener` must resolve `/Applications/Orion.app` or `~/Applications/Orion.app`, not the dedicated profile app URL. If normal Orion cannot be resolved, fall back to `NSWorkspace.shared.open(url)`.

- [ ] **Step 5: Run tests and commit**

```bash
swift test --filter OrionWorkspaceCoordinatorTests
swift test --filter ExternalBrowserOpenerTests
git add Sources/CatalinaWebApp Tests/CatalinaWebMacTests
git commit -m "feat: add Orion workspace coordination"
```

---

### Task 8: Add Focus Mode verification, Orion geometry restoration, and controller-above behavior

**Files:**
- Modify: `Sources/CatalinaWebApp/OrionWindowSession.swift`
- Modify: `Sources/CatalinaWebApp/OrionWorkspaceCoordinator.swift`
- Create: `Sources/CatalinaWebApp/ControllerWindowLevelManager.swift`
- Modify: `Tests/CatalinaWebMacTests/OrionWindowSessionTests.swift`
- Create: `Tests/CatalinaWebMacTests/ControllerWindowLevelManagerTests.swift`

**Interfaces:**
- Produces: `FocusModeState`, `ControllerWindowLevelManaging`.
- Consumes: `NSWorkspace.didActivateApplicationNotification`, verified Orion AX menu items, saved Orion frame string.

- [ ] **Step 1: Write failing Focus Mode tests**

Use the documented Orion View-menu distinction:

```swift
XCTAssertEqual(session.focusModeState(), .disabled) // "Enable Focus Mode" exists
XCTAssertEqual(session.focusModeState(), .enabled)  // "Disable Focus Mode" exists
XCTAssertEqual(session.focusModeState(), .unknown)  // neither can be verified
```

Test `ensureFocusMode()` presses only `Enable Focus Mode`; it must never toggle when state is `.unknown`.

- [ ] **Step 2: Write geometry tests**

On successful reacquisition, coordinator applies `state.orionWindowFrame` only when it parses to a non-empty frame intersecting a current screen. Invalid/off-screen saved geometry is ignored.

- [ ] **Step 3: Write controller window-level tests**

Behavior:

```swift
active app == dedicated Orion or CatalinaWeb -> controller.level = .floating
active app == any unrelated app            -> controller.level = .normal
```

This satisfies "above dedicated Orion, not globally above unrelated applications."

- [ ] **Step 4: Implement and verify**

Use `NSWorkspace.shared.notificationCenter` activation notifications. Do not poll foreground apps.

- [ ] **Step 5: Run tests and commit**

```bash
swift test --filter OrionWindowSessionTests
swift test --filter ControllerWindowLevelManagerTests
git add Sources/CatalinaWebApp Tests/CatalinaWebMacTests
git commit -m "feat: manage Orion focus and window lifecycle"
```

---

### Task 9: Replace the embedded browser window with the small native controller UI

**Files:**
- Rewrite: `Sources/CatalinaWebApp/MainWindowController.swift`
- Modify: `Sources/CatalinaWebApp/AppMenuBuilder.swift`
- Modify: `Tests/CatalinaWebMacTests/MainWindowControllerTests.swift`

**Interfaces:**
- Consumes: `OrionWorkspaceControlling`, `AccessibilityAuthorizing`, `ControllerWindowLevelManaging`.
- Produces: button/shortcut actions and status presentation only.

- [ ] **Step 1: Rewrite UI tests before production UI**

Tests must assert:

```swift
XCTAssertEqual(controller.workspaceControl.segmentCount, 2)
XCTAssertEqual(controller.workspaceControl.label(forSegment: 0), "ChatGPT")
XCTAssertEqual(controller.workspaceControl.label(forSegment: 1), "GitHub")
XCTAssertEqual(controller.connectionStatusLabel.stringValue, "Orion: Connected")
XCTAssertNil(controller.window?.contentView?.subviews.first { String(describing: type(of: $0)).contains("WKWebView") })
```

Also verify buttons dispatch to the fake coordinator and `Cmd-1`, `Cmd-2`, `Cmd-[`, `Cmd-]`, `Cmd-R`, `Cmd-W` remain wired.

- [ ] **Step 2: Run tests and verify failure**

```bash
swift test --filter MainWindowControllerTests
```

Expected: FAIL against the old content-container UI.

- [ ] **Step 3: Implement the small controller**

Use a default frame near `520 x 120` and layout:

```text
[ ChatGPT ] [ GitHub ]   [←] [→] [Reload]
Active: ChatGPT          Orion: Connected
```

Do not create a content container. The window remains resizable only if tests/UI review show value; otherwise use titled/closable/miniaturizable with a fixed content size.

- [ ] **Step 4: Add setup/recovery states**

Show actionable states without embedding browser content:

- `Accessibility permission required` + `Open System Preferences`.
- `Setting up CatalinaWeb Orion profile…`.
- `Orion connection lost` + `Reopen Workspace`.
- `Dedicated Orion window could not be verified.`
- `Focus Mode status unavailable.` as nonfatal secondary status.

- [ ] **Step 5: Run tests and commit**

```bash
swift test --filter MainWindowControllerTests
git add Sources/CatalinaWebApp Tests/CatalinaWebMacTests
git commit -m "feat: replace browser view with Orion controller UI"
```

---

### Task 10: Implement launch, recovery, and strict shutdown lifecycle

**Files:**
- Modify: `Sources/CatalinaWebApp/AppDelegate.swift`
- Modify: `Sources/CatalinaWebApp/OrionWorkspaceCoordinator.swift`
- Modify: `Sources/CatalinaWebApp/MainWindowController.swift`
- Create: `Tests/CatalinaWebMacTests/AppLifecycleTests.swift`

**Interfaces:**
- Consumes: setup coordinator, workspace coordinator, state store.
- Produces: deterministic launch/reopen/termination behavior.

- [ ] **Step 1: Write lifecycle tests**

Cover:

```swift
func testLaunchResumesSetupInsteadOfCreatingDuplicateProfile()
func testManualDedicatedWindowClosureLeavesControllerAlive()
func testReopenRestoresSavedWorkspaceURLAndGeometry()
func testShutdownSavesCurrentValidURLBeforeRequestingDedicatedClose()
func testShutdownDoesNotCloseNormalOrionWhenDedicatedIdentityIsMissing()
```

- [ ] **Step 2: Implement launch orchestration**

`AppDelegate.applicationDidFinishLaunching` creates the controller immediately, then begins setup/reacquisition. The UI stays responsive throughout; use completion handlers and Dispatch queues, not blocking loops.

- [ ] **Step 3: Implement strict shutdown**

Before allowing termination:

1. read the current URL if the dedicated window is verified;
2. save it only if valid for the active workspace;
3. save Orion geometry;
4. request close on the verified dedicated window;
5. wait only for a bounded verification interval;
6. terminate CatalinaWeb regardless after the interval.

Never call `terminate`, `kill`, `pkill`, or `killall` on Orion.

- [ ] **Step 4: Run tests and commit**

```bash
swift test --filter AppLifecycleTests
git add Sources/CatalinaWebApp Tests/CatalinaWebMacTests
git commit -m "feat: add Orion-backed app lifecycle"
```

---

### Task 11: Convert diagnostics from WebKit metrics to controller + dedicated Orion metrics

**Files:**
- Modify: `Sources/CatalinaWebCore/ControllerEvent.swift`
- Delete after migration: `Sources/CatalinaWebCore/BrowserEvent.swift`
- Modify: `Sources/CatalinaWebCore/DiagnosticsModels.swift`
- Modify: `Sources/CatalinaWebApp/DiagnosticsCollector.swift`
- Modify: `Sources/CatalinaWebApp/DiagnosticsWindowController.swift`
- Modify: `Tests/CatalinaWebCoreTests/DiagnosticsModelsTests.swift`
- Modify: `Tests/CatalinaWebMacTests/DiagnosticsCollectorTests.swift`

**Interfaces:**
- Consumes: dedicated Orion PID from `OrionWorkspaceControlling`, `cw_read_process_family_metrics(root_pid, ...)`, memory pressure reader.
- Produces: privacy-safe Prototype 2 snapshots/events.

- [ ] **Step 1: Write failing Prototype 2 diagnostics tests**

Snapshot fields:

```swift
public struct DiagnosticsSnapshot: Equatable {
    public let timestamp: Date
    public let activeWorkspace: Workspace
    public let connectionState: OrionConnectionState
    public let accessibilityAuthorized: Bool
    public let focusModeState: FocusModeState
    public let controllerResidentBytes: UInt64?
    public let dedicatedOrionRootPID: Int32?
    public let dedicatedOrionFamilyResidentBytes: UInt64?
    public let dedicatedOrionChildProcessCount: Int?
    public let memoryPressure: MemoryPressureLevel
}
```

Events use the `ControllerEvent` cases created in Task 2. Tests must verify that external navigation records only `url.host` and that automation failure descriptions pass through a redactor that removes URL query/fragment text before storage.

- [ ] **Step 2: Generalize process reader to arbitrary root PID**

Change:

```swift
func readCurrentProcessFamily() -> ProcessFamilyMeasurement
```

to:

```swift
func readProcessFamily(rootPID: Int32) -> ProcessFamilyMeasurement
```

Read CatalinaWeb with `getpid()` and dedicated Orion with its verified root PID. Report unavailable rather than zero on failed attribution.

- [ ] **Step 3: Update diagnostics UI**

Remove `liveWebViewCount` and WebContent termination language. Show controller RSS, dedicated Orion family RSS/count, connection, Accessibility, Focus Mode, workspace, and recent sanitized events.

- [ ] **Step 4: Run tests and commit**

```bash
swift test --filter DiagnosticsModelsTests
swift test --filter DiagnosticsCollectorTests
git add Sources/CatalinaWebCore Sources/CatalinaWebApp Tests
git commit -m "feat: add Orion-backed diagnostics"
```

---

### Task 12: Remove Prototype 1 WebKit production code and enforce the Prototype 2 security/package contract

**Files:**
- Delete: `Sources/CatalinaWebApp/WebViewController.swift`
- Delete: `Sources/CatalinaWebApp/WebViewNavigationDelegate.swift`
- Delete: `Sources/CatalinaWebApp/WebViewUIDelegate.swift`
- Delete: `Sources/CatalinaWebApp/FailureOverlayView.swift`
- Delete: `Sources/CatalinaWebCore/WebViewRecoveryState.swift`
- Delete: `Tests/CatalinaWebMacTests/WebViewControllerTests.swift`
- Delete: `Tests/CatalinaWebMacTests/NavigationDelegateTests.swift`
- Delete: `Tests/CatalinaWebMacTests/WebViewUIDelegateTests.swift`
- Delete: `Tests/CatalinaWebMacTests/DownloadObservationTests.swift`
- Delete: `Tests/CatalinaWebCoreTests/WebViewRecoveryStateTests.swift`
- Delete: `scripts/tests/test_catalina_webkit_bridge_contract.sh`
- Modify/Delete after caller migration: `Sources/CatalinaWebCore/NavigationPolicy.swift`, `Tests/CatalinaWebCoreTests/NavigationPolicyTests.swift`
- Create: `scripts/tests/test_orion_controller_security_contract.sh`
- Modify: `scripts/tests/test_security_contract.sh`
- Modify: `scripts/package_app.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: all Prototype 2 components.
- Produces: build with no production embedded WebKit code.

- [ ] **Step 1: Add the failing Prototype 2 security contract before deleting code**

The script must reject production browser-engine code and dangerous automation:

```sh
PROHIBITED='WKWebView|WKUserScript|import WebKit|WebView\(|developerExtrasEnabled|customUserAgent|AuthorizationExecuteWithPrivileges|sudo|killall Orion|pkill.*Orion'
```

Also require these source markers:

```sh
grep -RFn 'AXIsProcessTrusted' Sources/CatalinaWebApp
grep -RFn 'Dedicated Orion window could not be verified' Sources/CatalinaWebApp
grep -RFn 'CatalinaWeb' Sources/CatalinaWebApp/OrionAccessibilityCatalog.swift

CG_EVENT_FILES=$(grep -RIlF 'CGEventPost' Sources/CatalinaWebApp 2>/dev/null || true)
[ -z "$CG_EVENT_FILES" ] || [ "$CG_EVENT_FILES" = "Sources/CatalinaWebApp/OrionWindowSession.swift" ]
grep -Fq 'guard verifiedWindow != nil' Sources/CatalinaWebApp/OrionWindowSession.swift
```

- [ ] **Step 2: Run security contract and verify failure**

```bash
/bin/sh scripts/tests/test_orion_controller_security_contract.sh
```

Expected: FAIL while Prototype 1 WebKit files still exist.

- [ ] **Step 3: Delete obsolete production/tests and finish caller migration**

Remove the files listed above only after all imports/callers are on Prototype 2 abstractions. Keep Prototype 1 design/history in git and docs; do not erase the historical explanation.

- [ ] **Step 4: Update packaging/README**

Package still targets macOS 10.15. The README must state:

- Orion is a runtime prerequisite;
- Accessibility permission is required;
- CatalinaWeb uses a dedicated persistent Orion profile;
- CatalinaWeb itself does no web rendering;
- Prototype 1 embedded WebKit was rejected after bare `WKWebView` and legacy `WebView` runtime failures.

- [ ] **Step 5: Run complete automated verification**

```bash
/bin/sh scripts/tests/test_catalina_swift53_source.sh
/bin/sh scripts/tests/test_package_contract.sh
/bin/sh scripts/tests/test_security_contract.sh
/bin/sh scripts/tests/test_orion_controller_security_contract.sh
/bin/sh scripts/tests/test_orion_accessibility_probe_source.sh
swift test
swift build --product CatalinaWeb
git diff --check
```

Expected: all shell contracts PASS, all Swift tests PASS, product builds, `git diff --check` silent.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: replace embedded WebKit with Orion controller"
```

---

### Task 13: Run the Catalina functional/lifecycle gate and paired Orion benchmark

**Files:**
- Create: `docs/testing/orion-backed-validation-procedure.md`
- Modify: `scripts/benchmark_snapshot.sh`
- Create: `scripts/tests/test_benchmark_contract.sh`
- Modify: `README.md` only with measured results after validation.

**Interfaces:**
- Consumes: completed Prototype 2 build and packaged app.
- Produces: evidence-backed go/no-go decision.

- [ ] **Step 1: Write the validation document and benchmark contract**

The functional checklist must include all 25 spec gates, with explicit evidence slots for pass/fail and notes. The benchmark script must accept a labeled root PID/application identity rather than assuming CatalinaWeb's descendants are the renderer family.

- [ ] **Step 2: Package on Catalina**

```bash
rm -rf .build build
swift test
swift build --product CatalinaWeb
./scripts/package_app.sh
open build/CatalinaWeb.app
```

- [ ] **Step 3: Validate first-run setup**

On the real Catalina Mac:

1. confirm Accessibility permission flow;
2. confirm exactly one `CatalinaWeb` Orion profile is created;
3. interrupt/relaunch setup once and confirm no duplicate profile;
4. log into ChatGPT and GitHub inside the dedicated profile;
5. quit/relaunch and confirm both sessions persist.

Record failures by exact setup stage; do not patch around unverified AX behavior without returning to systematic debugging.

- [ ] **Step 4: Run the workspace/lifecycle gate**

Perform at least 25 alternating workspace switches and verify:

- exact ChatGPT conversation URL restoration;
- exact GitHub repo/issue/PR URL restoration;
- Back/Forward/Reload;
- uploads/downloads;
- external link rerouting to normal Orion;
- controller-above behavior;
- full-screen behavior;
- manual dedicated-window close + Reopen Workspace;
- CatalinaWeb shutdown closes only the dedicated window;
- normal Orion remains untouched;
- no duplicate profile/window creation.

- [ ] **Step 5: Run the paired benchmark**

Use the same sites, same authenticated accounts, same window size, same workload, and equivalent cache state for:

```text
A: normal Orion workflow
B: CatalinaWeb controller + dedicated CatalinaWeb Orion profile
```

Capture:

- controller RSS;
- normal/dedicated Orion root + descendant RSS;
- total relevant browser-family RSS;
- idle CPU;
- swap before/after a fixed session;
- WindowServer CPU/RSS snapshot;
- cold launch time;
- ChatGPT ↔ GitHub switch latency;
- responsiveness after a long session.

Run at least three alternating A/B pairs; do not compare one warm run against one cold run.

- [ ] **Step 6: Apply the go/no-go rule**

Prototype 2 is a **GO** only if the full functional gate passes and the combined workflow provides a meaningful resource or usability advantage over normal Orion. Controller-only low RSS is not sufficient.

If resource behavior is effectively the same and the workflow is not materially better, record Prototype 2 as **NO-GO** and stop rather than expanding scope.

- [ ] **Step 7: Final verification before completion claim**

```bash
/bin/sh scripts/tests/test_orion_controller_security_contract.sh
/bin/sh scripts/tests/test_benchmark_contract.sh
swift test
swift build --product CatalinaWeb
git diff --check
git status --short
```

Then follow `superpowers:verification-before-completion` and `superpowers:finishing-a-development-branch` before marking the implementation ready to merge.

- [ ] **Step 8: Commit validation tooling/results**

```bash
git add docs/testing/orion-backed-validation-procedure.md scripts/benchmark_snapshot.sh scripts/tests/test_benchmark_contract.sh README.md
git commit -m "test: validate Orion-backed CatalinaWeb prototype"
```
