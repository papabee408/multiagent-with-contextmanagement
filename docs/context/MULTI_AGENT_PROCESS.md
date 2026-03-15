# Multi-Agent Process

이 문서는 현재 템플릿의 실제 동작을 정리한 운영 문서다.
설명보다 구현과 테스트를 우선한다.

이 문서와 코드가 충돌하면 아래 순서를 source of truth로 본다.

1. `docs/agents/*.md`
2. `AGENTS.md`
3. `scripts/*.sh`
4. `scripts/gates/*.sh`
5. `tests/*.sh`, `tests/unit/*.mjs`
6. `docs/features/_template/*`

## 목적

- 역할별 기본 입력을 작게 유지한다.
- feature packet 단위로 문서와 검증을 묶는다.
- 사람이 아니라 shell gate 결과로 완료 가능 여부를 판정한다.
- `run-log.md`에 dispatch 상태와 역할별 결과를 남긴다.

## 핵심 모델

- `feature-id`는 packet 경로를 가리키는 식별자다.
- 단, 일부 명령은 `.context/active_feature`를 fallback으로 사용한다.
- `plan.md`는 planner의 원본 설계서다.
- downstream 역할은 기본적으로 자기 역할 전용 `*-handoff.md`를 읽는다.
- `run-log.md`는 orchestrator만의 문서가 아니다.
  - orchestrator는 `Dispatch Monitor`를 갱신한다.
  - 7개 역할은 모두 자기 결과 레코드를 남겨야 한다.
- gate는 packet 문서 형식, 역할 결과 형식, 변경 범위, 테스트 실행 결과를 함께 본다.

## Feature Packet

위치:

- `docs/features/<feature-id>/`

필수 파일:

- `brief.md`
- `plan.md`
- `implementer-handoff.md`
- `tester-handoff.md`
- `reviewer-handoff.md`
- `security-handoff.md`
- `test-matrix.md`
- `run-log.md`

보조 파일:

- `.baseline-changes.txt`
  - `scripts/feature-packet.sh`가 packet 생성 시점의 기존 dirty 파일을 스냅샷한다.
  - `scope` / `file-size` gate는 이 baseline 이전 변경을 무시한다.

생성/선택 방식:

- 새 packet 또는 기존 packet 전환의 공식 진입점은 `scripts/start-feature.sh <feature-id>`다.
- 기존 packet만 활성화하고 싶을 때는 `scripts/set-active-feature.sh <feature-id>`를 쓴다.
- `scripts/feature-packet.sh <feature-id>`는 packet만 직접 만든다.

## 실제 작업 흐름

### 1. Context bootstrap

```bash
scripts/context-log.sh resume-lite
```

실제 효과:

- `docs/context/*` 기본 파일이 없으면 생성한다.
- `docs/context/HANDOFF.md`와 `docs/context/CODEX_RESUME.md`를 준비한다.
- 다음 세션에서 읽을 resume prompt를 출력한다.

### 2. Feature bootstrap

```bash
scripts/start-feature.sh <feature-id>
```

실제 효과:

- `.context/`를 보장한다.
- `.context/setup-check.done`가 없으면 먼저 `scripts/check-project-setup.sh`를 실행한다.
- packet이 없으면 `scripts/feature-packet.sh`로 생성한다.
- packet이 있으면 `scripts/set-active-feature.sh`로 활성 feature만 바꾼다.

### 3. Dispatch visibility

오케스트레이터는 `scripts/dispatch-heartbeat.sh`로 `run-log.md`의 `Dispatch Monitor`를 갱신한다.

```bash
scripts/dispatch-heartbeat.sh queue <role> "<next action>"
scripts/dispatch-heartbeat.sh start <role> "<first concrete action>"
scripts/dispatch-heartbeat.sh progress <role> "<file/command/blocker>"
scripts/dispatch-heartbeat.sh risk <role> "<why at risk>"
scripts/dispatch-heartbeat.sh blocked <role> "<why blocked>"
scripts/dispatch-heartbeat.sh done <role> "<what finished>"
scripts/dispatch-heartbeat.sh show
```

반복 입력을 줄이려면 wrapper를 쓸 수 있다.

```bash
scripts/dispatch-role.sh <role> "<next action>"
scripts/record-role-result.sh <role> --agent-id <id> --scope "<scope>" --rq-covered "<rq>" --rq-missing "<rq>" --result PASS|FAIL|BLOCKED --evidence "<evidence>" --next-action "<next>"
scripts/finish-role.sh <role> "<done message>" --next-role <role> --next-action "<next action>"
```

