#!/bin/sh
set -eu

LABEL=""
OUTPUT=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --label)
            [ "$#" -ge 2 ] || { echo "FAIL: --label requires a value"; exit 2; }
            LABEL=$2
            shift 2
            ;;
        --output)
            [ "$#" -ge 2 ] || { echo "FAIL: --output requires a path"; exit 2; }
            OUTPUT=$2
            shift 2
            ;;
        *)
            echo "FAIL: unknown argument: $1"
            exit 2
            ;;
    esac
done

[ -n "$LABEL" ] || { echo "FAIL: --label is required"; exit 2; }
[ -n "$OUTPUT" ] || { echo "FAIL: --output is required"; exit 2; }

OUTPUT_DIR=$(dirname "$OUTPUT")
mkdir -p "$OUTPUT_DIR"

{
    echo "=== CatalinaWeb Benchmark Snapshot ==="
    echo "Label: $LABEL"
    echo

    echo "=== Date ==="
    date
    echo

    echo "=== macOS ==="
    sw_vers
    echo

    echo "=== Physical Memory Bytes ==="
    sysctl -n hw.memsize
    echo

    echo "=== vm_stat ==="
    vm_stat
    echo

    echo "=== memory_pressure ==="
    memory_pressure 2>/dev/null || true
    echo

    echo "=== Processes ==="
    ps -ww -axo pid=,ppid=,rss=,%cpu=,command=
    echo

    echo "=== WindowServer ==="
    ps -ww -axo pid=,ppid=,rss=,%cpu=,command= | grep '[W]indowServer' || true
} > "$OUTPUT"

echo "Saved benchmark snapshot: $OUTPUT"
