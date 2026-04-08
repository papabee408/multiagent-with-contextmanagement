#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts" \
  "$TMP_DIR/docs/features/feature-standard/artifacts/roles" \
  "$TMP_DIR/docs/features/feature-standard/artifacts/gates" \
  "$TMP_DIR/docs/features/feature-override/artifacts/roles" \
  "$TMP_DIR/docs/features/feature-override/artifacts/gates" \
  "$TMP_DIR/docs/features/feature-high-risk/artifacts/roles" \
  "$TMP_DIR/docs/features/_template"

cp "$ROOT_DIR/scripts/report-template-kpis.sh" "$TMP_DIR/scripts/report-template-kpis.sh"
chmod +x "$TMP_DIR/scripts/report-template-kpis.sh"

cat > "$TMP_DIR/docs/features/feature-standard/brief.md" <<'EOF'
# Feature Brief

## Risk Class
- class: `standard`

## Workflow Mode
- mode: `lite`

## Execution Mode
- mode: `single`
EOF

cat > "$TMP_DIR/docs/features/feature-override/brief.md" <<'EOF'
# Feature Brief

## Risk Class
- class: `standard`

## Workflow Mode
- mode: `full`

## Execution Mode
- mode: `single`
EOF

cat > "$TMP_DIR/docs/features/feature-high-risk/brief.md" <<'EOF'
# Feature Brief

## Risk Class
- class: `high-risk`

## Workflow Mode
- mode: `full`

## Execution Mode
- mode: `multi-agent`
EOF

cat > "$TMP_DIR/docs/features/feature-standard/artifacts/roles/planner.json" <<'EOF'
{ "updated_at_utc": "2026-03-27 01:00:00Z" }
EOF
cat > "$TMP_DIR/docs/features/feature-standard/artifacts/roles/gate-checker.json" <<'EOF'
{ "updated_at_utc": "2026-03-27 01:10:00Z" }
EOF
cat > "$TMP_DIR/docs/features/feature-standard/artifacts/gates/full.json" <<'EOF'
{ "result": "PASS" }
EOF

cat > "$TMP_DIR/docs/features/feature-override/artifacts/roles/planner.json" <<'EOF'
{ "updated_at_utc": "2026-03-27 02:00:00Z" }
EOF
cat > "$TMP_DIR/docs/features/feature-override/artifacts/roles/gate-checker.json" <<'EOF'
{ "updated_at_utc": "2026-03-27 02:30:00Z" }
EOF
cat > "$TMP_DIR/docs/features/feature-override/artifacts/gates/full.json" <<'EOF'
{ "result": "PASS" }
EOF

cat > "$TMP_DIR/docs/features/feature-high-risk/artifacts/roles/planner.json" <<'EOF'
{ "updated_at_utc": "2026-03-27 03:00:00Z" }
EOF
cat > "$TMP_DIR/docs/features/feature-high-risk/artifacts/roles/gate-checker.json" <<'EOF'
{ "updated_at_utc": "2026-03-27 03:20:00Z" }
EOF

cd "$TMP_DIR"

full_output="$(bash scripts/report-template-kpis.sh)"
printf '%s\n' "$full_output" | grep -Fq '# Template KPI Report'
printf '%s\n' "$full_output" | grep -Fq 'Feature packets: 3'
printf '%s\n' "$full_output" | grep -Fq 'Workflow overrides: 1/3 (33.3%)'
printf '%s\n' "$full_output" | grep -Fq 'High-risk compliance: 1/1 (100.0%)'
printf '%s\n' "$full_output" | grep -Fq 'Full gate PASS coverage: 2/3 (66.7%)'
printf '%s\n' "$full_output" | grep -Fq 'Average planner-to-gate-checker minutes: 20.0 (samples: 3)'
printf '%s\n' "$full_output" | grep -Fq 'standard-or-trivial-in-full: 1'
printf '%s\n' "$full_output" | grep -Fq 'packets-without-pass-full-gate: 1'

maintenance_output="$(bash scripts/report-template-kpis.sh --maintenance-section)"
printf '%s\n' "$maintenance_output" | grep -Fq '### Workflow Mix'
printf '%s\n' "$maintenance_output" | grep -Fq -- '- full: 2 (66.7%)'
printf '%s\n' "$maintenance_output" | grep -Fq -- '- multi-agent: 1 (33.3%)'

echo "[PASS] report-template-kpis smoke"
