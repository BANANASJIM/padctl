#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-kcov-output}"
rm -rf "$OUT_DIR"

zig build -j1 test -Dtest-coverage
