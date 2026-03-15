# Multi-Agent Dev Quick Guide

이 저장소에서 자주 쓰는 명령을 한 곳에 모아둔 운영용 메모다.
명령이 기억 안 나면 여기부터 보면 된다.

## 문서 용도

- `README.md`
  - 현재 이 템플릿 레포를 운영할 때 보는 문서
  - 자주 쓰는 명령, heartbeat 확인, gate 실행 흐름 안내
- `docs/context/PROJECT.md`
  - 이 레포의 실제 목표, 제약, 운영 원칙
  - 템플릿을 다른 프로젝트에 복사했다면 가장 먼저 갱신해야 하는 파일
- `docs/context/CONVENTIONS.md`
  - 재사용, 컴포넌트화, 하드코딩 방지 기준
- `docs/context/ARCHITECTURE.md`, `docs/context/RULES.md`
  - 코딩 전에 먼저 읽는 구조/구현 규칙
- `codex-template-multi-agent-process/`
  - `scripts/export-template.sh`가 만드는 복사용 템플릿 번들
  - 기존 레포 이식 작업 중 비교용으로 둘 수 있고, 끝나면 다시 생성 가능하므로 삭제해도 된다
- `UPGRADE_PROMPT.md`
  - 이 템플릿을 다른 기존 레포에 업그레이드 이식할 때 AI에게 주는 재사용 프롬프트
  - 운영 문서가 아니라 마이그레이션 실행 문서

## 가장 자주 쓰는 흐름

### 1. 새 요청 시작

```bash
scripts/context-log.sh resume-lite
scripts/start-feature.sh <feature-id>
scripts/workflow-mode.sh show --feature <feature-id>
scripts/sync-handoffs.sh <feature-id>
```

- `resume-lite`: 직전 handoff와 resume snapshot을 만든다.
- `start-feature.sh`: feature packet을 만들거나 활성 feature로 전환한다.
- `workflow-mode.sh show`: 현재 feature가 `lite`인지 `full`인지와 role chain 기준을 확인한다.
- `sync-handoffs.sh`: `plan.md`와 `brief.md`를 기준으로 handoff 4종과 `test-matrix.md` source digest를 다시 생성한다.
- `implementer-subtasks.sh list|validate`: `plan.md`가 `parallel` implementer mode일 때 task card 단위 worker package를 확인한다.

### 2. 지금 에이전트가 뭘 하는지 보기

```bash
scripts/dispatch-heartbeat.sh show
```

- 보통은 `run-log.md`를 직접 열지 말고 이 명령으로 본다.
- `.context/active_feature`가 잡혀 있으면 feature id를 따로 안 넣어도 된다.
- 다른 feature를 보고 싶으면:

```bash
scripts/dispatch-heartbeat.sh show --feature <feature-id>
```

### 3. 오케스트레이터가 상태 갱신할 때

```bash
scripts/dispatch-heartbeat.sh queue <role> "<next action>"
scripts/dispatch-heartbeat.sh start <role> "<first concrete action>"
scripts/dispatch-heartbeat.sh progress <role> "<file/command/blocker>"
scripts/dispatch-heartbeat.sh risk <role> "<why at risk>"
scripts/dispatch-heartbeat.sh blocked <role> "<why blocked>"
scripts/dispatch-heartbeat.sh done <role> "<what finished>"
```

wrapper를 쓰면 반복 입력을 줄일 수 있다:

```bash
scripts/dispatch-role.sh <role> "<next action>"
scripts/record-role-result.sh <role> --agent-id <id> --scope "<scope>" --rq-covered "<rq>" --rq-missing "<rq>" --result PASS --evidence "<evidence>" --next-action "<next>"
scripts/finish-role.sh <role> "<done message>" --next-role <role> --next-action "<next action>"
```

