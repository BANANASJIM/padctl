#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-kcov-output}"
rm -rf "$OUT_DIR"

timeout 600 zig build test -Dtest-coverage --summary all
