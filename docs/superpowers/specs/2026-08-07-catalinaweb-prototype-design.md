# CatalinaWeb Prototype Design

Date: 2026-08-07
Status: Approved design
Target: macOS Catalina 10.15.7 on MacBookPro9,2

## 1. Purpose

CatalinaWeb is a purpose-built, extremely lightweight native macOS client for exactly two web applications:

- ChatGPT
- GitHub

It is not a general-purpose browser. The prototype exists to determine whether a native AppKit + WKWebView client on macOS Catalina can provide the required ChatGPT and GitHub capabilities while using materially fewer resources than Orion.

The prototype should be abandoned if it cannot preserve the required functionality or cannot produce a meaningful efficiency advantage.

## 2. Product boundaries

CatalinaWeb supports two fixed workspaces only:

1. ChatGPT
2. GitHub

Top-level navigation to unrelated sites must open externally in Orion. CatalinaWeb must not grow a generic address bar, arbitrary browsing model, extension ecosystem, profiles, sync, bookmarks database, browser account system, news feed, wallet, telemetry framework, or other general-browser features during Prototype 1.

## 3. Core architecture

Prototype 1 uses native AppKit and the WebKit framework already available on macOS Catalina.

Primary components:

- `NSApplication` / AppKit application shell
- `WorkspaceController`
  - ChatGPT workspace state
  - GitHub workspace state
- `WebViewController`
  - owns exactly one live `WKWebView`
- `NavigationPolicy`
  - classifies top-level navigation
- persistent `WKWebsiteDataStore`
  - cookies
  - local storage
  - login/session data
- lightweight diagnostics collector

### One-live-webview invariant

At most one `WKWebView` may exist at any time.

When switching workspaces:

1. Save the current workspace's last committed URL.
2. Remove the current `WKWebView` from the view hierarchy.
3. Release all strong references to the current web view and its delegates/controllers that would keep it alive.
4. Create a new `WKWebView` for the destination workspace.
5. Load the destination workspace's exact last saved URL, or its home URL if no saved URL exists.

The inactive workspace must not remain preloaded, hidden, or retained for faster switching.

## 4. Workspace state

CatalinaWeb persists only the state required to resume the two workspaces:

- ChatGPT last URL
- GitHub last URL
- last active workspace
- application window size and position

CatalinaWeb does not create a custom history database, cached page snapshots, duplicated cookie store, or serialized page-state archive.

Website login/session state is owned by WebKit's persistent website data store so destroying a `WKWebView` does not log the user out.

## 5. User interface

The interface is intentionally minimal.

Primary controls:

- ChatGPT workspace button
- GitHub workspace button
- Back
- Forward
- Reload

No address bar is present.

### Keyboard shortcuts

- `Command-1`: ChatGPT
- `Command-2`: GitHub
- `Command-[`: Back
- `Command-]`: Forward
- `Command-R`: Reload
- `Command-W`: close CatalinaWeb
- `Command-L`: intentionally unused

The active workspace button must have a clear selected state.

## 6. Navigation policy

CatalinaWeb applies a strict distinction between top-level browsing and subresources.

### Internal top-level navigation

Top-level URLs required for ChatGPT/OpenAI or GitHub workflows may load internally.

The initial allowlist must be narrow and evidence-driven. Required authentication or redirect domains are added only when observed and verified during prototype testing.

### External top-level navigation

A user-initiated top-level navigation to an unrelated site must:

1. be cancelled inside CatalinaWeb; and
2. open in Orion.

### Subresources

The top-level navigation policy must not indiscriminately block JavaScript, CSS, images, APIs, CDNs, GitHub assets, ChatGPT APIs, authentication assets, or other subresources required by the allowed sites.

### New-window requests

CatalinaWeb does not create additional browser windows.

- allowed ChatGPT/GitHub new-window targets load in the current workspace;
- unrelated targets open in Orion.

This preserves the one-live-webview invariant.

## 7. Uploads and downloads

File transfer is a first-class Prototype 1 requirement.

### Uploads

Use public `WKUIDelegate` APIs to provide the native macOS open panel required for HTML file input controls.

Prototype validation must include:

- ChatGPT image upload
- ChatGPT regular file upload
- any GitHub upload/edit flow needed by the user

### Downloads

Prototype validation must include:

- GitHub repository ZIP download
- direct GitHub file download
- ChatGPT generated-file download

Download behavior must use public Catalina-compatible APIs. If native Catalina WebKit lacks a required reliable download mechanism, record the exact failure and design the smallest fallback after the prototype evidence is collected. Do not introduce private WebKit APIs merely to force Prototype 1 to pass.

## 8. Resource-management policy

The performance model is intentionally more aggressive than a normal browser.

### Hard rules

- exactly one live `WKWebView`
- no hidden destination workspace
- no shell-level speculative preloading
- no background workspace warm-up
- no old web view retained for instant switching
- no extension runtime
- no browser-level sync service
- no browser telemetry service

