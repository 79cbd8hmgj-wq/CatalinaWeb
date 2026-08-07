# CatalinaWeb Prototype 2 — Orion-Backed Controller Design

Date: 2026-08-07
Status: Approved design
Branch: `agent/orion-backed-design`

## 1. Purpose

CatalinaWeb Prototype 2 replaces the failed embedded-WebKit rendering architecture with a lightweight native AppKit controller that delegates all web rendering to a dedicated persistent Orion profile.

The product remains intentionally narrow: exactly two workspaces, ChatGPT and GitHub, on macOS Catalina 10.15.7.

CatalinaWeb itself performs no web rendering. Orion owns page rendering, authentication, cookies, uploads, downloads, modern-site compatibility, and browser process management. CatalinaWeb owns workspace state, window lifecycle, navigation controls, Orion automation, diagnostics, and the low-overhead specialized user experience.

## 2. Why Prototype 1 is not the implementation base

Prototype 1 used Catalina `WKWebView` directly. Runtime testing established two separate classes of failure:

1. A Catalina-specific `NSURLRequest` bridging trap caused an `EXC_BAD_INSTRUCTION` when reading `navigationAction.sourceFrame.request.url`; that crash was fixed by using `webView.url` instead.
2. Even after the crash fix, modern sites did not render correctly in embedded WebKit.

The rendering failure reproduced outside CatalinaWeb in both:

- a completely bare `WKWebView` smoke test, and
- the deprecated legacy `WebView` API.

GitHub was already affected before any ChatGPT-specific user-agent work. User-agent experiments also failed to restore correct rendering. Safari and Orion on the same Catalina installation render the target sites correctly.

Therefore Prototype 2 treats the embedded-WebKit architecture as a documented no-go rather than continuing to layer compatibility workarounds onto it.

Prototype 1 remains preserved in Git history and the draft PR as evidence and diagnostic history.

## 3. Product scope

CatalinaWeb Prototype 2 provides:

- one small native controller window;
- one dedicated persistent Orion profile named `CatalinaWeb`;
- one dedicated Orion content window;
- one active rendering surface at a time;
- two logical workspaces: ChatGPT and GitHub;
- exact per-workspace URL restoration;
- Back, Forward, and Reload controls;
- keyboard shortcuts;
- automatic first-run Orion profile setup;
- Focus Mode control;
- Orion window geometry persistence;
- external-link rerouting to normal Orion;
- strict dedicated-window identity verification;
- lifecycle and performance diagnostics.

CatalinaWeb does not provide:

- an address bar;
- arbitrary tabs;
- bookmarks;
- browser history UI;
- extension management;
- general-purpose browsing;
- its own cookie or credential store;
- injected JavaScript;
- an Orion extension;
- private Orion APIs;
- force-kill behavior for Orion.

## 4. Architecture

```text
CatalinaWeb.app
|
+-- Controller Window
|   +-- ChatGPT
|   +-- GitHub
|   +-- Back
|   +-- Forward
|   +-- Reload
|
+-- Workspace State
|   +-- last ChatGPT URL
|   +-- last GitHub URL
|   +-- active workspace
|   +-- Orion window geometry
|   +-- controller window geometry
|
+-- Orion Automation
|   +-- dedicated-profile discovery
|   +-- Accessibility authorization
|   +-- AXUIElement inspection/control
|   +-- URL navigation
|   +-- Focus Mode control
|   +-- window positioning
|   +-- external-navigation handling
|   +-- lifecycle verification
|
+-- Diagnostics
    +-- controller RSS
    +-- best-effort dedicated Orion process-family RSS
    +-- automation events/failures
    +-- workspace and window state

Orion
+-- Dedicated persistent `CatalinaWeb` profile
    +-- one window
        +-- one active page
```

CatalinaWeb never embeds Orion's content view. Orion remains a normal macOS application and owns its own renderer processes.

## 5. Orion profile model

Prototype 2 uses a dedicated persistent Orion profile named `CatalinaWeb`.

The profile is isolated from the user's normal Orion browsing environment. It exists only for ChatGPT and GitHub.

The profile is persistent so that:

- ChatGPT login survives relaunches;
- GitHub login survives relaunches;
- normal site cookies and storage remain inside Orion;
- CatalinaWeb never stores passwords, session cookies, or authentication tokens.

The implementation must not intentionally use the user's normal Orion profile for the CatalinaWeb workspaces.

## 6. First-run setup

First-run setup is a verified state machine, not a blind macro sequence.

