# CatalinaWeb

CatalinaWeb is an experimental macOS Catalina 10.15.7 AppKit + WKWebView client for exactly two workspaces: ChatGPT and GitHub. Prototype 1 is a performance/compatibility experiment, not a general-purpose browser.

## Build

```bash
swift build --product CatalinaWeb
./scripts/package_app.sh
open build/CatalinaWeb.app
```

See `docs/superpowers/specs/2026-08-07-catalinaweb-prototype-design.md` for the approved product boundaries and go/no-go criteria.
