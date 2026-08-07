#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
PACKAGE="$ROOT/Package.swift"
PACKAGER="$ROOT/scripts/package_app.sh"

[ -f "$PACKAGE" ] || { echo "FAIL: Package.swift missing"; exit 1; }
[ -f "$PACKAGER" ] || { echo "FAIL: package_app.sh missing"; exit 1; }

grep -Fq '// swift-tools-version:5.3' "$PACKAGE"
grep -Fq '.macOS(.v10_15)' "$PACKAGE"
grep -Fq 'name: "CatalinaWeb"' "$PACKAGE"
grep -Fq 'LSMinimumSystemVersion' "$PACKAGER"
grep -Fq '<string>10.15</string>' "$PACKAGER"

if grep -Eq 'async[[:space:]]|await[[:space:]]' "$ROOT"/Sources/CatalinaWebApp/*.swift "$ROOT"/Sources/CatalinaWeb/*.swift 2>/dev/null; then
    echo "FAIL: Swift Concurrency is outside the Catalina/Xcode 12.4 baseline"
    exit 1
fi

echo "PASS: package contract"