```text
Orion installed
    -> Accessibility authorized
    -> dedicated CatalinaWeb profile created
    -> dedicated profile positively identified
    -> one dedicated Orion window opened
    -> Focus Mode enabled or verified
    -> ChatGPT loaded
    -> setup complete
```

Each completed step is persisted only after its result is verified.

If setup is interrupted, the next launch resumes from the first unverified step rather than creating duplicate profiles or windows.

### 6.1 Accessibility permission

CatalinaWeb requires macOS Accessibility permission for Orion automation.

If permission is unavailable, CatalinaWeb presents a clear setup state and an action to open the relevant System Preferences pane. No Orion automation occurs until permission is granted.

### 6.2 Automation mechanism

Primary mechanism:

- native macOS Accessibility APIs using `AXUIElement`.

Permitted fallback:

- targeted keyboard commands where Orion does not expose a reliable Accessibility action.

The fallback may use normal shortcuts such as `Cmd-L`, `Cmd-C`, `Cmd-R`, `Cmd-[`, and `Cmd-]`, but only after the dedicated Orion window has been positively identified.

CatalinaWeb must not use coordinate-based click automation as its primary control mechanism.

## 7. Dedicated Orion window identity

Automation is permitted only when CatalinaWeb can positively identify the dedicated `CatalinaWeb` Orion window/profile environment.

Identity evidence may include a combination of:

- owning process/application identity;
- profile-specific application identity exposed by Orion/macOS;
- window title or accessibility metadata;
- process path or bundle metadata;
- persisted setup identity data;
- verified relationship to the dedicated profile launcher/window created during setup.

The implementation must prefer stable identity signals over window position, z-order, or title text alone.

If identity cannot be established confidently, CatalinaWeb performs no navigation or window automation and reports:

`Dedicated Orion window could not be verified.`

It must never send workspace/navigation keystrokes to an arbitrary Orion window.

## 8. Workspace state

There are exactly two logical workspaces:

- ChatGPT
- GitHub

Each workspace stores:

- the last valid committed top-level URL;
- the last successful activation time.

Home URLs:

- ChatGPT: `https://chatgpt.com/`
- GitHub: `https://github.com/`

The active workspace is persisted across CatalinaWeb relaunches.

## 9. Workspace switching

The dedicated Orion profile has one window and one active page.

When the user activates ChatGPT or GitHub through a button or shortcut:

1. Read the current Orion URL.
2. Validate that it belongs to the currently active workspace.
3. Save the exact valid URL for that workspace.
4. Resolve the destination workspace URL from saved state.
5. Fall back to the workspace home URL if no valid saved URL exists.
6. Navigate the dedicated Orion window to that URL.
7. Verify that the destination workspace was reached.
8. Update the selected workspace state.

No attempt is made to preserve unsent DOM state. An unsent ChatGPT draft or unsaved GitHub form may be lost when switching workspaces. This is an explicit tradeoff in favor of a single active renderer/window.

## 10. URL acquisition

Preferred URL acquisition:

1. Read Orion's accessible address/location element through Accessibility APIs.

Fallback URL acquisition, only if necessary:

1. Save the current clipboard contents.
2. Positively identify and focus the dedicated Orion window.
3. Send `Cmd-L`.
4. Send `Cmd-C`.
5. Read the clipboard value.
6. Validate it as a URL.
7. Restore the prior clipboard contents.
8. Restore the intended focus state.

Clipboard contents are never trusted without URL parsing and workspace validation.

## 11. Navigation controls

The native controller exposes:

- ChatGPT
- GitHub
- Back
- Forward
- Reload

Keyboard shortcuts:

- `Cmd-1`: ChatGPT
- `Cmd-2`: GitHub
- `Cmd-[`: Back
- `Cmd-]`: Forward
- `Cmd-R`: Reload
- `Cmd-W`: close CatalinaWeb and its dedicated Orion window

Back, Forward, and Reload are dispatched only to the positively identified dedicated Orion window.

## 12. External navigation

The dedicated profile is logically restricted to ChatGPT and GitHub.

### 12.1 Workspace-related destinations

ChatGPT may use:

- `chatgpt.com`;
- OpenAI authentication destinations encountered during login and required to complete authentication.

GitHub may use:

- `github.com`;
- GitHub authentication destinations encountered during login and required to complete authentication.

The implementation must use evidence-driven allowlisting for authentication flows rather than broad speculative domain expansion.

### 12.2 Unrelated destinations

Unrelated top-level destinations should open in the user's normal Orion browsing environment.

Because Prototype 2 intentionally uses no Orion extension and no injected browser script, this routing is post-navigation observation rather than browser-engine-level interception.

When an unrelated URL is detected:

