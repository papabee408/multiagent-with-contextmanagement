#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/.github/workflows" \
  "$TMP_DIR/docs/context" \
  "$TMP_DIR/docs/agents" \
  "$TMP_DIR/docs/features/_template" \
  "$TMP_DIR/docs/features" \
  "$TMP_DIR/tests" \
  "$TMP_DIR/scripts"

cat > "$TMP_DIR/.gitignore" <<'EOF'
# placeholder
EOF

cat > "$TMP_DIR/AGENTS.md" <<'EOF'
# Agents
EOF

cat > "$TMP_DIR/README.md" <<'EOF'
# README
EOF

cat > "$TMP_DIR/UPGRADE_PROMPT.md" <<'EOF'
# UPGRADE
EOF

cat > "$TMP_DIR/test-guide.md" <<'EOF'
# Test guide
EOF

cp "$ROOT_DIR/scripts/export-template.sh" "$TMP_DIR/scripts/export-template.sh"
cp "$ROOT_DIR/scripts/gates/check-tests.sh" "$TMP_DIR/scripts/check-tests.sh"
chmod +x \
  "$TMP_DIR/scripts/export-template.sh"

cat > "$TMP_DIR/.github/workflows/gates.yml" <<'EOF'
name: Gates
on: [push]
EOF

cat > "$TMP_DIR/docs/context/HANDOFF.md" <<'EOF'
# Handoff
EOF

cat > "$TMP_DIR/docs/context/CODEX_RESUME.md" <<'EOF'
# Resume
EOF

cat > "$TMP_DIR/docs/context/MAINTENANCE_STATUS.md" <<'EOF'
# Maintenance
EOF

mkdir -p "$TMP_DIR/docs/context/sessions/old"
cat > "$TMP_DIR/docs/context/sessions/old/session.md" <<'EOF'
session
EOF

cat > "$TMP_DIR/docs/context/GATES.md" <<'EOF'
# Gate Policy
EOF

cat > "$TMP_DIR/docs/agents/AGENT.md" <<'EOF'
# Agent
EOF

cat > "$TMP_DIR/docs/features/_template/brief.md" <<'EOF'
# Feature Brief
EOF

cat > "$TMP_DIR/docs/features/README.md" <<'EOF'
# Features
EOF

cat > "$TMP_DIR/docs/context/PROJECT.md" <<'EOF'
# Project Brief
EOF

cat > "$TMP_DIR/docs/context/ARCHITECTURE.md" <<'EOF'
# Architecture
EOF

cat > "$TMP_DIR/docs/context/CONVENTIONS.md" <<'EOF'
# Conventions
EOF

cat > "$TMP_DIR/docs/context/RULES.md" <<'EOF'
# Rules
EOF

cd "$TMP_DIR"
bash scripts/export-template.sh "$TMP_DIR/exported"

test -d "$TMP_DIR/exported/.github/workflows"
test -d "$TMP_DIR/exported/docs/agents"
test -d "$TMP_DIR/exported/docs/context"
test -d "$TMP_DIR/exported/docs/features/_template"
test -d "$TMP_DIR/exported/scripts"

if [[ -f "$TMP_DIR/exported/docs/context/HANDOFF.md" ]]; then
  echo "[FAIL] HANDOFF.md must be excluded from export"
  exit 1
fi
if [[ -f "$TMP_DIR/exported/docs/context/CODEX_RESUME.md" ]]; then
  echo "[FAIL] CODEX_RESUME.md must be excluded from export"
  exit 1
fi
if [[ -f "$TMP_DIR/exported/docs/context/MAINTENANCE_STATUS.md" ]]; then
  echo "[FAIL] MAINTENANCE_STATUS.md must be excluded from export"
  exit 1
fi
if [[ -d "$TMP_DIR/exported/docs/context/sessions" ]]; then
  echo "[FAIL] docs/context/sessions must be excluded from export"
  exit 1
fi

echo "[PASS] export-template smoke"