주의:

- `dispatch-heartbeat.sh`는 `Dispatch Monitor`만 수정한다.
- 역할별 결과 섹션은 `scripts/record-role-result.sh`로 갱신할 수 있다.
- `scripts/record-role-result.sh`는 대응되는 `docs/features/<feature-id>/artifacts/roles/<role>.json` receipt도 함께 갱신한다.
- `show`, `gates/run.sh`, `complete-feature.sh`는 `feature-id`를 생략하면 `.context/active_feature`를 쓸 수 있다.

### 4. 역할 순서

정상 순서:

1. `planner`
2. `implementer`
3. `tester`
4. `gate-checker`
5. `reviewer`
6. `security`

상태 전이 규칙:

- `reviewer = FAIL`이면 `security`는 `BLOCKED`여야 한다.
- `security = PASS`는 `reviewer = PASS`일 때만 허용된다.
- `implementer = PASS`는 `planner = PASS`일 때만 허용된다.

위 3개는 `role-chain` gate가 실제로 강제한다.

### 5. 검증

가장 작은 테스트 검증:

```bash
bash scripts/gates/check-tests.sh --feature
```

실제 실행 항목:

- `node --test tests/unit/*.test.mjs`

인프라 smoke/regression만 따로 돌리고 싶으면:

```bash
bash scripts/gates/check-tests.sh --infra
```

전체 테스트 묶음:

```bash
bash scripts/gates/check-tests.sh --full
```

전체 gate:

```bash
scripts/gates/run.sh <feature-id>
scripts/gates/run.sh --reuse-if-valid <feature-id>
```

`run.sh` 안에는 이미 `tests` gate가 포함되어 있다.
즉 tester는 `--feature`를 책임지고, gate-checker는 `run.sh`를 통해 현재 feature receipt를 재사용하거나 feature 테스트를 다시 실행한 뒤 infra 테스트를 반드시 다시 도는 식으로 책임을 나눈다.

재사용 규칙:

- tester의 `--feature` 성공 결과는 `docs/features/<feature-id>/artifacts/tests/feature.json`에 기록된다.
- gate-checker의 `run.sh`는 위 receipt가 현재 fingerprint와 일치하면 feature 테스트를 재사용하고 infra 테스트만 다시 돈다.
- `run.sh --reuse-if-valid`는 전체 gate PASS receipt가 현재 fingerprint와 일치할 때 gate 전체를 재사용한다.
- `scripts/complete-feature.sh`는 이 옵션을 사용해 완료 직전 중복 gate 실행을 줄인다.

### 6. 완료 처리

```bash
scripts/complete-feature.sh <feature-id> "<summary>" "<next-step>"
```

실제 효과:

- active feature를 맞춘다.
- `scripts/gates/run.sh --reuse-if-valid <feature-id>`를 실행한다.
- active context session이 없으면 새 세션을 연다.
- `context-log.sh note`와 `context-log.sh finish`를 호출해 `docs/context/*`를 갱신한다.

## Role Contract Summary

아래는 현재 역할 문서가 요구하는 기본 계약이다.
`Must Read`는 운영 계약이고, gate가 전부를 직접 강제하는 것은 아니다.

### `orchestrator`

기본 입력:

- `docs/features/<feature-id>/brief.md`
- `docs/features/<feature-id>/run-log.md`
- `docs/context/PROJECT.md`
- `docs/context/GATES.md`
- `docs/context/HANDOFF.md`
- `docs/context/CODEX_RESUME.md`

주요 책임:

- packet 존재 보장
- 역할 순서 dispatch
- `Dispatch Monitor` 유지
- 최종 요약과 다음 액션 결정
- `context-log` 기록

제약:

- `plan.md`를 직접 작성하거나 수정하면 안 된다.

### `planner`

기본 입력:

- `docs/features/<feature-id>/brief.md`
- `docs/features/<feature-id>/test-matrix.md`
- `docs/context/PROJECT.md`
- `docs/context/ARCHITECTURE.md`
- `docs/context/GATES.md`

주요 산출물:

- `plan.md`
- `scripts/sync-handoffs.sh <feature-id>`를 통해 갱신되는 `implementer-handoff.md`
- `scripts/sync-handoffs.sh <feature-id>`를 통해 갱신되는 `tester-handoff.md`
- `scripts/sync-handoffs.sh <feature-id>`를 통해 갱신되는 `reviewer-handoff.md`
- `scripts/sync-handoffs.sh <feature-id>`를 통해 갱신되는 `security-handoff.md`
- `scripts/sync-handoffs.sh <feature-id>`를 통해 seed/refresh 되는 `test-matrix.md`

