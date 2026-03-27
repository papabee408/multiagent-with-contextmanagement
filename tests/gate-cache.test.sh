#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
COUNTER_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$COUNTER_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/tests/unit" \
  "$TMP_DIR/docs/context" \
  "$TMP_DIR/docs/features/feature-1" \
  "$TMP_DIR/.context"

cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/gates/_validation_cache.sh" "$TMP_DIR/scripts/gates/_validation_cache.sh"
cp "$ROOT_DIR/scripts/gates/check-tests.sh" "$TMP_DIR/scripts/gates/check-tests.sh"
cp "$ROOT_DIR/scripts/gates/run.sh" "$TMP_DIR/scripts/gates/run.sh"
cp "$ROOT_DIR/scripts/complete-feature.sh" "$TMP_DIR/scripts/complete-feature.sh"
cp "$ROOT_DIR/scripts/stage-closeout.sh" "$TMP_DIR/scripts/stage-closeout.sh"
cp "$ROOT_DIR/scripts/set-active-feature.sh" "$TMP_DIR/scripts/set-active-feature.sh"

chmod +x \
  "$TMP_DIR/scripts/gates/check-tests.sh" \
  "$TMP_DIR/scripts/gates/run.sh" \
  "$TMP_DIR/scripts/complete-feature.sh" \
  "$TMP_DIR/scripts/stage-closeout.sh" \
  "$TMP_DIR/scripts/set-active-feature.sh"

cat > "$TMP_DIR/tests/unit/cache-feature.test.mjs" <<'EOF'
import { test } from "node:test";
import { appendFileSync } from "node:fs";

test("feature-cache-marker", () => {
  appendFileSync(process.env.FEATURE_COUNTER, "feature\n");
});
EOF

cat > "$TMP_DIR/tests/context-log.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'context-log\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/gates.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'gates\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/dispatch-heartbeat.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'dispatch\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/run-log-ops.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'run-log\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/stage-closeout.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'stage-closeout\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/sync-handoffs.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sync\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/workflow-mode.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'workflow-mode\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/execution-mode.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'execution-mode\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/promote-workflow.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'promote-workflow\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/start-feature.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'start-feature\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/implementer-subtasks.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'implementer-subtasks\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/check-tests-modes.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'mode-self\n' >> "$INFRA_COUNTER"
EOF

cat > "$TMP_DIR/tests/gate-cache.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'gate-cache-self\n' >> "$INFRA_COUNTER"
EOF

chmod +x \
  "$TMP_DIR/tests/context-log.test.sh" \
  "$TMP_DIR/tests/gates.test.sh" \
  "$TMP_DIR/tests/dispatch-heartbeat.test.sh" \
  "$TMP_DIR/tests/run-log-ops.test.sh" \
  "$TMP_DIR/tests/stage-closeout.test.sh" \
  "$TMP_DIR/tests/sync-handoffs.test.sh" \
  "$TMP_DIR/tests/workflow-mode.test.sh" \
  "$TMP_DIR/tests/execution-mode.test.sh" \
  "$TMP_DIR/tests/promote-workflow.test.sh" \
  "$TMP_DIR/tests/start-feature.test.sh" \
  "$TMP_DIR/tests/implementer-subtasks.test.sh" \
  "$TMP_DIR/tests/check-tests-modes.test.sh" \
  "$TMP_DIR/tests/gate-cache.test.sh"

for script_name in \
  check-project-context \
  check-packet \
  check-brief \
  check-plan \
  check-handoffs \
  check-role-chain \
  check-test-matrix \
  check-scope \
  check-file-size \
  check-secrets; do
  cat > "$TMP_DIR/scripts/gates/${script_name}.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "[PASS] ${script_name}"
EOF
  chmod +x "$TMP_DIR/scripts/gates/${script_name}.sh"
done

cat > "$TMP_DIR/scripts/context-log.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CONTEXT_COUNTER"
EOF
chmod +x "$TMP_DIR/scripts/context-log.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-1
EOF

cat > "$TMP_DIR/docs/context/PROJECT.md" <<'EOF'
# Project Brief
EOF

cat > "$TMP_DIR/docs/context/CONVENTIONS.md" <<'EOF'
# Coding Conventions
EOF

