#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
FILE="$ROOT/Sources/CatalinaWebApp/WebViewNavigationDelegate.swift"

if /usr/bin/grep -Fq 'navigationAction.sourceFrame.request' "$FILE"; then
    echo 'FAIL: unsafe Catalina WebKit sourceFrame.request bridge remains in WebViewNavigationDelegate.swift' >&2
    exit 1
fi

/usr/bin/grep -Fq 'sourceURL: webView.url' "$FILE"

echo 'PASS: Catalina WebKit navigation source bridge contract'