주의:

- `planner.scope`는 `plan.md`를 포함해야 한다.
- downstream handoff와 `test-matrix.md`를 planner가 `scripts/sync-handoffs.sh <feature-id>`로 refresh한다는 것이 운영 계약이다.

### `implementer`

기본 입력:

- `docs/features/<feature-id>/implementer-handoff.md`
- `docs/context/RULES.md`

선택 재오픈:

- `docs/context/CONVENTIONS.md`
- `docs/features/<feature-id>/plan.md`
- `docs/context/ARCHITECTURE.md`

주요 책임:

- planner 승인 범위만 구현

### `tester`

기본 입력:

- `docs/features/<feature-id>/tester-handoff.md`
- `docs/features/<feature-id>/test-matrix.md`
- `docs/context/GATES.md`
- `test-guide.md`
- implementer diff

필수 커맨드:

- `scripts/gates/check-tests.sh --feature`

주요 책임:

- 테스트 추가/수정
- 실제 실행한 테스트 기준으로 `test-matrix.md`를 `VERIFIED` 상태로 닫기

### `gate-checker`

기본 입력 계약:

- `docs/features/<feature-id>/plan.md`
- `docs/context/GATES.md`
- changed file list

실제 실행 커맨드:

- `scripts/gates/run.sh <feature-id>`

중요:

- 문서상 입력은 `plan.md + GATES.md + changed files`로 보이지만, 실제 `run.sh`는 packet 전체와 context 문서, 테스트, secrets까지 모두 소비한다.

### `reviewer`

기본 입력:

- `docs/features/<feature-id>/reviewer-handoff.md`
- implementer diff
- gate-checker output

주요 책임:

- 의미적 품질, 회귀 위험, scope drift, architecture fit 리뷰

### `security`

기본 입력:

- implementer diff
- relevant config/env usage
- `docs/features/<feature-id>/security-handoff.md`

전제 조건:

- `reviewer = PASS` 이후에만 실행

## `run-log.md`의 실제 의미

`run-log.md`는 두 부분으로 나뉜다.

### 1. `Dispatch Monitor`

필수 필드:

- `current-role`
- `current-status`
- `started-at-utc`
- `last-progress-at-utc`
- `interrupt-after-utc`
- `last-progress`

`role-chain` gate는 위 필드가 비어 있지 않은지와 timestamp ordering만 확인한다.

### 2. `Role Outputs`

필수 역할:

- `orchestrator`
- `planner`
- `implementer`
- `tester`
- `gate-checker`
- `reviewer`
- `security`

각 역할의 필수 필드:

- `agent-id`
- `scope`
- `rq_covered`
- `rq_missing`
- `result`
- `evidence`
- `next_action`

기계 검증용 mirror:

- 각 역할은 `docs/features/<feature-id>/artifacts/roles/<role>.json` receipt도 함께 가진다.
- `run-log.md`는 사람이 읽는 현재 상태와 역할 요약을 위한 문서다.
- role receipt는 gate가 role output 무결성을 검증하기 위한 구조화 정본이다.

실제 강제 규칙:

- 7개 역할 모두 섹션이 있어야 한다.
- `agent-id`는 역할 간 중복되면 안 된다.
- `agent-id`가 역할명 자체면 안 된다.
- `planner.scope`는 `plan.md`를 포함해야 한다.
- `orchestrator.scope`는 `plan.md`를 포함하면 안 된다.

## Gate가 실제로 보는 문서 형식

### `brief.md`

필수 섹션:

- `## Feature ID`
- `## Goal`
- `## Non-goals`
- `## Requirements (RQ)`
- `## Constraints`
- `## Acceptance`
- `## Requirement Notes`

`Requirement Notes` 필수 키:

- `External dependencies`
- `Existing modules/components/constants to reuse`
- `Values/config that must not be hardcoded`

모든 RQ는 설명이 채워져 있어야 한다.

### `plan.md`

필수 구조:

- `## Scope`
- `- target files:`
- `- out-of-scope files:`
- `## RQ -> Task Mapping`
- `## Architecture Notes`
- `## Reuse and Config Plan`
- `## Task Cards`

추가 강제:

- target file은 repo-relative, backtick-wrapped path로 한 줄에 하나씩 있어야 한다.
- `Architecture Notes`와 `Reuse and Config Plan`의 각 키가 비어 있으면 안 된다.
- task card마다 `files`, `change`, `done when`이 있어야 한다.

