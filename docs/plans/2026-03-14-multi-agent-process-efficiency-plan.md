# Multi-Agent Process Efficiency Plan

## 문서 기준
- 이 문서는 현재 저장소의 실제 source of truth만 기준으로 작성한다.
- 기준 파일:
  - `docs/context/MULTI_AGENT_PROCESS.md`
  - `AGENTS.md`
  - `docs/agents/*.md`
  - `docs/context/GATES.md`
  - `scripts/gates/*.sh`
  - `scripts/start-feature.sh`
  - `scripts/complete-feature.sh`
- 목적은 안전장치를 약화하지 않고, 동일 사실의 반복 기록/반복 검증/불필요한 재읽기를 줄이는 것이다.

## 유지해야 하는 안정성 기준
아래 항목은 줄이면 안 된다.

1. feature packet 중심 흐름
   - `brief.md`, `plan.md`, `*-handoff.md`, `test-matrix.md`, `run-log.md`를 축으로 한 packet 구조는 유지한다.
2. 역할 체인 강제
   - `planner -> implementer -> tester -> gate-checker -> reviewer -> security`
   - `reviewer FAIL => security BLOCKED`
   - `reviewer PASS 없이 security PASS 금지`
3. `plan.md` 소유권 분리
   - planner만 `plan.md`를 작성한다.
4. gate 권위 유지
   - 최종 완료 조건은 계속 `scripts/gates/run.sh` 기준이어야 한다.
5. 고유 `agent-id` 유지
   - role passing 방지 장치는 그대로 둔다.

## 현재 비효율 진단

### 1. planner가 같은 사실을 여러 파일에 반복 작성한다
현재 planner는 사실상 같은 내용을 아래 파일에 다시 적어야 한다.

- `plan.md`
- `implementer-handoff.md`
- `tester-handoff.md`
- `reviewer-handoff.md`
- `security-handoff.md`
- `test-matrix.md`

문제:
- 설계 정보의 정본이 `plan.md`인데, downstream 입력을 위해 같은 제약/범위/RQ를 handoff 4종에 재서술한다.
- 파일 수가 늘수록 갱신 누락과 드리프트 가능성이 커진다.
- planner 시간이 길어지고 downstream도 handoff 최신성 검증 때문에 원문을 다시 읽게 된다.

### 2. 동일한 tree 상태에서 검증이 반복 실행된다
현재 테스트/게이트는 최소 두 번, 상황에 따라 세 번 반복된다.

- tester: `scripts/gates/check-tests.sh`
- gate-checker: `scripts/gates/run.sh`
- complete 단계: `scripts/complete-feature.sh` 내부에서 다시 `scripts/gates/run.sh`

문제:
- 테스트와 gate가 같은 코드 상태에서 재실행될 수 있다.
- 안전성은 거의 늘지 않는데 완료 시간이 길어진다.
- 긴 테스트가 붙는 실제 프로젝트로 갈수록 비용이 급격히 커진다.

### 3. `run-log.md`가 실시간 모니터와 최종 증빙을 동시에 맡는다
현재 `run-log.md`는 아래 역할을 한 파일에서 동시에 수행한다.

- Dispatch Monitor
- 7개 역할 결과 기록
- `role-chain` gate 증빙

문제:
- 실시간 진행 로그와 기계 검증용 결과 포맷은 목적이 다르다.
- 같은 상태를 heartbeat와 role output에 중복 입력해야 한다.
- gate가 자유서술형 markdown 파싱에 강하게 의존한다.

### 4. downstream이 handoff만 읽도록 설계했지만, handoff 신선도 증명이 약하다
문서 계약상 implementer/tester/reviewer/security는 handoff 우선이다.
하지만 실제로는 아래 이유로 원문 재오픈 유인이 남아 있다.

- handoff가 최신 `plan.md`를 반영하는지 기계적으로 알기 어렵다
- 어떤 shared doc를 기준으로 handoff가 생성됐는지 추적값이 없다
- ambiguous할 때 원문 reopen을 허용하는데, 애매하면 방어적으로 다시 읽게 된다

문제:
- "최소 읽기" 규칙은 있지만 "안심하고 덜 읽을 근거"가 부족하다.
- 결국 불필요한 `plan.md`, `ARCHITECTURE.md`, `GATES.md` 재확인이 반복된다.

