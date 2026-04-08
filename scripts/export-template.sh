#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/codex-template-multi-agent-process}"

copy_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
}

prune_template_exclusions() {
  local root="$1"

  rm -f \
    "$root/docs/context/HANDOFF.md" \
    "$root/docs/context/CODEX_RESUME.md" \
    "$root/docs/context/MAINTENANCE_STATUS.md"

  rm -rf "$root/docs/context/sessions"
}

copy_dir() {
  local src="$1"
  local dest="$2"
  mkdir -p "$dest"
  cp -R "$src"/. "$dest"/
}

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

copy_file "$ROOT_DIR/.gitignore" "$OUTPUT_DIR/.gitignore"
copy_file "$ROOT_DIR/AGENTS.md" "$OUTPUT_DIR/AGENTS.md"
copy_file "$ROOT_DIR/README.md" "$OUTPUT_DIR/README.md"
copy_file "$ROOT_DIR/UPGRADE_PROMPT.md" "$OUTPUT_DIR/UPGRADE_PROMPT.md"
copy_file "$ROOT_DIR/test-guide.md" "$OUTPUT_DIR/test-guide.md"

copy_dir "$ROOT_DIR/.github" "$OUTPUT_DIR/.github"
copy_dir "$ROOT_DIR/docs/agents" "$OUTPUT_DIR/docs/agents"
copy_dir "$ROOT_DIR/docs/context" "$OUTPUT_DIR/docs/context"
prune_template_exclusions "$OUTPUT_DIR"
copy_dir "$ROOT_DIR/docs/features/_template" "$OUTPUT_DIR/docs/features/_template"
copy_file "$ROOT_DIR/docs/features/README.md" "$OUTPUT_DIR/docs/features/README.md"
copy_dir "$ROOT_DIR/scripts" "$OUTPUT_DIR/scripts"
copy_dir "$ROOT_DIR/tests" "$OUTPUT_DIR/tests"

rm -f "$OUTPUT_DIR/scripts/export-template.sh"
rm -rf "$OUTPUT_DIR/docs/plans"
rm -rf "$OUTPUT_DIR/docs/features/template-ops-hardening"

find "$OUTPUT_DIR" -name ".DS_Store" -delete
find "$OUTPUT_DIR" -type d -name "artifacts" -prune -exec rm -rf {} +

cat > "$OUTPUT_DIR/TEMPLATE_USAGE.md" <<'EOF'
# Template Usage

This folder is the copyable export of the multi-agent harness template.

## New Project

1. Copy everything in this folder into the new repository root.
2. Customize `docs/context/PROJECT.md` first.
3. Customize `docs/context/ARCHITECTURE.md`, `docs/context/CONVENTIONS.md`, and `docs/context/RULES.md` to match the real project.
4. Run:

```bash
scripts/context-log.sh resume-lite
scripts/check-project-setup.sh
scripts/start-feature.sh bootstrap-template
bash scripts/gates/check-tests.sh --full
```

5. If the repo slug in `docs/context/PROJECT.md` is still `context+MultiAgentDev`, `scripts/gates/check-project-context.sh` should fail until you update it.

## Existing Project Migration

Do not blindly overwrite the target repo root.

Recommended flow:

1. Copy this folder into the existing repository as `codex-template-multi-agent-process/`.
2. Open `UPGRADE_PROMPT.md`.
3. Give that prompt to the coding agent and set:
   - `<TEMPLATE_DIR>` = `codex-template-multi-agent-process`
4. Let the agent merge the template in stages instead of replacing project files wholesale.

Use this mode when the target repo already has:
- its own `README.md`
- its own `AGENTS.md`
- its own CI/workflows
- existing test commands or contributor conventions
EOF

cat > "$OUTPUT_DIR/MIGRATE_EXISTING_PROJECT.md" <<'EOF'
# Existing Project Migration Guide

Use this template as a source bundle, not as a blind overwrite.

## Recommended Migration Sequence

1. Copy this folder into the target repo under:

```text
codex-template-multi-agent-process/
```

2. Keep the target repo's root files in place.
   - Do not overwrite `README.md`, `AGENTS.md`, or existing CI files by hand.

3. Run the upgrade via the bundled prompt:
   - open `codex-template-multi-agent-process/UPGRADE_PROMPT.md`
   - pass it to the agent
   - set `<TEMPLATE_DIR>` if needed

4. Migrate in this order:
   - visibility and operator wrappers
   - gate scripts
   - role/docs merge
   - CI hookup

5. After the merge, run the target repo's adapted verification commands.

## Files Usually Safe To Bring Over Early

- `scripts/dispatch-heartbeat.sh`
- `scripts/dispatch-role.sh`
- `scripts/record-role-result.sh`
- `scripts/finish-role.sh`
- `docs/features/_template/*`
- `docs/agents/*`
- `scripts/gates/*`

## Files That Usually Need Careful Merge

- `README.md`
- `AGENTS.md`
- `.github/workflows/gates.yml`
- `scripts/gates/check-tests.sh`
- `docs/context/PROJECT.md`
- `docs/context/ARCHITECTURE.md`

These often contain repo-specific assumptions and should be adapted, not blindly copied.
EOF

echo "[OK] template exported to: $OUTPUT_DIR"
