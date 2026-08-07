#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
PROBE="$ROOT/scripts/orion_accessibility_probe.swift"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

[ -f "$PROBE" ] || fail "Orion Accessibility probe is missing"

PROHIBITED='AXUIElementPerformAction|CGEventPost|NSPasteboard|setAttributeValue|AXUIElementSetAttributeValue|defaults write|killall|pkill'

if grep -En "$PROHIBITED" "$PROBE" >/tmp/catalinaweb-orion-probe-prohibited.txt 2>/dev/null; then
    cat /tmp/catalinaweb-orion-probe-prohibited.txt >&2
    rm -f /tmp/catalinaweb-orion-probe-prohibited.txt
    fail "probe contains mutation behavior"
fi
rm -f /tmp/catalinaweb-orion-probe-prohibited.txt

if grep -Fn 'as? AXUIElement' "$PROBE" >/tmp/catalinaweb-orion-probe-cfcast.txt 2>/dev/null; then
    cat /tmp/catalinaweb-orion-probe-cfcast.txt >&2
    rm -f /tmp/catalinaweb-orion-probe-cfcast.txt
    fail "probe uses a Swift 5.3-incompatible conditional cast to AXUIElement"
fi
rm -f /tmp/catalinaweb-orion-probe-cfcast.txt

# Catalina Swift 5.3 rejects rebinding a previously declared local variable
# with the same name (the regression we hit was `var names` followed by
# `guard ..., let names = names`). Do not reject ordinary optional binding such
# as `guard let role = role`, which compiles correctly.
if grep -Fn 'let names = names' "$PROBE" >/tmp/catalinaweb-orion-probe-shadowing.txt 2>/dev/null; then
    cat /tmp/catalinaweb-orion-probe-shadowing.txt >&2
    rm -f /tmp/catalinaweb-orion-probe-shadowing.txt
    fail "probe reintroduces the Swift 5.3 local names shadowing regression"
fi
rm -f /tmp/catalinaweb-orion-probe-shadowing.txt

# The Catalina 10.15 ApplicationServices SDK does not export kAXWebAreaRole.
# The runtime role string is still AXWebArea, as verified by the Catalina probe.
if grep -Fn 'kAXWebAreaRole' "$PROBE" >/tmp/catalinaweb-orion-probe-webarea.txt 2>/dev/null; then
    cat /tmp/catalinaweb-orion-probe-webarea.txt >&2
    rm -f /tmp/catalinaweb-orion-probe-webarea.txt
    fail "probe uses kAXWebAreaRole, which is unavailable in the Catalina SDK"
fi
rm -f /tmp/catalinaweb-orion-probe-webarea.txt
grep -Fq 'AXWebArea' "$PROBE" \
    || fail "probe lacks the Catalina-verified AXWebArea role string"

grep -Fq 'AXUIElementGetTypeID()' "$PROBE" \
    || fail "probe does not verify CoreFoundation type identity before AXUIElement conversion"
grep -Fq 'kAXRoleAttribute' "$PROBE" \
    || fail "probe does not inspect AX roles"
grep -Fq 'kAXTitleAttribute' "$PROBE" \
    || fail "probe does not inspect AX titles"
grep -Fq 'kAXWindowsAttribute' "$PROBE" \
    || fail "probe does not inspect AX windows"
grep -Fq 'kAXMenuBarAttribute' "$PROBE" \
    || fail "probe does not inspect the AX menu bar"
grep -Fq 'maximumTreeDepth' "$PROBE" \
    || fail "probe tree traversal is not explicitly bounded"
grep -Fq 'http' "$PROBE" \
    || fail "probe lacks URL-only value filtering"

# Targeted Profiles diagnostics must remain read-only while exposing alternate
# semantic AX paths that Orion may use for lazily populated submenus.
grep -Fq -- '--profiles-detail' "$PROBE" \
    || fail "probe lacks targeted Profiles diagnostic mode"
grep -Fq 'AXUIElementCopyAttributeNames' "$PROBE" \
    || fail "probe does not enumerate available AX attributes"
grep -Fq 'AXUIElementCopyActionNames' "$PROBE" \
    || fail "probe does not enumerate advertised AX actions"
grep -Fq 'kAXVisibleChildrenAttribute' "$PROBE" \
    || fail "probe does not inspect AXVisibleChildren for lazy menus"

# Task 6 needs evidence that can distinguish the manually created CatalinaWeb
# profile window inside Orion's shared process. The diagnostic remains read-only
# and prints only allowlisted profile-manager text plus URL-bearing values.
grep -Fq -- '--profile-manager-detail' "$PROBE" \
    || fail "probe lacks targeted profile-manager/window identity mode"
grep -Fq 'kAXFocusedWindowAttribute' "$PROBE" \
    || fail "probe does not inspect the focused Orion window"
grep -Fq 'kAXMainWindowAttribute' "$PROBE" \
    || fail "probe does not inspect the main Orion window"
grep -Fq 'CatalinaWeb' "$PROBE" \
    || fail "probe lacks allowlisted CatalinaWeb profile marker"
grep -Fq 'Primary' "$PROBE" \
    || fail "probe lacks allowlisted Primary profile marker"

echo "PASS: Orion Accessibility probe source contract"
