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

PROHIBITED='WKUserScript|customUserAgent|setValue.*forKey.*WebKit|allowsAnyHTTPSCertificate|SecTrustSetExceptions|renice|setpriority|sudo|AuthorizationExecuteWithPrivileges|launchctl|csrutil'

if grep -RInE "$PROHIBITED" "$SOURCES" >/tmp/catalinaweb-security-prohibited.txt 2>/dev/null; then
    cat /tmp/catalinaweb-security-prohibited.txt
    fail "prohibited production implementation pattern found"
fi
rm -f /tmp/catalinaweb-security-prohibited.txt

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