### Memory pressure

Prototype 1 should observe macOS memory-pressure notifications.

- Normal: no intervention
- Warning: release nonessential CatalinaWeb-owned caches/state
- Critical: record the event, but do not automatically destroy the active page until safe active-page recreation has been validated

The prototype must not automatically reload an active ChatGPT page under ordinary warning pressure because that could interrupt an in-progress response or unsent text.

## 9. Diagnostics

Performance measurement is part of the product, not an afterthought.

Prototype 1 should provide a lightweight diagnostics surface or log containing at least:

- active workspace
- live `WKWebView` count
- CatalinaWeb process RSS
- observable WebKit child-process count
- total observable CatalinaWeb/WebKit process-family RSS where feasible with public Catalina APIs
- current system memory-pressure state
- workspace-switch lifecycle events
- Web Content process termination events
- blocked external-navigation events

Diagnostics must not change process priority or scheduling. Measurement must remain separate from CatalinaPerformance App Priority.

## 10. Compatibility behavior

### Authentication

CatalinaWeb must preserve ChatGPT and GitHub login state across workspace destruction and recreation using the persistent WebKit website data store.

CatalinaWeb must not implement its own credential database or intercept passwords.

### Web Content process termination

If WebKit terminates the active Web Content process:

1. keep CatalinaWeb running;
2. retain the workspace's last committed URL;
3. display a lightweight failure state;
4. expose a Reload Workspace action;
5. recreate a fresh `WKWebView` only when requested.

Do not create an uncontrolled automatic crash/reload loop.

### Site incompatibility

Prototype diagnostics should distinguish, where practical:

- navigation failure
- authentication redirect rejection
- Web Content process termination
- file upload failure
- download failure
- TLS/network failure
- site/browser incompatibility visible to the user

Do not hide engine incompatibility with broad user-agent spoofing. If current ChatGPT or GitHub fundamentally requires a newer engine than Catalina's WebKit provides, that is a valid prototype result.

## 11. Security boundaries

Prototype 1 uses only public macOS APIs.

It must not:

- inject custom JavaScript into ChatGPT or GitHub
- weaken TLS verification
- bypass certificate errors
- use private WebKit APIs
- disable WebKit process isolation
- store user passwords itself
- modify SIP
- install privileged helpers
- mutate CatalinaPerformance settings

CatalinaPerformance integration is explicitly deferred until CatalinaWeb proves it can function and outperform Orion on its own.

## 12. Functional acceptance gate

### ChatGPT must support

- sign in and remain signed in
- load conversation history
- open an existing conversation
- create a new chat
- send messages
- stream a full response
- render Markdown and code blocks
- upload an image
- upload a regular file
- download a generated file
- normal copy and paste

### GitHub must support

- sign in and remain signed in
- open repositories
- browse source
- inspect commits and diffs
- use issues
- use pull requests
- edit a file
- download a file or repository
- complete normal authentication flows

Any material failure in these workflows is a blocker for continuing with the native Catalina WebKit architecture.

## 13. Lifecycle acceptance gate

Repeatedly switch:

ChatGPT -> GitHub -> ChatGPT -> GitHub

Verify that:

- only one `WKWebView` is live after each transition
- abandoned WebKit process trees terminate rather than accumulate indefinitely
- login state remains intact
- each workspace returns to its exact previous URL
- memory usage does not ratchet upward on every switch
- no hidden web views or duplicate workspace controllers remain alive

## 14. Orion comparison

The prototype must be tested against Orion under the same machine state and representative workload.

Measure at minimum:

- cold launch time
- time until ChatGPT is usable
- browser-family RAM
- system RAM
- swap growth
- system CPU average and peak
- WindowServer average and peak
- workspace-switch latency
- subjective interaction responsiveness

Existing unrelated Orion sessions are useful background evidence but do not replace paired testing.

## 15. Go / no-go rule

Continue CatalinaWeb development only if both conditions are true:

1. ChatGPT and GitHub have no meaningful capability loss for the required workflows.
2. CatalinaWeb demonstrates a meaningful resource or responsiveness advantage over Orion.

Primary target:

- at least 15-20% lower browser-family memory than Orion under a paired representative workload

A comparably meaningful reduction in swap accumulation or another clear responsiveness advantage may also justify continuation.

If CatalinaWeb only saves a trivial amount of memory, performs worse interactively, or requires substantial capability compromises, stop the project rather than adding polish.

## 16. Explicitly deferred work

The following are outside Prototype 1:

- CatalinaPerformance integration
- automatic Performance Mode activation
- process-priority tuning
- custom WebKit builds
- newer bundled browser engine
- extensions
- arbitrary browsing
- multiple simultaneous live workspaces
- more than one ChatGPT or GitHub tab
- custom password manager
- browser sync
- user-agent spoofing as a compatibility strategy
- private WebKit APIs

A newer WebKit or different engine may be evaluated only if native Catalina WebKit fails the functional gate and the project remains worth pursuing.
