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
cp "$ROOT_DIR/scripts/check-project-setup.sh" "$TMP_DIR/scripts/check-project-setup.sh"
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

bash scripts/start-feature.sh feature-1 >/dev/null

grep -Fxq -- 'README.md' docs/features/feature-1/.baseline-changes.txt
grep -Fq -- '- `feature-id`: feature-1' docs/features/feature-1/brief.md
grep -Fq -- '- auth-permissions: `no`' docs/features/feature-1/brief.md
grep -Fq -- '- blast-radius: `no`' docs/features/feature-1/brief.md
grep -Fq -- '- class: `standard`' docs/features/feature-1/brief.md
grep -Fq -- '- mode: `lite`' docs/features/feature-1/brief.md
grep -Fq -- '- mode: `single`' docs/features/feature-1/brief.md
grep -Fq -- '- feature-id: feature-1' docs/features/feature-1/run-log.md
grep -Fq 'docs/features/<feature-id>/plan.md' docs/features/feature-1/run-log.md
[[ -f docs/features/feature-1/implementer-handoff.md ]]
[[ -f docs/features/feature-1/tester-handoff.md ]]
[[ ! -f docs/features/feature-1/reviewer-handoff.md ]]
[[ ! -f docs/features/feature-1/security-handoff.md ]]
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

if bash scripts/start-feature.sh --risk-class high-risk --workflow-mode full --execution-mode multi-agent feature-1 >/dev/null 2>&1; then
  echo "[FAIL] existing feature re-entry should not bypass mode locks"
  exit 1
fi
if [[ "$(cat .context/active_feature)" != "feature-1" ]]; then
  echo "[FAIL] rejected existing-feature override must not switch the active feature"
  exit 1
fi

bash scripts/start-feature.sh feature-1 >/dev/null
grep -Fxq 'feature-1' .context/active_feature

bash scripts/start-feature.sh --risk-class high-risk feature-1b >/dev/null
grep -Fq -- '- class: `high-risk`' docs/features/feature-1b/brief.md
grep -Fq -- '- mode: `full`' docs/features/feature-1b/brief.md
[[ -f docs/features/feature-1b/reviewer-handoff.md ]]
[[ -f docs/features/feature-1b/security-handoff.md ]]

current_active_feature="$(cat .context/active_feature)"
if bash scripts/start-feature.sh --risk-class nope broken-feature >/tmp/broken-feature.log 2>&1; then
  echo "[FAIL] invalid bootstrap inputs should not create a partial feature packet"
  exit 1
fi
if [[ -d docs/features/broken-feature ]]; then
  echo "[FAIL] invalid bootstrap inputs should not leave a partial feature directory"
  exit 1
fi
if [[ "$(cat .context/active_feature)" != "$current_active_feature" ]]; then
  echo "[FAIL] invalid bootstrap inputs should not switch the active feature"
  exit 1
fi

cat > "$TMP_DIR/scripts/check-project-setup.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

call_count_file="$(dirname "$0")/.setup-check-call-count"
count="$(cat "$call_count_file" 2>/dev/null || echo 0)"
count="$((count + 1))"
printf '%s' "$count" > "$call_count_file"

echo "[ALERT] fixture setup check intentionally failing."
exit 1
EOF
chmod +x "$TMP_DIR/scripts/check-project-setup.sh"
rm -f "$TMP_DIR/.context/setup-check.done"

if ! bash scripts/start-feature.sh feature-2 >/tmp/feature2.log 2>&1; then
  echo "[FAIL] alerting setup check should not fail feature bootstrap flow"
  exit 1
fi

if [[ "$(cat "$TMP_DIR/scripts/.setup-check-call-count")" != "1" ]]; then
  echo "[FAIL] first alerting bootstrap run should execute the setup check once"
  exit 1
fi
if [[ -f .context/setup-check.done ]]; then
  echo "[FAIL] alerting setup checks should not leave a success stamp behind"
  exit 1
fi

if ! bash scripts/start-feature.sh --risk-class high-risk feature-3 >/tmp/feature3.log 2>&1; then
  echo "[FAIL] rerun should still bootstrap feature after prior alerting setup run"
  exit 1
fi

if [[ "$(cat "$TMP_DIR/scripts/.setup-check-call-count")" != "2" ]]; then
  echo "[FAIL] alerting setup checks should rerun until they pass"
  exit 1
fi
if [[ -f .context/setup-check.done ]]; then
  echo "[FAIL] alerting reruns should still avoid leaving a success stamp"
  exit 1
fi

cat > "$TMP_DIR/scripts/check-project-setup.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

call_count_file="$(dirname "$0")/.setup-check-call-count"
count="$(cat "$call_count_file" 2>/dev/null || echo 0)"
count="$((count + 1))"
printf '%s' "$count" > "$call_count_file"

echo "[OK] fixture setup check now passing."
exit 0
EOF
chmod +x "$TMP_DIR/scripts/check-project-setup.sh"

if ! bash scripts/start-feature.sh feature-4 >/tmp/feature4.log 2>&1; then
  echo "[FAIL] passing setup check should still allow feature bootstrap"
  exit 1
fi

if [[ "$(cat "$TMP_DIR/scripts/.setup-check-call-count")" != "3" ]]; then
  echo "[FAIL] setup check should run one last time when it finally passes"
  exit 1
fi
grep -Fq 'status=ok' .context/setup-check.done

if ! bash scripts/start-feature.sh feature-5 >/tmp/feature5.log 2>&1; then
  echo "[FAIL] setup-check success should not block later bootstrap runs"
  exit 1
fi

if [[ "$(cat "$TMP_DIR/scripts/.setup-check-call-count")" != "3" ]]; then
  echo "[FAIL] successful setup checks should be stamped and skipped on later runs"
  exit 1
fi
if ! grep -Fq 'docs/features/<feature-id>/plan.md' docs/features/feature-2/run-log.md; then
  echo "[FAIL] feature-id placeholder should remain in run-log scope templates"
  exit 1
fi
if grep -Fq 'docs/features/<feature-2>/plan.md' docs/features/feature-2/run-log.md; then
  echo "[FAIL] feature-id placeholder was replaced inside docs path"
  exit 1
fi

echo "[PASS] start-feature smoke"