### `*-handoff.md`

각 handoff 파일은 존재만 하면 끝이 아니다.
아래 역할별 키가 채워져 있어야 한다.

- `implementer-handoff.md`
  - `rq_covered`
  - `target files`
  - `task order`
  - `out-of-scope reminders`
  - `architecture placement`
  - `dependency constraints`
  - `reuse / config directives`
  - `done when`
- `tester-handoff.md`
  - `rq coverage`
  - `required scenarios`
  - `priority risks`
  - `fixtures / mocks / setup`
  - `execution notes / commands`
  - `matrix expectations`
- `reviewer-handoff.md`
  - `regression hotspots`
  - `architecture / reuse focus`
  - `scope drift watchpoints`
  - `fail conditions`
- `security-handoff.md`
  - `validation / auth focus`
  - `secrets / config touchpoints`
  - `abuse / failure paths`
  - `fail conditions`

### `test-matrix.md`

필수 top-level 상태:

- `status: VERIFIED`
- `last-updated-utc`

각 RQ row 필수 컬럼:

- `Normal`
- `Error`
- `Boundary`
- `Test File`
- `Status`

추가 강제:

- `brief.md`의 모든 RQ가 row로 존재해야 한다.
- duplicate row는 실패다.
- 각 row의 `Status`도 `VERIFIED`여야 한다.

## Gate Summary

`scripts/gates/run.sh`가 실행하는 gate:

1. `project-context`
2. `packet`
3. `brief`
4. `plan`
5. `handoffs`
6. `role-chain`
7. `test-matrix`
8. `scope`
9. `file-size`
10. `tests`
11. `secrets`

각 gate의 실제 의미:

- `project-context`
  - `PROJECT.md`, `CONVENTIONS.md`, `ARCHITECTURE.md`, `RULES.md`, `GATES.md` 존재 확인
  - 앞의 4개 문서는 섹션 누락/placeholder/stale template 내용도 검사
- `packet`
  - feature packet 필수 파일 존재
- `brief`
  - `brief.md` 스키마 검사
- `plan`
  - `plan.md` 스키마 검사
- `handoffs`
  - 4개 handoff 파일과 필수 키 검사
- `role-chain`
  - `run-log.md`의 역할 섹션, dispatch monitor, 상태 전이, `agent-id` 유일성, `plan.md` ownership 검사
- `test-matrix`
  - `VERIFIED` 상태와 row completeness 검사
- `scope`
  - 변경 파일이 `plan.md` target files를 벗어났는지 검사
  - 단, `docs/*`, `README.md`, `AGENTS.md`는 예외 허용
- `file-size`
  - 특정 코드 파일 확장자에 대해 라인 수 정책 검사
- `tests`
  - feature receipt가 현재 fingerprint와 일치하면 재사용
  - 아니면 `scripts/gates/check-tests.sh --feature --feature-id <feature-id>` 실행
  - 항상 `scripts/gates/check-tests.sh --infra` 실행
- `secrets`
  - 하드코딩된 secret 패턴 검사

## 운영 규칙과 gate 강제 규칙의 차이

현재 저장소는 아래 두 층으로 움직인다.

### 운영 계약

역할 문서와 `AGENTS.md`에 적힌 규칙이다.

예:

- downstream 역할은 기본적으로 자기 handoff만 읽는다.
- orchestrator는 45초/90초/120초 기준으로 risk 또는 interrupt 판단을 한다.
- planner가 `plan.md`를 정본으로 갱신하고 `scripts/sync-handoffs.sh <feature-id>`로 handoff와 test-matrix 초기화를 맡는다.

### gate 강제 규칙

shell script가 실제로 FAIL을 내는 규칙이다.

예:

- `run-log.md` 형식
- `agent-id` 유일성
- `brief.md` / `plan.md` / `handoff.md` / `test-matrix.md`의 비어 있지 않은 필드
- 테스트 실행 성공
- scope/file-size/secrets

운영 계약이 모두 shell로 자동 강제되는 것은 아니다.
반대로 gate가 강제하는 형식은 이 문서보다 `scripts/gates/*.sh`가 더 정확하다.

## 요약

현재 프로세스의 핵심은 아래 한 줄로 요약된다.

- planner가 packet 문서를 설계하고,
- downstream 역할은 handoff 중심으로 일하고,
- orchestrator는 `Dispatch Monitor`와 context-log를 관리하고,
- 최종 판정은 `scripts/gates/run.sh`의 raw PASS/FAIL로 한다.
