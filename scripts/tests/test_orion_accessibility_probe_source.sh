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

echo "PASS: Orion Accessibility probe source contract"
