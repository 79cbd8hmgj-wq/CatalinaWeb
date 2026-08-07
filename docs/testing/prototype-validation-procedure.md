# CatalinaWeb Prototype Validation Procedure

This procedure is the acceptance gate for Prototype 1. It compares CatalinaWeb with Orion on the same Mac and intentionally keeps measurement separate from scheduling or system mutation.

## Preconditions

1. Use macOS Catalina 10.15.7 on the target MacBookPro9,2.
2. Reboot, or begin both browser trials from a comparably idle machine state.
3. Close Firefox and other unnecessary browsers and applications before each trial.
4. If CatalinaPerformance is used for measurement, keep App Priority disabled for both Orion and CatalinaWeb. Do not introduce different system mutations between trials.
5. Use the same network connection and the same fixed ChatGPT prompt/files for both trials.
6. Do not change CatalinaWeb or Orion settings between the paired trials.

## Build and launch CatalinaWeb

From the repository root:

```bash
chmod +x scripts/*.sh scripts/tests/*.sh
/bin/sh scripts/tests/test_package_contract.sh
/bin/sh scripts/tests/test_security_contract.sh
rm -rf .build build
swift test
swift build --product CatalinaWeb
./scripts/package_app.sh
/usr/bin/codesign --verify --deep --strict build/CatalinaWeb.app
open build/CatalinaWeb.app
```

## Snapshot commands

Create a directory for one paired run:

```bash
RUN="$HOME/Desktop/CatalinaWeb-benchmark-$(date '+%Y%m%d-%H%M%S')"
mkdir -p "$RUN"
```

For each browser, capture three read-only snapshots with:

```bash
./scripts/benchmark_snapshot.sh --label "BROWSER start" --output "$RUN/BROWSER-start.txt"
./scripts/benchmark_snapshot.sh --label "BROWSER mid"   --output "$RUN/BROWSER-mid.txt"
./scripts/benchmark_snapshot.sh --label "BROWSER end"   --output "$RUN/BROWSER-end.txt"
```

Replace `BROWSER` with `orion` or `catalinaweb` in both the label and filename.

For CatalinaWeb, also open **Window -> Diagnostics** and record the displayed snapshot at start, after the switch sequence, and at the end. The diagnostics window must continue to report exactly one live `WKWebView` while a workspace is loaded.

## Fixed workload

Use the same workload in both browsers.

### ChatGPT

1. Open the same existing conversation.
2. Send the same fixed prompt.
3. Wait for the full streamed response to finish.
4. Upload the same image.
5. Upload the same text or PDF file.
6. Verify copy/paste and rendered Markdown/code blocks.
7. If testing CatalinaWeb, verify a generated-file download if the conversation can produce one without changing the workload materially.

### GitHub

1. Open the CatalinaWeb repository.
2. Browse the same source file.
3. Open commit history and one commit diff.
4. Open the pull-request/issues view.
5. Open the edit view for a harmless documentation file, make a temporary local edit, and leave without committing it.
6. Download the repository ZIP.

### Workspace switch sequence

For CatalinaWeb, perform exactly:

```text
ChatGPT -> GitHub -> ChatGPT -> GitHub -> ChatGPT
```

After each restored page becomes usable, pause for 15 seconds. Confirm the exact prior URL returns and login remains intact.

For Orion, reproduce the same logical page sequence with only the equivalent ChatGPT/GitHub tabs required for the workload.

## Functional gate

### ChatGPT

Record PASS/FAIL for:

```text
sign in and remain signed in
load conversation history
open existing conversation
create new chat
send message
stream full response
render Markdown/code blocks
upload image
upload regular file
download generated file
copy/paste
```

### GitHub

Record PASS/FAIL for:

```text
sign in and remain signed in
open repositories
browse source
inspect commits/diffs
issues
pull requests
edit a file
direct/repository download behavior
normal authentication flow
```

If native Catalina WebKit reports an unsupported browser or a required workflow fails, capture CatalinaWeb Diagnostics and stop that part of the gate. Do not mask the incompatibility by changing the user agent.

## Lifecycle gate

Repeat at least 20 workspace switches using the approved two-workspace pattern. Verify after each switch:

- `Live WKWebViews` remains `1` after the destination loads.
- The exact previous workspace URL restores.
- Authentication remains intact.
- No second CatalinaWeb window appears from website popup requests.
- Browser-family resident memory does not monotonically ratchet upward after every switch.
- Strict descendant metrics that cannot be attributed are shown as `Unavailable`, not fabricated as zero.

## Metrics to compare

Record for both browsers:

| Metric | Orion | CatalinaWeb |
|---|---:|---:|
| Cold launch time | | |
| ChatGPT ready time | | |
| Browser-family RAM at start | | |
| Browser-family RAM at mid | | |
| Browser-family RAM at end | | |
| System RAM | | |
| Swap start/end and growth | | |
| CPU average/peak | | |
| WindowServer average/peak | | |
| Workspace-switch/page-ready latency | | |
| Subjective responsiveness | | |

CatalinaWeb's diagnostics process-family figure is deliberately conservative: it includes only processes attributable through strict public parent/child relationships. If WebKit XPC services cannot be safely attributed, treat that metric as incomplete and use the system/process snapshots to interpret the paired result rather than guessing ownership.

## Go / no-go rule

Continue beyond Prototype 1 only when both conditions hold:

1. All required ChatGPT and GitHub workflows pass without meaningful capability loss.
2. CatalinaWeb shows at least **15% lower browser-family memory than Orion**, or a comparably meaningful reduction in swap growth/responsiveness with no material regression.

A **20%+ memory reduction** remains the preferred target. If CatalinaWeb merely saves a trivial amount of memory, or native Catalina WebKit prevents required workflows, stop Prototype 1 and evaluate the engine question separately before adding features.