1. Capture the external URL.
2. Preserve the last valid CatalinaWeb workspace URL.
3. Navigate the dedicated Orion window back to the previous valid workspace URL.
4. Open the external URL in normal Orion.
5. Leave the saved CatalinaWeb workspace URL unchanged.

A foreign page may begin loading briefly before rerouting.

If rerouting cannot be performed safely, CatalinaWeb leaves the page alone rather than risking automation against the wrong Orion window.

## 13. Controller window

The native controller is intentionally small.

Conceptual layout:

```text
+------------------------------------------------+
| CatalinaWeb                                    |
|                                                |
| [ ChatGPT ] [ GitHub ]   [<-] [->] [Reload]  |
|                                                |
| Active: ChatGPT                                |
| Orion: Connected                               |
+------------------------------------------------+
```

The active workspace button is visually distinguished.

The controller remembers its own position.

The controller stays above the dedicated Orion window during normal desktop use, but it must not become a global always-on-top panel above unrelated applications.

## 14. Orion window geometry

CatalinaWeb remembers and restores the dedicated Orion window's last known size and position.

The user remains free to move and resize the Orion window normally.

CatalinaWeb does not force a fixed layout on each launch.

Full-screen Orion is allowed. CatalinaWeb does not attempt to force its controller above a full-screen Space. When Orion exits full screen, normal controller behavior resumes.

## 15. Focus Mode

The dedicated Orion window should operate in Orion Focus Mode to minimize browser chrome.

CatalinaWeb verifies Focus Mode during:

- dedicated profile launch;
- window reacquisition;
- recovery after the dedicated window is reopened.

If Focus Mode is verifiably disabled, CatalinaWeb may invoke Orion's normal Focus Mode command/shortcut.

If Focus Mode state cannot be verified, CatalinaWeb leaves Orion usable and reports:

`Focus Mode status unavailable.`

It must not repeatedly toggle Focus Mode blindly.

## 16. Launch lifecycle

### 16.1 Normal launch

```text
Launch CatalinaWeb
    -> verify Accessibility authorization
    -> locate or launch dedicated CatalinaWeb Orion profile
    -> positively identify its single window
    -> restore Orion window geometry
    -> restore last active workspace and exact URL
    -> verify Focus Mode if possible
    -> show controller above the dedicated Orion window
```

### 16.2 Unexpected Orion closure

If the dedicated Orion window closes or becomes unavailable unexpectedly, CatalinaWeb remains alive and presents a recoverable state such as:

`Orion connection lost`

with:

`Reopen Workspace`

Reopen Workspace:

1. launches or reacquires the dedicated profile;
2. verifies the dedicated window;
3. restores geometry;
4. restores the saved workspace URL;
5. restores or verifies Focus Mode;
6. resumes normal controls.

There is no automatic restart loop.

## 17. Shutdown lifecycle

Closing CatalinaWeb follows this sequence:

1. Read and validate the current dedicated Orion URL.
2. Save the active workspace's last valid URL.
3. Save dedicated Orion window geometry.
4. Request closure of the dedicated CatalinaWeb Orion window.
5. Verify the dedicated window closed when possible.
6. Exit CatalinaWeb.

The implementation must not close unrelated normal Orion windows or intentionally terminate the user's normal Orion session.

If the dedicated window refuses to close, CatalinaWeb exits after reporting that the dedicated Orion environment may still be running. It does not force-kill Orion.

## 18. Error handling model

Every automation operation follows:

```text
identify target
-> perform one action
-> verify result
-> persist state
```

No long blind UI scripting sequences are allowed.

Required failure behavior:

- Profile creation cannot be verified: stop setup.
- Dedicated window cannot be verified: perform no automation.
- URL navigation times out: retain the previous saved valid URL.
- Focus Mode cannot be confirmed: report unknown status and leave Orion usable.
- External rerouting cannot be done safely: leave the destination alone.
- Accessibility hierarchy changes after an Orion update: fail visibly rather than guessing element positions.

No force-killing Orion is permitted.

## 19. Security and privacy boundaries

CatalinaWeb must not:

- store ChatGPT credentials;
- store GitHub credentials;
- copy or persist authentication cookies;
- log page text or message contents;
- inject JavaScript into ChatGPT or GitHub;
- install an Orion browser extension;
- use private Orion APIs;
- modify Orion's internal profile files directly unless a future separately approved design explicitly allows it;
- weaken TLS or certificate validation;
- request privileged/root access for browser control.

Accessibility permission is used only for the dedicated Orion setup/window-control workflow.

## 20. Diagnostics

CatalinaWeb maintains lightweight diagnostics for:

