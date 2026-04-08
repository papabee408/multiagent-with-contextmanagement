#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="$ROOT_DIR/stable-ai-dev-template"

if [[ ! -d "$BUNDLE_DIR" ]]; then
  exit 0
fi

fail() {
  echo "[FAIL] template-sync" >&2
  echo " - $1" >&2
  exit 1
}

PATHS=(
  ".github"
  ".gitignore"
  "AGENTS.md"
  "README.md"
  "docs"
  "scripts"
  "test-guide.md"
  "tests"
)

for relative_path in "${PATHS[@]}"; do
  root_path="$ROOT_DIR/$relative_path"
  bundle_path="$BUNDLE_DIR/$relative_path"

  [[ -e "$root_path" ]] || fail "missing root path: $relative_path"
  [[ -e "$bundle_path" ]] || fail "missing bundle path: $relative_path"

  if ! diff -qr "$root_path" "$bundle_path" >/dev/null; then
    diff -qr "$root_path" "$bundle_path" >&2 || true
    fail "root and stable-ai-dev-template differ at $relative_path"
  fi
done