cat > "$TMP_DIR/docs/context/ARCHITECTURE.md" <<'EOF'
# Architecture Boundaries
EOF

cat > "$TMP_DIR/docs/context/RULES.md" <<'EOF'
# Implementer Rules
EOF

cat > "$TMP_DIR/docs/context/GATES.md" <<'EOF'
# Gate Policy
EOF

cat > "$TMP_DIR/docs/features/feature-1/brief.md" <<'EOF'
# Feature Brief
EOF

cat > "$TMP_DIR/docs/features/feature-1/plan.md" <<'EOF'
# Feature Plan
EOF

cat > "$TMP_DIR/docs/features/feature-1/implementer-handoff.md" <<'EOF'
# Implementer Handoff
EOF

cat > "$TMP_DIR/docs/features/feature-1/tester-handoff.md" <<'EOF'
# Tester Handoff
EOF

cat > "$TMP_DIR/docs/features/feature-1/reviewer-handoff.md" <<'EOF'
# Reviewer Handoff
EOF

cat > "$TMP_DIR/docs/features/feature-1/security-handoff.md" <<'EOF'
# Security Handoff
EOF

cat > "$TMP_DIR/docs/features/feature-1/test-matrix.md" <<'EOF'
# Test Matrix
EOF

cat > "$TMP_DIR/docs/features/feature-1/run-log.md" <<'EOF'
# Run Log
EOF

cd "$TMP_DIR"
git init -q

export FEATURE_COUNTER="$COUNTER_DIR/feature.log"
export INFRA_COUNTER="$COUNTER_DIR/infra.log"
export CONTEXT_COUNTER="$COUNTER_DIR/context.log"

bash scripts/gates/check-tests.sh --feature --feature-id feature-1 >/dev/null
[[ -f "$FEATURE_COUNTER" ]]
if [[ -f "$INFRA_COUNTER" ]]; then
  echo "[FAIL] feature-only tester path should not run infra tests"
  exit 1
fi
[[ -f "docs/features/feature-1/artifacts/tests/feature.json" ]]

rm -f "$FEATURE_COUNTER" "$INFRA_COUNTER"

fast_output="$(bash scripts/gates/run.sh --fast feature-1)"
printf '%s\n' "$fast_output" | grep -Fq '[INFO] reusing feature test receipt:'
[[ ! -f "$FEATURE_COUNTER" ]]
[[ ! -f "$INFRA_COUNTER" ]]
if [[ -f "docs/features/feature-1/artifacts/gates/full.json" ]]; then
  echo "[FAIL] fast gate should not write full gate receipts"
  exit 1
fi

rm -f "$FEATURE_COUNTER" "$INFRA_COUNTER"

run_output="$(bash scripts/gates/run.sh feature-1)"
printf '%s\n' "$run_output" | grep -Fq '[INFO] reusing feature test receipt:'
[[ ! -f "$FEATURE_COUNTER" ]]
grep -Fq 'context-log' "$INFRA_COUNTER"
grep -Fq 'run-log' "$INFRA_COUNTER"
grep -Fq 'stage-closeout' "$INFRA_COUNTER"
grep -Fq 'workflow-mode' "$INFRA_COUNTER"
grep -Fq 'execution-mode' "$INFRA_COUNTER"
grep -Fq 'promote-workflow' "$INFRA_COUNTER"
grep -Fq 'start-feature' "$INFRA_COUNTER"
grep -Fq 'implementer-subtasks' "$INFRA_COUNTER"
[[ -f "docs/features/feature-1/artifacts/gates/full.json" ]]

rm -f "$FEATURE_COUNTER" "$INFRA_COUNTER"

reuse_output="$(bash scripts/gates/run.sh --reuse-if-valid feature-1)"
printf '%s\n' "$reuse_output" | grep -Fq '[PASS] full gate receipt reused: feature-1'
[[ ! -f "$FEATURE_COUNTER" ]]
[[ ! -f "$INFRA_COUNTER" ]]

bash scripts/complete-feature.sh feature-1 "summary" "next" >/dev/null
[[ ! -f "$FEATURE_COUNTER" ]]
[[ ! -f "$INFRA_COUNTER" ]]
grep -Fq 'note Feature feature-1 completed. All gates passed.' "$CONTEXT_COUNTER"

echo "[PASS] gate-cache smoke"
