#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
FILE="$ROOT/Sources/CatalinaWebApp/MemoryPressureMonitor.swift"

if /usr/bin/grep -Fq 'guard let event = event else' "$FILE"; then
    echo 'FAIL: Swift 5.3-incompatible optional-binding shadowing remains in MemoryPressureMonitor.swift' >&2
    exit 1
fi

/usr/bin/grep -Fq 'let pendingEvent = source?.data' "$FILE"
/usr/bin/grep -Fq 'guard let pressureEvent = pendingEvent else' "$FILE"
/usr/bin/grep -Fq 'pressureEvent.contains(.critical)' "$FILE"
/usr/bin/grep -Fq 'pressureEvent.contains(.warning)' "$FILE"

echo 'PASS: Catalina Swift 5.3 source contract'
