#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
SOURCES="$ROOT/Sources"
WEB_CONTROLLER="$ROOT/Sources/CatalinaWebApp/WebViewController.swift"
UI_DELEGATE="$ROOT/Sources/CatalinaWebApp/WebViewUIDelegate.swift"

fail() {
    echo "FAIL: $1"
    exit 1
}

[ -d "$SOURCES" ] || fail "Sources directory missing"
[ -f "$WEB_CONTROLLER" ] || fail "WebViewController.swift missing"
[ -f "$UI_DELEGATE" ] || fail "WebViewUIDelegate.swift missing"

PROHIBITED='WKUserScript|applicationNameForUserAgent|setValue.*forKey.*WebKit|allowsAnyHTTPSCertificate|SecTrustSetExceptions|renice|setpriority|sudo|AuthorizationExecuteWithPrivileges|launchctl|csrutil'

if grep -RInE "$PROHIBITED" "$SOURCES" >/tmp/catalinaweb-security-prohibited.txt 2>/dev/null; then
    cat /tmp/catalinaweb-security-prohibited.txt
    fail "prohibited production implementation pattern found"
fi
rm -f /tmp/catalinaweb-security-prohibited.txt

CUSTOM_UA_FILES=$(grep -RIlF 'customUserAgent' "$SOURCES" 2>/dev/null || true)
[ "$CUSTOM_UA_FILES" = "$WEB_CONTROLLER" ] \
    || fail "customUserAgent is permitted only in WebViewController.swift"

CUSTOM_UA_COUNT=$(grep -Fc 'customUserAgent' "$WEB_CONTROLLER" | tr -d ' ')
[ "$CUSTOM_UA_COUNT" -eq 1 ] \
    || fail "expected exactly one customUserAgent assignment"

grep -Fq 'if workspace == .chatGPT {' "$WEB_CONTROLLER" \
    || fail "ChatGPT-only user-agent scope is missing"
grep -Fq 'webView.customUserAgent = Self.chatGPTCompatibilityUserAgent' "$WEB_CONTROLLER" \
    || fail "ChatGPT compatibility user-agent assignment is missing"
grep -Fq 'Version/26.0 Safari/605.1.15' "$WEB_CONTROLLER" \
    || fail "observed Orion compatibility user-agent is missing"

grep -Fq 'WKWebsiteDataStore.default()' "$WEB_CONTROLLER" \
    || fail "persistent default WebKit website data store is not explicit"

if grep -RInF '.nonPersistent()' "$SOURCES" >/dev/null 2>&1; then
    fail "non-persistent WebKit website data store found"
fi

grep -Fq 'createWebViewWith' "$UI_DELEGATE" \
    || fail "new-window handling is missing"
grep -Fq 'return nil' "$UI_DELEGATE" \
    || fail "new-window delegate must return nil"

if grep -Eq 'return[[:space:]]+WKWebView|=[[:space:]]*WKWebView[[:space:]]*\(' "$UI_DELEGATE"; then
    fail "new-window delegate creates or returns a second WKWebView"
fi

echo "PASS: security contract"
