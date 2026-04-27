#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-kcov-output}"
rm -rf "$OUT_DIR"

zig build test -Dtest-coverage
