#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$ROOT_DIR"

echo "[INFO] running unit tests"
node --test tests/unit/*.test.mjs

echo "[INFO] running context-log tests"
bash tests/context-log.test.sh

echo "[PASS] tests"
