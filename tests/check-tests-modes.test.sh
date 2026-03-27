#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/tests/unit"

cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/gates/_validation_cache.sh" "$TMP_DIR/scripts/gates/_validation_cache.sh"
cp "$ROOT_DIR/scripts/gates/check-tests.sh" "$TMP_DIR/scripts/gates/check-tests.sh"

cat > "$TMP_DIR/tests/unit/feature-mode.test.mjs" <<'EOF'
import { test } from 'node:test';
import { appendFileSync } from 'node:fs';

test('feature-mode-marker', () => {
  appendFileSync('feature.log', 'feature\n');
});
EOF

cat > "$TMP_DIR/tests/context-log.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo context-log >> infra.log
EOF

cat > "$TMP_DIR/tests/gates.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo gates >> infra.log
EOF

cat > "$TMP_DIR/tests/dispatch-heartbeat.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo dispatch >> infra.log
EOF

cat > "$TMP_DIR/tests/run-log-ops.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo run-log >> infra.log
EOF

cat > "$TMP_DIR/tests/stage-closeout.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo stage-closeout >> infra.log
EOF

cat > "$TMP_DIR/tests/sync-handoffs.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo sync >> infra.log
EOF

cat > "$TMP_DIR/tests/workflow-mode.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo workflow-mode >> infra.log
EOF

cat > "$TMP_DIR/tests/execution-mode.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo execution-mode >> infra.log
EOF

cat > "$TMP_DIR/tests/promote-workflow.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo promote-workflow >> infra.log
EOF

cat > "$TMP_DIR/tests/start-feature.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo start-feature >> infra.log
EOF

cat > "$TMP_DIR/tests/implementer-subtasks.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo implementer-subtasks >> infra.log
EOF

cat > "$TMP_DIR/tests/check-tests-modes.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo mode-self >> infra.log
EOF

cat > "$TMP_DIR/tests/gate-cache.test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo gate-cache >> infra.log
EOF

chmod +x \
  "$TMP_DIR/scripts/gates/check-tests.sh" \
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

cd "$TMP_DIR"

bash scripts/gates/check-tests.sh --feature >/dev/null
grep -Fq 'feature' feature.log
if [[ -f infra.log ]]; then
  echo "[FAIL] feature mode should not run infra tests"
  exit 1
fi

rm -f feature.log infra.log

bash scripts/gates/check-tests.sh --infra >/dev/null
grep -Fq 'context-log' infra.log
grep -Fq 'gates' infra.log
grep -Fq 'dispatch' infra.log
grep -Fq 'run-log' infra.log
grep -Fq 'stage-closeout' infra.log
grep -Fq 'sync' infra.log
grep -Fq 'workflow-mode' infra.log
grep -Fq 'execution-mode' infra.log
grep -Fq 'promote-workflow' infra.log
grep -Fq 'start-feature' infra.log
grep -Fq 'implementer-subtasks' infra.log
grep -Fq 'mode-self' infra.log
grep -Fq 'gate-cache' infra.log
if [[ -f feature.log ]]; then
  echo "[FAIL] infra mode should not run feature tests"
  exit 1
fi

rm -f feature.log infra.log

bash scripts/gates/check-tests.sh --full >/dev/null
grep -Fq 'feature' feature.log
grep -Fq 'context-log' infra.log

echo "[PASS] check-tests modes smoke"