- Accessibility authorization state;
- setup state;
- dedicated profile/window identity status;
- active workspace;
- last valid ChatGPT URL;
- last valid GitHub URL;
- last successful Orion operation;
- last automation failure;
- Focus Mode status;
- dedicated-window reopen/close events;
- CatalinaWeb controller RSS;
- best-effort dedicated Orion process-family RSS.

Diagnostics must not include browsing contents, messages, form contents, credentials, or authentication tokens.

## 21. Resource model

CatalinaWeb itself should remain very small because it owns no renderer.

Implementation goals:

- no hidden `WKWebView`;
- no embedded browser engine;
- no persistent privileged helper;
- no daemon;
- use Accessibility notifications where reliable;
- avoid high-frequency polling;
- use slow fallback observation only where event-driven observation is unavailable.

The relevant resource footprint is the combined total of:

`CatalinaWeb controller + dedicated CatalinaWeb Orion profile/window`

not the controller in isolation.

## 22. Functional acceptance gate

Prototype 2 is not functionally complete until Catalina runtime testing confirms all of the following:

1. Automatic first-run dedicated-profile creation.
2. Accessibility setup behaves correctly.
3. No duplicate dedicated profile is created after interrupted/repeated setup.
4. Persistent ChatGPT login.
5. Persistent GitHub login.
6. Exact ChatGPT URL restoration.
7. Exact GitHub URL restoration.
8. At least 25 alternating ChatGPT/GitHub switches.
9. Back control works.
10. Forward control works.
11. Reload control works.
12. ChatGPT normal conversation navigation works.
13. ChatGPT uploads work through Orion.
14. ChatGPT downloads work through Orion where applicable.
15. GitHub repository navigation works.
16. GitHub diffs/issues/PR pages work.
17. GitHub editing/form flows work.
18. GitHub downloads work through Orion.
19. External unrelated links reroute to normal Orion without corrupting saved workspace state.
20. Controller-above behavior works during normal desktop use.
21. Dedicated Orion closure does not disturb normal Orion windows.
22. Manual closure of the dedicated Orion window is recoverable through Reopen Workspace.
23. Application relaunch restores active workspace, exact URL, and window geometry.
24. Focus Mode does not enter a blind toggle loop.
25. No automation is sent to an unverified Orion window.

## 23. Performance acceptance gate

Performance evaluation occurs only after the functional gate passes.

Compare:

- normal Orion workflow; versus
- CatalinaWeb controller + dedicated CatalinaWeb Orion profile.

Measure:

- total relevant browser-family RSS;
- controller RSS;
- swap growth;
- idle CPU;
- WindowServer impact;
- startup time;
- workspace-switch latency;
- long-session responsiveness.

The project should not be declared successful solely because the controller itself is lightweight. The combined CatalinaWeb + dedicated-Orion workflow must provide a meaningful resource or usability advantage over simply using Orion normally.

If it does not, Prototype 2 is a no-go and the project should stop rather than hiding that result behind controller-only measurements.

## 24. Testing strategy

### Unit tests

Test pure logic independently from macOS UI automation:

- workspace URL validation;
- saved-state transitions;
- setup state-machine transitions;
- window identity scoring/verification logic;
- external-navigation classification;
- retry/timeout decisions;
- diagnostic redaction;
- geometry persistence.

### Adapter tests

Wrap Accessibility and process/window discovery behind interfaces so behavior can be tested with fakes.

Test:

- successful target discovery;
- ambiguous target refusal;
- missing accessibility elements;
- URL-read fallback behavior;
- failed navigation verification;
- Focus Mode unknown state;
- dedicated-window disappearance/reacquisition.

### Catalina hands-on tests

All actual Orion UI hierarchy, Accessibility permission, profile creation, Focus Mode, login persistence, window lifecycle, keyboard fallback, external rerouting, uploads/downloads, and resource measurements require verification on the Catalina Mac.

## 25. Explicit non-goals for Prototype 2

Prototype 2 will not attempt to:

- fork or build WebKit;
- replace Orion's renderer;
- embed Orion inside CatalinaWeb;
- support arbitrary websites;
- support more than the two approved workspaces;
- preserve unsent DOM drafts across workspace switches;
- intercept navigation inside Orion through an extension;
- automate Orion using private APIs;
- achieve a browser-engine-level external-navigation block;
- guarantee lower rendering memory than Orion itself.

## 26. Success definition

Prototype 2 succeeds only if it is both:

1. functionally reliable for ChatGPT and GitHub on Catalina; and
2. meaningfully better than normal Orion usage in resource behavior, workflow simplicity, or both.

The design intentionally prefers verified automation and explicit failure states over brittle hidden behavior.
