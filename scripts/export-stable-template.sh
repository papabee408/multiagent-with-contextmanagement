#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/.build/stable-ai-dev-template}"

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

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

for relative_path in "${PATHS[@]}"; do
  cp -R "$ROOT_DIR/$relative_path" "$OUTPUT_DIR/$relative_path"
done

find "$OUTPUT_DIR/docs/tasks" -maxdepth 1 -type f -name '*.md' \
  ! -name 'README.md' \
  ! -name '_template.md' \
  -delete

rm -f "$OUTPUT_DIR/scripts/export-stable-template.sh"
find "$OUTPUT_DIR" -name '.DS_Store' -delete

echo "[PASS] export-stable-template"
echo " - output=$OUTPUT_DIR"
