#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Broad, intentionally conservative patterns for hardcoded secret-like literals.
PATTERN='(sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,}|-----BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY-----)'

if rg -n --hidden --glob '!.git' --glob '!docs/context/sessions/**' "$PATTERN" "$ROOT_DIR" >/tmp/gate-secrets.out 2>/dev/null; then
  echo "[FAIL] secrets"
  cat /tmp/gate-secrets.out
  exit 1
fi

echo "[PASS] secrets"
