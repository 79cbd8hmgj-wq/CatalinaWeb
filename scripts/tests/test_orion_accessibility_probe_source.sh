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

echo "PASS: Orion Accessibility probe source contract"