- `queue`: 다음 역할로 넘기기 직전
- `start`: 역할이 실제로 시작했을 때
- `progress`: 파일/명령 기준으로 의미 있는 진행이 생겼을 때
- `risk`: 45초 안에 의미 있는 진행이 안 보여서 주의가 필요할 때
- `blocked`: 120초 내 actionable output이 없거나 진행이 막혔을 때
- `done`: 해당 역할 작업이 끝났을 때
- wrapper는 `run-log.md` role output 기록, `docs/features/<feature-id>/artifacts/roles/*.json` role receipt 기록, queue/done 전환을 덜 수동적으로 만들기 위한 얇은 entrypoint다.

### 4. 중간/최종 검증

```bash
bash scripts/gates/check-tests.sh --feature
bash scripts/gates/check-tests.sh --infra
bash scripts/gates/check-tests.sh --full
scripts/gates/run.sh
scripts/gates/run.sh <feature-id>
scripts/gates/run.sh --reuse-if-valid <feature-id>
```

- `check-tests.sh --feature`: tester용 feature-facing test 실행
- `check-tests.sh --infra`: template/gate/dispatch 같은 infra smoke 실행
- `check-tests.sh --full`: 전체 로컬 회귀 실행
- `gates/run.sh`: packet, handoffs, role-chain, test-matrix, scope, file-size, tests, secrets 확인
  - 추가로 `project-context`, `brief`, `plan`까지 확인해 오래된 문서/누락된 요구사항/재사용 계획 누락을 잡는다.
- `run.sh --reuse-if-valid`: 최근 PASS gate receipt가 현재 fingerprint와 같으면 전체 gate를 재사용한다.

### 5. 작업 완료 기록

```bash
scripts/complete-feature.sh <feature-id> "<summary>" "<next-step>"
```

- `complete-feature.sh`는 내부에서 `scripts/gates/run.sh --reuse-if-valid <feature-id>`를 호출해 불필요한 중복 gate를 줄인다.

## 언제 어떤 명령을 쓰나

### 새 feature를 시작할 때

```bash
scripts/start-feature.sh <feature-id>
```

### 진행 중인 feature를 바꿀 때

```bash
scripts/set-active-feature.sh <feature-id>
```

### gate만 다시 확인하고 싶을 때

```bash
scripts/gates/run.sh
```

### test-matrix / run-log 규칙이 잘 지켜지는지 보고 싶을 때

```bash
bash scripts/gates/check-tests.sh --full
```

### 기존 레포에 옮길 번들을 다시 만들 때

```bash
scripts/export-template.sh
```

- 기본 출력 경로는 `codex-template-multi-agent-process/`다.
- 번들 안의 `TEMPLATE_USAGE.md`, `MIGRATE_EXISTING_PROJECT.md`, `UPGRADE_PROMPT.md`를 같이 보면 된다.
- 비교나 이식이 끝난 임시 번들이면 삭제하고, 필요할 때 다시 생성하면 된다.

## 기다릴지 끊을지 판단 기준

`scripts/dispatch-heartbeat.sh show` 결과를 기준으로 본다.

- 기다려도 되는 경우:
  - `last-progress-at-utc`가 최근 45초 이내
  - `last-progress`에 실제 파일 경로 또는 명령이 적혀 있음
- 끊는 게 좋은 경우:
  - `current-status`가 `AT_RISK` 또는 `BLOCKED`
  - 최근 진행 업데이트가 45초 넘게 없음
  - `last-progress`가 "thinking", "checking"처럼 추상적임

## 상세 문서

- Feature packet 구조: `docs/features/README.md`
- Gate 정책: `docs/context/GATES.md`
- 프로젝트 기본 문서: `docs/context/PROJECT.md`
- 멀티 에이전트 상세 프로세스: `docs/context/MULTI_AGENT_PROCESS.md`
- 코딩 컨벤션: `docs/context/CONVENTIONS.md`
- 에이전트 역할 계약: `docs/agents/README.md`
- 기존 레포 업그레이드용 프롬프트: `UPGRADE_PROMPT.md`
