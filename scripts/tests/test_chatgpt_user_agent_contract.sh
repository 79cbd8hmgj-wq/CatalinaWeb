#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
FILE="$ROOT/Sources/CatalinaWebApp/WebViewController.swift"

/usr/bin/grep -Fq 'if workspace == .chatGPT' "$FILE"
/usr/bin/grep -Fq 'configuration.applicationNameForUserAgent = Self.chatGPTCompatibilityApplicationName' "$FILE"
/usr/bin/grep -Fq 'Version/15.6 Safari/605.1.15' "$FILE"

if /usr/bin/grep -Fq 'customUserAgent' "$FILE"; then
    echo 'FAIL: global customUserAgent must not be used for ChatGPT compatibility' >&2
    exit 1
fi

echo 'PASS: ChatGPT Safari identity compatibility contract'
