#!/usr/bin/env bash

ROOT_DIR_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

role_receipt_dir() {
  local root_dir="$ROOT_DIR_DEFAULT"
  local feature_id=""

  if [[ $# -eq 1 ]]; then
    feature_id="$1"
  else
    root_dir="$1"
    feature_id="$2"
  fi

  printf '%s/docs/features/%s/artifacts/roles' "$root_dir" "$feature_id"
}

role_receipt_file() {
  local root_dir="$ROOT_DIR_DEFAULT"
  local feature_id=""
  local role=""

  if [[ $# -eq 2 ]]; then
    feature_id="$1"
    role="$2"
  else
    root_dir="$1"
    feature_id="$2"
    role="$3"
  fi

  printf '%s/%s.json' "$(role_receipt_dir "$root_dir" "$feature_id")" "$role"
}

ensure_role_receipt_dir() {
  local root_dir="$ROOT_DIR_DEFAULT"
  local feature_id=""

  if [[ $# -eq 1 ]]; then
    feature_id="$1"
  else
    root_dir="$1"
    feature_id="$2"
  fi

  mkdir -p "$(role_receipt_dir "$root_dir" "$feature_id")"
}

json_field_value_role() {
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

role_receipt_json_field() {
  json_field_value_role "$@"
}

json_field_exists_role() {
  local file="$1"
  local field="$2"

  if [[ ! -f "$file" ]]; then
    printf 'false'
    return 0
  fi

  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const field = process.argv[2];
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    process.stdout.write(
      Object.prototype.hasOwnProperty.call(data, field) ? "true" : "false",
    );
  ' "$file" "$field"
}

json_array_lines_role() {
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
    const value = data[field];
    if (Array.isArray(value) && value.length > 0) {
      process.stdout.write(value.join("\n") + "\n");
    }
  ' "$file" "$field"
}

role_input_digest() {
  local root_dir="${1:-$ROOT_DIR_DEFAULT}"

  {
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 \
        "$root_dir/scripts/_run_log_helpers.sh" \
        "$root_dir/scripts/_role_receipt_helpers.sh" \
        "$root_dir/scripts/record-role-result.sh"
    else
      sha256sum \
        "$root_dir/scripts/_run_log_helpers.sh" \
        "$root_dir/scripts/_role_receipt_helpers.sh" \
        "$root_dir/scripts/record-role-result.sh"
    fi
  } | if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{ print $1 }'
  else
    sha256sum | awk '{ print $1 }'
  fi
}

write_role_receipt_json() {
  local file="$1"
  local role="$2"
  local agent_id="$3"
  local scope="$4"
  local rq_covered="$5"
  local rq_missing="$6"
  local result="$7"
  local evidence="$8"
  local next_action="$9"
  local touched_files="${10}"
  local input_digest="${11}"

  mkdir -p "$(dirname "$file")"

  FILE="$file" \
  ROLE_VALUE="$role" \
  AGENT_ID="$agent_id" \
  SCOPE_VALUE="$scope" \
  RQ_COVERED_VALUE="$rq_covered" \
  RQ_MISSING_VALUE="$rq_missing" \
  RESULT_VALUE="$result" \
  EVIDENCE_VALUE="$evidence" \
  NEXT_ACTION_VALUE="$next_action" \
  TOUCHED_FILES_VALUE="$touched_files" \
  INPUT_DIGEST_VALUE="$input_digest" \
  UPDATED_AT_UTC="$(perl -MPOSIX -e 'print strftime("%Y-%m-%d %H:%M:%SZ", gmtime(time()))')" \
  node <<'EOF'
const fs = require("fs");
const path = require("path");

const parseTouchedFiles = (value) => {
  const raw = String(value || "").trim();
  if (!raw || raw === "[]" || /^none$/i.test(raw)) {
    return [];
  }
  return raw
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
};

const file = process.env.FILE;
fs.mkdirSync(path.dirname(file), { recursive: true });
fs.writeFileSync(
  file,
  JSON.stringify(
    {
      kind: "role-result",
      role: process.env.ROLE_VALUE,
      agent_id: process.env.AGENT_ID,
      scope: process.env.SCOPE_VALUE,
      rq_covered: process.env.RQ_COVERED_VALUE,
      rq_missing: process.env.RQ_MISSING_VALUE,
      result: process.env.RESULT_VALUE,
      evidence: process.env.EVIDENCE_VALUE,
      next_action: process.env.NEXT_ACTION_VALUE,
      touched_files: parseTouchedFiles(process.env.TOUCHED_FILES_VALUE),
      input_digest: process.env.INPUT_DIGEST_VALUE,
      updated_at_utc: process.env.UPDATED_AT_UTC,
    },
    null,
    2,
  ) + "\n",
);
EOF
}

write_role_receipt() {
  local feature_id="$1"
  local role="$2"
  local agent_id="$3"
  local scope="$4"
  local rq_covered="$5"
  local rq_missing="$6"
  local result="$7"
  local evidence="$8"
  local next_action="$9"
  local touched_files="${10}"
  local file

  file="$(role_receipt_file "$feature_id" "$role")"
  ensure_role_receipt_dir "$feature_id"
  write_role_receipt_json \
    "$file" \
    "$role" \
    "$agent_id" \
    "$scope" \
    "$rq_covered" \
    "$rq_missing" \
    "$result" \
    "$evidence" \
    "$next_action" \
    "$touched_files" \
    "$(role_input_digest "$ROOT_DIR_DEFAULT")"
}
