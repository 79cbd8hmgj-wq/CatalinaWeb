# Orion Accessibility Probe — Catalina Evidence Procedure

This probe is the evidence checkpoint before CatalinaWeb automates Orion profile creation or browser-window controls.

## Purpose

The probe reads Orion's macOS Accessibility hierarchy on the actual Catalina 10.15.7 machine so CatalinaWeb can use semantic roles, menu titles, fields, and buttons that Orion really exposes. It must not guess coordinate positions or undocumented element names.

The probe is read-only. It does not press Accessibility actions, post keyboard/mouse events, write preferences, modify the clipboard, terminate processes, or edit Orion profile files.

## Prerequisites

1. Build/pull branch `agent/orion-backed-implementation`.
2. Give the probe host process Accessibility permission if macOS requires it.
3. Launch normal Orion and leave one ordinary browser window open.
4. Do not enter passwords or sensitive text while capturing the structure.

## Source contract

From the repository root:

```bash
/bin/sh scripts/tests/test_orion_accessibility_probe_source.sh
```

Expected:

```text
PASS: Orion Accessibility probe source contract
```

## Compile on Catalina

```bash
xcrun swiftc \
  scripts/orion_accessibility_probe.swift \
  -o /tmp/orion_accessibility_probe \
  -framework AppKit \
  -framework ApplicationServices
```

The command must compile with the Catalina/Xcode 12.4 toolchain. A compile error is a blocker; do not work around it with private APIs.

## Capture

With Orion running:

```bash
/tmp/orion_accessibility_probe \
  > "$HOME/Desktop/orion-catalina-accessibility.txt"
```

If more than one Orion-like application is running and the wrong one is selected, rerun with the normal Orion PID:

```bash
/tmp/orion_accessibility_probe --pid ORION_PID \
  > "$HOME/Desktop/orion-catalina-accessibility.txt"
```

The probe deliberately omits webpage/static text and prints text-field values only when the value parses as an `http` or `https` URL.

## Evidence required before implementation proceeds

Review the capture for semantic evidence of each capability:

- File menu.
- Profiles submenu or equivalent profile-management path.
- A semantically named profile-creation command/control.
- A profile-name text field or other semantic name-entry control.
- A semantic confirmation/create button.
- View menu.
- `Enable Focus Mode` and/or `Disable Focus Mode` menu item.
- Orion browser-window roles/subroles that distinguish the browser window.
- An address/location element, if Orion exposes one through Accessibility.

For every item, record the observed role/title/identifier path. If an item is absent, mark that capability unavailable. Do not invent a title, identifier, or coordinate fallback.

## Saved fixture

Only a redacted structural summary should be committed to:

```text
Tests/Fixtures/orion-catalina-accessibility-summary.txt
```

Do not commit the raw Desktop capture if it contains any user-specific paths, window titles, URLs, or other identifying data. The summary should include only the semantic roles/titles/identifiers required by the implementation.
