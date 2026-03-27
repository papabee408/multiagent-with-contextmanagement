#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts" \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/docs/features" \
  "$TMP_DIR/docs/context" \
  "$TMP_DIR/.context"

cp "$ROOT_DIR/scripts/start-feature.sh" "$TMP_DIR/scripts/start-feature.sh"
cp "$ROOT_DIR/scripts/feature-packet.sh" "$TMP_DIR/scripts/feature-packet.sh"
cp "$ROOT_DIR/scripts/set-active-feature.sh" "$TMP_DIR/scripts/set-active-feature.sh"
cp "$ROOT_DIR/scripts/workflow-mode.sh" "$TMP_DIR/scripts/workflow-mode.sh"
cp "$ROOT_DIR/scripts/execution-mode.sh" "$TMP_DIR/scripts/execution-mode.sh"
cp "$ROOT_DIR/scripts/sync-handoffs.sh" "$TMP_DIR/scripts/sync-handoffs.sh"
cp "$ROOT_DIR/scripts/_run_log_helpers.sh" "$TMP_DIR/scripts/_run_log_helpers.sh"
cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
chmod +x \
  "$TMP_DIR/scripts/start-feature.sh" \
  "$TMP_DIR/scripts/feature-packet.sh" \
  "$TMP_DIR/scripts/set-active-feature.sh" \
  "$TMP_DIR/scripts/workflow-mode.sh" \
  "$TMP_DIR/scripts/execution-mode.sh" \
  "$TMP_DIR/scripts/sync-handoffs.sh"

cp -R "$ROOT_DIR/docs/features/_template" "$TMP_DIR/docs/features/_template"

cat > "$TMP_DIR/docs/context/PROJECT.md" <<'EOF'
# Project Brief
EOF

cat > "$TMP_DIR/docs/context/ARCHITECTURE.md" <<'EOF'
# Architecture Boundaries
EOF

cat > "$TMP_DIR/docs/context/GATES.md" <<'EOF'
# Gate Policy
EOF

date -u +"%Y-%m-%d %H:%M:%SZ" > "$TMP_DIR/.context/setup-check.done"

cd "$TMP_DIR"
git init -q

cat > README.md <<'EOF'
# Dirty before feature bootstrap
EOF

bash scripts/start-feature.sh --workflow-mode lite --execution-mode single feature-1 >/dev/null

grep -Fxq 'README.md' docs/features/feature-1/.baseline-changes.txt
if grep -Fq 'docs/features/feature-1/plan.md' docs/features/feature-1/.baseline-changes.txt; then
  echo "[FAIL] baseline snapshot should not include newly created packet files"
  exit 1
fi
if grep -Fq 'docs/features/feature-1/.baseline-changes.txt' docs/features/feature-1/.baseline-changes.txt; then
  echo "[FAIL] baseline snapshot should not include its own baseline file"
  exit 1
fi

printf '\n# probe\n' >> docs/features/feature-1/plan.md
changed_output="$(
  source "$TMP_DIR/scripts/gates/_helpers.sh" feature-1
  changed_files
)"
printf '%s\n' "$changed_output" | grep -Fxq 'docs/features/feature-1/plan.md'

if bash scripts/start-feature.sh --workflow-mode full --execution-mode multi-agent feature-1 >/dev/null 2>&1; then
  echo "[FAIL] existing feature re-entry should not bypass mode locks"
  exit 1
fi

bash scripts/start-feature.sh feature-1 >/dev/null
grep -Fxq 'feature-1' .context/active_feature

echo "[PASS] start-feature smoke"
