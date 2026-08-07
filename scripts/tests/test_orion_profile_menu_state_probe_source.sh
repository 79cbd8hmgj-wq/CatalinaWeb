#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
PROBE="$ROOT/scripts/orion_profile_menu_state_probe.swift"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

[ -f "$PROBE" ] || fail "Orion profile menu state probe is missing"

PROHIBITED='AXUIElementPerformAction|AXUIElementSetAttributeValue|CGEventPost|NSPasteboard|defaults write|killall|pkill'
if grep -En "$PROHIBITED" "$PROBE" >/tmp/catalinaweb-profile-state-probe-prohibited.txt 2>/dev/null; then
    cat /tmp/catalinaweb-profile-state-probe-prohibited.txt >&2
    rm -f /tmp/catalinaweb-profile-state-probe-prohibited.txt
    fail "profile state probe contains mutation behavior"
fi
rm -f /tmp/catalinaweb-profile-state-probe-prohibited.txt

if grep -Fn 'as? AXUIElement' "$PROBE" >/tmp/catalinaweb-profile-state-probe-cfcast.txt 2>/dev/null; then
    cat /tmp/catalinaweb-profile-state-probe-cfcast.txt >&2
    rm -f /tmp/catalinaweb-profile-state-probe-cfcast.txt
    fail "profile state probe uses a Swift 5.3-incompatible AXUIElement cast"
fi
rm -f /tmp/catalinaweb-profile-state-probe-cfcast.txt

grep -Fq 'AXUIElementGetTypeID()' "$PROBE" \
    || fail "profile state probe does not verify AXUIElement CF type identity"
grep -Fq 'AXSelected' "$PROBE" \
    || fail "profile state probe does not inspect selected state"
grep -Fq 'AXMenuItemMarkChar' "$PROBE" \
    || fail "profile state probe does not inspect menu mark state"
grep -Fq 'AXMenuItemPrimaryUIElement' "$PROBE" \
    || fail "profile state probe does not inspect primary UI linkage"
grep -Fq 'AXParent' "$PROBE" \
    || fail "profile state probe does not inspect parent hierarchy"
grep -Fq 'CatalinaWeb' "$PROBE" \
    || fail "profile state probe lacks CatalinaWeb marker"
grep -Fq 'Primary' "$PROBE" \
    || fail "profile state probe lacks Primary marker"
grep -Fq 'AXWebArea' "$PROBE" \
    || fail "profile state probe does not omit web content"

echo "PASS: Orion profile menu state probe source contract"
