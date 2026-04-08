#!/usr/bin/env bash

# This helper expects the caller to have already sourced `_helpers.sh`
# so that ROOT_DIR, FEATURE_ID, FEATURE_DIR, changed_files, and sha256_file exist.

validation_cache_artifacts_dir() {
  local feature_id="$1"
  printf '%s/docs/features/%s/artifacts' "$ROOT_DIR" "$feature_id"
}

feature_test_receipt_file() {
  local feature_id="$1"
  printf '%s/tests/feature.json' "$(validation_cache_artifacts_dir "$feature_id")"
}

full_gate_receipt_file() {
  local feature_id="$1"
  printf '%s/gates/full.json' "$(validation_cache_artifacts_dir "$feature_id")"
}

ensure_validation_cache_dirs() {
  local feature_id="$1"
  mkdir -p \
    "$(validation_cache_artifacts_dir "$feature_id")/tests" \
    "$(validation_cache_artifacts_dir "$feature_id")/gates"
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{ print $1 }'
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{ print $1 }'
    return 0
  fi

  echo "[ERROR] sha256 tool not found" >&2
  exit 1
}

node_version_or_missing() {
  node --version 2>/dev/null || printf '%s\n' "missing"
}

manifest_digest_line() {
  local path="$1"
  local absolute_path="$ROOT_DIR/$path"
  local digest="missing"

  if [[ -f "$absolute_path" ]]; then
    digest="$(sha256_file "$absolute_path")"
  fi

  printf '%s\t%s\n' "$path" "$digest"
}

manifest_digest_glob() {
  local pattern="$1"
  find "$ROOT_DIR" -path "$ROOT_DIR/$pattern" -type f | sort | while IFS= read -r absolute_path; do
    relative_path="${absolute_path#$ROOT_DIR/}"
    manifest_digest_line "$relative_path"
  done
}

changed_file_manifest() {
  local artifacts_prefix="docs/features/$FEATURE_ID/artifacts/"

  changed_files | while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    if [[ "$relative_path" == "$artifacts_prefix"* ]]; then
      continue
    fi
    manifest_digest_line "$relative_path"
  done
}

packet_manifest() {
  local feature_id="$1"
  local packet_dir="docs/features/$feature_id"
  local relative_path

  for relative_path in \
    "$packet_dir/brief.md" \
    "$packet_dir/plan.md" \
    "$packet_dir/implementer-handoff.md" \
    "$packet_dir/tester-handoff.md" \
    "$packet_dir/reviewer-handoff.md" \
    "$packet_dir/security-handoff.md" \
    "$packet_dir/test-matrix.md" \
    "$packet_dir/run-log.md"; do
    manifest_digest_line "$relative_path"
  done
}

context_manifest() {
  local relative_path
  for relative_path in \
    "docs/context/PROJECT.md" \
    "docs/context/CONVENTIONS.md" \
    "docs/context/ARCHITECTURE.md" \
    "docs/context/RULES.md" \
    "docs/context/GATES.md"; do
    manifest_digest_line "$relative_path"
  done
}

feature_tests_fingerprint() {
  local feature_id="$1"

  {
    echo "kind=feature-tests"
    echo "feature-id=$feature_id"
    echo "node-version=$(node_version_or_missing)"
    manifest_digest_line "scripts/gates/check-tests.sh"
    manifest_digest_glob "tests/unit/*.test.mjs"
    packet_manifest "$feature_id"
    changed_file_manifest
  } | sha256_stdin
}

full_gate_fingerprint() {
  local feature_id="$1"

  {
    echo "kind=full-gate"
    echo "feature-id=$feature_id"
    echo "node-version=$(node_version_or_missing)"
    manifest_digest_line "scripts/gates/run.sh"
    manifest_digest_line "scripts/gates/check-tests.sh"
    manifest_digest_glob "scripts/gates/*.sh"
    manifest_digest_glob "scripts/*.sh"
    manifest_digest_glob "tests/*.test.sh"
    context_manifest
    packet_manifest "$feature_id"
    changed_file_manifest
  } | sha256_stdin
}

json_receipt_field() {
  local file="$1"
  local field="$2"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const field = process.argv[2];
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      process.stdout.write(String(data[field]));
    }
  ' "$file" "$field"
}

write_feature_test_receipt() {
  local feature_id="$1"
  local mode="$2"
  local fingerprint="$3"
  local result="$4"
  local command="$5"
  local file

  file="$(feature_test_receipt_file "$feature_id")"
  ensure_validation_cache_dirs "$feature_id"

  FILE="$file" \
  FEATURE_ID="$feature_id" \
  MODE="$mode" \
  FINGERPRINT="$fingerprint" \
  RESULT="$result" \
  COMMAND_VALUE="$command" \
  EXECUTED_AT_UTC="$(utc_now)" \
  SCRIPT_SHA="$(sha256_file "$ROOT_DIR/scripts/gates/check-tests.sh")" \
  NODE_VERSION_VALUE="$(node_version_or_missing)" \
  node <<'EOF'
const fs = require("fs");
const path = require("path");

const file = process.env.FILE;
fs.mkdirSync(path.dirname(file), { recursive: true });
fs.writeFileSync(
  file,
  JSON.stringify(
    {
      kind: "feature-tests",
      feature_id: process.env.FEATURE_ID,
      mode: process.env.MODE,
      fingerprint: process.env.FINGERPRINT,
      result: process.env.RESULT,
      command: process.env.COMMAND_VALUE,
      executed_at_utc: process.env.EXECUTED_AT_UTC,
      script_sha: process.env.SCRIPT_SHA,
      node_version: process.env.NODE_VERSION_VALUE,
    },
    null,
    2,
  ) + "\n",
);
EOF
}

write_full_gate_receipt() {
  local feature_id="$1"
  local fingerprint="$2"
  local result="$3"
  local tests_fingerprint="$4"
  local command="$5"
  local file

  file="$(full_gate_receipt_file "$feature_id")"
  ensure_validation_cache_dirs "$feature_id"

  FILE="$file" \
  FEATURE_ID="$feature_id" \
  FINGERPRINT="$fingerprint" \
  RESULT="$result" \
  TESTS_FINGERPRINT="$tests_fingerprint" \
  COMMAND_VALUE="$command" \
  EXECUTED_AT_UTC="$(utc_now)" \
  SCRIPT_SHA="$(sha256_file "$ROOT_DIR/scripts/gates/run.sh")" \
  node <<'EOF'
const fs = require("fs");
const path = require("path");

const file = process.env.FILE;
fs.mkdirSync(path.dirname(file), { recursive: true });
fs.writeFileSync(
  file,
  JSON.stringify(
    {
      kind: "full-gate",
      feature_id: process.env.FEATURE_ID,
      fingerprint: process.env.FINGERPRINT,
      result: process.env.RESULT,
      tests_fingerprint: process.env.TESTS_FINGERPRINT,
      command: process.env.COMMAND_VALUE,
      executed_at_utc: process.env.EXECUTED_AT_UTC,
      script_sha: process.env.SCRIPT_SHA,
    },
    null,
    2,
  ) + "\n",
);
EOF
}
