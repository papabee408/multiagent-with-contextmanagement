#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/docs/features/feature-1/artifacts/roles" \
  "$TMP_DIR/docs/context" \
  "$TMP_DIR/docs/context/sessions" \
  "$TMP_DIR/src" \
  "$TMP_DIR/.context"

cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/stage-closeout.sh" "$TMP_DIR/scripts/stage-closeout.sh"
cp "$ROOT_DIR/scripts/complete-feature.sh" "$TMP_DIR/scripts/complete-feature.sh"
cp "$ROOT_DIR/scripts/set-active-feature.sh" "$TMP_DIR/scripts/set-active-feature.sh"

chmod +x \
  "$TMP_DIR/scripts/stage-closeout.sh" \
  "$TMP_DIR/scripts/complete-feature.sh" \
  "$TMP_DIR/scripts/set-active-feature.sh"

cat > "$TMP_DIR/scripts/gates/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "[PASS] full gate receipt reused: ${2:-feature-1}"
EOF
chmod +x "$TMP_DIR/scripts/gates/run.sh"

cat > "$TMP_DIR/scripts/context-log.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

command_name="${1:-}"
shift || true

mkdir -p docs/context/sessions .context

case "$command_name" in
  start)
    session_path="docs/context/sessions/20260327-closeout.md"
    printf '%s\n' "$session_path" > .context/active_session
    printf '# Session Log\n' > "$session_path"
    ;;
  note)
    :
    ;;
  finish)
    session_path="docs/context/sessions/20260327-closeout.md"
    printf '# Current Handoff\n\n- done\n' > docs/context/HANDOFF.md
    printf '# Codex Resume Snapshot\n\n- ready\n' > docs/context/CODEX_RESUME.md
    printf '# Context Maintenance Status\n\n- ok\n' > docs/context/MAINTENANCE_STATUS.md
    printf '## Session Summary\n- %s\n' "${1:-summary}" >> "$session_path"
    : > .context/active_session
    ;;
  *)
    :
    ;;
esac
EOF
chmod +x "$TMP_DIR/scripts/context-log.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-1
EOF

cat > "$TMP_DIR/docs/features/feature-1/run-log.md" <<'EOF'
# Run Log
EOF

cat > "$TMP_DIR/docs/context/sessions/20260326-unrelated.md" <<'EOF'
# Another Session
EOF

cat > "$TMP_DIR/src/keep-unstaged.txt" <<'EOF'
leave me alone
EOF

cd "$TMP_DIR"
git init -q
git config user.name "Codex Test"
git config user.email "codex-test@example.com"
git add .
git commit -qm "test fixture"

complete_output="$(bash scripts/complete-feature.sh feature-1 "summary" "next")"
printf '%s\n' "$complete_output" | grep -Fq '[OK] staged closeout files for feature: feature-1'
printf '%s\n' "$complete_output" | grep -Fq '[PASS] feature completion recorded: feature-1'

cached_files="$(git diff --cached --name-only | sort)"
printf '%s\n' "$cached_files" | grep -Fxq 'docs/context/CODEX_RESUME.md'
printf '%s\n' "$cached_files" | grep -Fxq 'docs/context/HANDOFF.md'
printf '%s\n' "$cached_files" | grep -Fxq 'docs/context/MAINTENANCE_STATUS.md'
printf '%s\n' "$cached_files" | grep -Fxq 'docs/context/sessions/20260327-closeout.md'

if printf '%s\n' "$cached_files" | grep -Fxq 'src/keep-unstaged.txt'; then
  echo "[FAIL] expected non-closeout file to remain unstaged"
  exit 1
fi

printf 'updated\n' >> docs/features/feature-1/run-log.md
printf '{}\n' > docs/features/feature-1/artifacts/roles/orchestrator.json
printf 'resume tweak\n' >> docs/context/CODEX_RESUME.md
printf 'unrelated\n' >> docs/context/sessions/20260326-unrelated.md
printf 'code change\n' >> src/keep-unstaged.txt

stage_output="$(bash scripts/stage-closeout.sh --feature feature-1)"
printf '%s\n' "$stage_output" | grep -Fq '[OK] staged closeout files for feature: feature-1'

cached_files="$(git diff --cached --name-only | sort)"
printf '%s\n' "$cached_files" | grep -Fxq 'docs/features/feature-1/artifacts/roles/orchestrator.json'
printf '%s\n' "$cached_files" | grep -Fxq 'docs/features/feature-1/run-log.md'
printf '%s\n' "$cached_files" | grep -Fxq 'docs/context/CODEX_RESUME.md'

if printf '%s\n' "$cached_files" | grep -Fxq 'src/keep-unstaged.txt'; then
  echo "[FAIL] expected non-closeout file to remain unstaged after helper run"
  exit 1
fi

if printf '%s\n' "$cached_files" | grep -Fxq 'docs/context/sessions/20260326-unrelated.md'; then
  echo "[FAIL] expected unrelated session file to remain unstaged after helper run"
  exit 1
fi

unstaged_output="$(git status --short)"
printf '%s\n' "$unstaged_output" | grep -Fq 'src/keep-unstaged.txt'
printf '%s\n' "$unstaged_output" | grep -Fq 'docs/context/sessions/20260326-unrelated.md'

echo "[PASS] stage-closeout smoke"