### 5. 사람용 조작 단계가 많아 운영 오버헤드가 크다
현재 오케스트레이터는 역할 전환마다 아래 작업을 수동으로 이어붙여야 한다.

- heartbeat `queue/start/progress/done`
- 역할 결과 markdown 기록
- 필요시 gate 재실행
- 완료 시 `complete-feature.sh`

문제:
- 상태는 명확하지만 조작 단계가 많다.
- 실수는 gate가 잡더라도, 운영자는 같은 형식 작업을 반복한다.
- 속도 저하는 주로 "생각"보다 "기록/호출"에서 발생한다.

## 권장 개선안

### 1. `plan.md`를 정본으로 두고 handoff는 생성물로 바꾼다
가장 먼저 줄여야 할 중복이다.

권장 방식:
- planner의 실질 입력/출력 정본은 계속 `plan.md`로 둔다.
- planner는 handoff별 차이만 적는 얇은 override 블록만 유지한다.
- `scripts/sync-handoffs.sh <feature-id>`를 추가해 아래 파일을 자동 생성 또는 동기화한다.
  - `implementer-handoff.md`
  - `tester-handoff.md`
  - `reviewer-handoff.md`
  - `security-handoff.md`
  - `test-matrix.md` 초기 row

생성 규칙 예시:
- `plan.md`의 `Scope`, `RQ -> Task Mapping`, `Architecture Notes`, `Reuse and Config Plan`
- `brief.md`의 RQ 목록
- role별 override 필드

안정성 이유:
- downstream은 지금처럼 handoff 파일을 읽는다.
- gate도 지금처럼 handoff 파일 존재를 검사할 수 있다.
- 바뀌는 것은 "planner가 5개 파일을 직접 편집하느냐"이지, packet 계약 자체가 아니다.

기대 효과:
- planner 작성량 감소
- handoff 드리프트 감소
- downstream이 handoff를 더 신뢰하게 되어 원문 재오픈 감소

### 2. handoff에 `source digest`를 넣어 재읽기 필요성을 줄인다
handoff 상단에 handoff가 어떤 원문 버전을 반영하는지 기록한다.

권장 필드:
- `brief-sha`
- `plan-sha`
- `project-context-sha`
- `architecture-sha`
- `gates-sha`
- `generated-at-utc`

운영 규칙:
- downstream은 handoff digest가 현재 원문과 일치하면 handoff만 읽는다.
- digest 불일치 또는 필수 필드 누락일 때만 `plan.md`나 shared doc를 다시 연다.

안정성 이유:
- 원문 재오픈 권한은 그대로 남긴다.
- 다만 "다시 읽어야 하는 조건"을 명확히 해서 불필요한 방어적 재읽기를 줄인다.

기대 효과:
- implementer/tester/reviewer/security의 문서 읽기량 감소
- handoff 최신성 논쟁 감소

### 3. 테스트/게이트를 fingerprint 기반으로 재사용한다
현재 구조에서 가장 큰 실행 시간 낭비 구간이다.

권장 방식:
- tester가 `check-tests.sh` 성공 시 receipt를 남긴다.
- gate-checker가 full gate를 돌릴 때, `tests` 항목은 같은 fingerprint면 tester receipt를 재사용한다.
- `complete-feature.sh`도 최근 full gate PASS receipt가 현재 fingerprint와 같으면 재실행 없이 완료 처리한다.

fingerprint 구성 권장:
- 현재 changed file set
- 관련 packet 파일 hash
- 테스트 명령 문자열
- baseline snapshot
- feature id

재사용 허용 범위:
- `tests` gate
- 필요하면 이후 `project-context`, `brief`, `plan`, `handoffs`도 동일 fingerprint일 때 재사용 가능

재사용 금지 또는 보수적 유지:
- `role-chain`
- `scope`
- `file-size`
- `secrets`

안정성 이유:
- authoritative final gate는 유지한다.
- 단지 "같은 입력에 대한 같은 검증"만 스킵한다.
- fingerprint가 다르면 지금처럼 전체를 다시 실행하면 된다.

기대 효과:
- tester 이후 대기 시간 단축
- `complete-feature.sh` 단계 체감 속도 개선
- 실제 프로젝트 확장 시 비용 폭증 방지

### 4. `run-log.md`와 기계 검증용 receipt를 분리한다
사람이 읽는 로그와 gate 증빙을 분리해야 운영비가 내려간다.

