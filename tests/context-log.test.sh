#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/scripts"
cp "$ROOT_DIR/scripts/context-log.sh" "$TMP_DIR/scripts/context-log.sh"
chmod +x "$TMP_DIR/scripts/context-log.sh"

cd "$TMP_DIR"

bash scripts/context-log.sh init >/dev/null
bash scripts/context-log.sh resume-lite >/dev/null

[[ -f "$TMP_DIR/docs/context/PROJECT.md" ]] || {
  echo "[FAIL] expected docs/context/PROJECT.md"
  exit 1
}

[[ -f "$TMP_DIR/docs/context/CONVENTIONS.md" ]] || {
  echo "[FAIL] expected docs/context/CONVENTIONS.md"
  exit 1
}

[[ -f "$TMP_DIR/docs/context/HANDOFF.md" ]] || {
  echo "[FAIL] expected docs/context/HANDOFF.md"
  exit 1
}

[[ -f "$TMP_DIR/docs/context/CODEX_RESUME.md" ]] || {
  echo "[FAIL] expected docs/context/CODEX_RESUME.md"
  exit 1
}

if grep -q "Discord Bot" "$TMP_DIR/docs/context/PROJECT.md"; then
  echo "[FAIL] expected generic project brief, found stale project content"
  exit 1
fi

if ! grep -q "repo-slug: $(basename "$TMP_DIR")" "$TMP_DIR/docs/context/PROJECT.md"; then
  echo "[FAIL] expected repo-slug to match temp repo directory"
  exit 1
fi

echo "[PASS] context-log smoke"