권장 구조:
- `run-log.md`: Dispatch Monitor + 짧은 human-readable 진행 요약
- `docs/features/<feature-id>/artifacts/roles/<role>.json`: 기계 검증용 role receipt
- `docs/features/<feature-id>/artifacts/gates/latest.json`: full gate 결과

role receipt 필드 예시:
- `role`
- `agent_id`
- `scope`
- `rq_covered`
- `rq_missing`
- `result`
- `evidence`
- `updated_at_utc`
- `input_digest`

안정성 이유:
- `run-log.md`는 그대로 남는다.
- `role-chain`은 markdown 파싱에서 structured receipt 검증으로 점진 이관할 수 있다.
- 초기에는 dual-write로 운영해도 된다.

기대 효과:
- role output 중복 기록 감소
- gate 파싱 안정성 증가
- 향후 자동화 스크립트 작성이 쉬워짐

### 5. 오케스트레이션 조작을 wrapper command로 묶는다
현재는 상태 전환이 명확하지만 명령 수가 많다.

권장 스크립트:
- `scripts/dispatch-role.sh <feature-id> <role> "<next action>"`
- `scripts/record-role-result.sh <feature-id> <role> <receipt-file>`
- `scripts/finish-role.sh <feature-id> <role> "<summary>"`

기능:
- heartbeat 갱신
- role receipt 반영
- `run-log.md` 요약 갱신
- 필요시 다음 역할 queue까지 처리

안정성 이유:
- 상태 모델은 그대로 둔다.
- 사람이 순서를 실수하지 않도록 shell entrypoint만 좁힌다.

기대 효과:
- 오케스트레이터 수동 작업 감소
- 운영 절차 편차 감소

### 6. tester와 gate-checker의 책임 경계를 더 선명하게 만든다
지금은 tester도 gate 일부를 실행하고, gate-checker도 전체 gate를 실행한다.
이 구조 자체는 맞지만 책임 경계를 명확히 해야 중복이 줄어든다.

권장 재정의:
- tester:
  - 테스트 환경 preflight
  - 테스트 추가/수정
  - `check-tests.sh` 실행
  - `test-matrix.md` finalize
  - 테스트 receipt 작성
- gate-checker:
  - authoritative full gate 실행자
  - receipt 재사용 가능 여부만 판단
  - 최종 gate summary 작성

안정성 이유:
- 역할 체인은 그대로 유지된다.
- tester가 "테스트 실행자", gate-checker가 "최종 정책 판정자"라는 구분이 선명해진다.

기대 효과:
- 중복 설명과 중복 명령 감소
- 역할 간 책임 충돌 감소

## 단계별 적용 순서

### Phase 1
가장 안전하고 효과가 큰 항목부터 적용한다.

1. handoff `source digest` 추가
2. `scripts/sync-handoffs.sh` 추가
3. wrapper command 추가

이 단계는 packet 계약과 gate 구조를 거의 건드리지 않는다.

### Phase 2
실행 시간 절감 중심 개선을 넣는다.

1. tester receipt
2. gate receipt
3. fingerprint 비교
4. `complete-feature.sh` 재실행 회피

이 단계부터 체감 속도가 크게 좋아진다.

### Phase 3
증빙 구조를 정리한다.

1. role receipt JSON 도입
2. `role-chain`의 structured validation 추가
3. `run-log.md`를 live monitor 중심으로 축소

이 단계는 효과가 크지만 gate 개편 범위가 넓어서 마지막이 적절하다.

## 바로 실행할 우선순위
바로 시작한다면 아래 세 가지가 가장 효율 대비 리스크가 좋다.

1. `scripts/sync-handoffs.sh`
   - planner 중복 작성량을 즉시 줄인다.
2. handoff `source digest`
   - 불필요한 원문 재읽기를 바로 줄인다.
3. `complete-feature.sh`의 최근 PASS gate 재사용
   - 완료 직전 반복 gate 실행을 줄인다.

## 한 줄 결론
이 템플릿의 문제는 안전장치가 많다는 점이 아니라, 같은 사실을 packet 문서와 gate에서 여러 번 다시 기록하고 다시 검증한다는 점이다.
따라서 역할 체인과 gate 권위를 유지한 채, `plan.md` 정본화, handoff 생성 자동화, fingerprint 기반 검증 재사용, structured receipt 도입 순서로 개선하는 것이 가장 안전하고 효과적이다.
