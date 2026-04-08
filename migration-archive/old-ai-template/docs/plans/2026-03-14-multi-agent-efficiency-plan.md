# Multi-Agent Efficiency Plan

## 목적
- `MULTI_AGENT_PROCESS.md` 기준으로 현재 멀티 에이전트 운영 흐름의 속도 저하 요인을 정리한다.
- 안정성을 해치지 않는 선에서 중복 작성, 불필요한 문서 재열람, 반복 gate 실행을 줄이는 방법을 제안한다.
- "단계를 없애는 것"이 아니라 "같은 안전성을 더 적은 비용으로 유지하는 것"을 목표로 한다.

## 유지할 안정성 기준
- 최종 authoritative 검증은 계속 `scripts/gates/run.sh <feature-id>`와 CI `Gates`가 맡는다.
- `planner -> implementer -> tester -> gate-checker -> reviewer -> security` 순서는 유지한다.
- `planner`의 `plan.md` 소유권은 유지한다.
- `reviewer`/`security`의 최종 승인 단계는 유지한다.
- 역할별 고유 `agent-id`와 `role-chain` 규칙은 유지한다.

## 현재 병목 요약

### 1. 운영 규칙이 여러 문서에 중복 서술된다
관찰 근거:
- `AGENTS.md`
- `README.md`
- `docs/context/MULTI_AGENT_PROCESS.md`
- `docs/agents/README.md`

문제:
- 역할 순서, bootstrap, handoff 원칙, gate 명령이 여러 파일에 반복된다.
- 사람과 에이전트가 같은 규칙을 여러 문서에서 다시 읽게 된다.
- 실제 규칙 변경 시 문서 정렬 비용이 커지고, 읽기 비용도 커진다.

개선:
- `docs/context/MULTI_AGENT_PROCESS.md`를 운영 플로우의 단일 정본으로 고정한다.
- `README.md`는 quick command index만 남긴다.
- `AGENTS.md`는 라우팅 규칙과 "어느 역할이 어떤 문서를 읽는가"만 남긴다.
- `docs/agents/README.md`는 역할 파일 목록과 공통 출력 포맷만 유지한다.

예상 효과:
- 신규 세션의 읽기량 감소
- 규칙 충돌과 문서 유지보수 비용 감소

### 2. planner가 같은 사실을 너무 많은 파일에 다시 쓴다
관찰 근거:
- feature packet 필수 파일이 `brief.md`, `plan.md`, 4개 `*-handoff.md`, `test-matrix.md`, `run-log.md`까지 확장돼 있다.
- `planner`는 `plan.md`와 4개 handoff, `test-matrix.md` 초기 row까지 모두 작성/갱신한다.

문제:
- scope, RQ, architecture note, 테스트 기대치가 `plan.md`와 handoff들에 반복된다.
- 문서 수가 많을수록 planner 단계가 느려지고, downstream이 충돌을 발견하면 다시 전체 handoff를 refresh해야 한다.
- gate는 주로 존재/형식/필수 필드를 검증하므로, 문서 수 증가 대비 안정성 증가는 제한적이다.

개선:
- `plan.md`를 계속 정본으로 유지하되, handoff는 수동 재작성 대신 파생 산출물로 다룬다.
- 권장 방식은 두 단계다.
  - 1단계: `plan.md` 안에 role summary 섹션을 명시하고 handoff는 그 요약을 복사하는 최소 문서로 축소한다.
  - 2단계: `scripts/generate-handoffs.sh <feature-id>` 같은 스크립트로 handoff를 자동 생성한다.
- `tester-handoff.md`, `reviewer-handoff.md`, `security-handoff.md`는 역할별 차이만 남기고 공통 scope/RQ 재기술은 줄인다.

예상 효과:
- planner 작성 시간 감소
- handoff 간 drift 감소
- downstream의 재독해 비용 감소

### 3. bootstrap과 orchestrator가 여전히 전역 문서를 반복 로드한다
관찰 근거:
- 세션 시작 시 `resume-lite`, `HANDOFF.md`, `CODEX_RESUME.md`를 우선 읽는다.
- orchestrator는 다시 `PROJECT.md`, `GATES.md`, `HANDOFF.md`, `CODEX_RESUME.md`를 읽는다.
- 동시에 전역 계약은 `planner`만 deep read를 담당하도록 설계돼 있다.

문제:
- 현재 요청 처리에 직접 필요하지 않은 전역 문서를 세션마다 반복 로드하게 된다.
- feature packet이 이미 현재 요청 범위를 좁혀주는데도, bootstrap 문서가 별도 비용을 계속 만든다.

개선:
- orchestrator 기본 입력을 더 얇게 만든다.
  - 기본: `brief.md`, `run-log.md`, `HANDOFF.md`, `CODEX_RESUME.md`
  - 보조: 완료 판단이 필요할 때만 `GATES.md` 상태 규칙 요약
- `PROJECT.md`와 `ARCHITECTURE.md`의 deep read는 planner 중심을 유지한다.
- `resume-lite` 출력도 "최근 feature / 최근 blocker / 다음 액션" 중심의 짧은 operator summary로 압축한다.

예상 효과:
- 세션 재개 속도 개선
- 같은 프로젝트 원칙의 반복 독해 감소

### 4. 동일한 테스트와 gate가 한 feature에서 여러 번 반복 실행된다
관찰 근거:
- `tester`는 `scripts/gates/check-tests.sh` 실행이 필수다.
- `scripts/gates/run.sh` 안에도 `tests` gate로 `check-tests.sh`가 포함된다.
- `scripts/complete-feature.sh`는 완료 시 `scripts/gates/run.sh`를 다시 실행한다.

문제:
- 같은 코드 상태에서 테스트와 gate가 2~3회 반복 실행될 수 있다.
- 로컬 루프에서 가장 큰 체감 속도 저하 요인이다.
- 안정성은 최종 gate와 CI에서 이미 확보되므로, 모든 단계에서 동일 강도의 재실행은 과하다.

개선:
- 검증 강도를 역할별로 분리한다.
  - tester: 빠른 실행 확인 + feature 관련 테스트 우선
  - gate-checker: authoritative full gate
  - complete-feature: "마지막 full gate PASS 이후 코드/packet이 바뀌지 않았을 때" 재실행 생략
- `gates` 결과를 fingerprint로 캐시한다.
  - 입력 후보: changed file set, `plan.md`, handoff 파일, `test-matrix.md`, 실행 커맨드
  - fingerprint가 같으면 local completion에서는 full rerun을 생략할 수 있다.

예상 효과:
- 로컬 반복 검증 시간 감소
- CI 수준의 안전성은 그대로 유지

### 5. tester 단계가 feature와 무관한 인프라 회귀 테스트까지 항상 수행한다
관찰 근거:
- `check-tests.sh`는 unit test 외에 `context-log`, `gates`, `dispatch-heartbeat` 테스트도 매번 실행한다.

문제:
- 대부분의 feature는 앱/스크립트 일부만 건드리는데도 템플릿 운영 인프라 회귀 테스트를 전부 돈다.
- tester 단계가 "feature 검증"보다 "템플릿 전체 회귀"에 묶여 있다.

개선:
- 테스트 계층을 분리한다.
  - `scripts/gates/check-tests.sh --feature`
  - `scripts/gates/check-tests.sh --infra`
  - `scripts/gates/check-tests.sh --full`
- tester는 changed files 기준으로 필요한 집합만 실행한다.
- `gate-checker`와 CI는 계속 `--full`을 사용한다.
- 인프라 관련 파일이 안 바뀌었을 때는 `context-log/gates/dispatch-heartbeat` 테스트를 tester 단계에서 생략한다.

예상 효과:
- 일반 feature의 tester 단계 속도 개선
- 인프라 수정 시에는 기존 수준의 보호 유지

### 6. `run-log.md`가 live monitor와 최종 증빙을 동시에 맡아 기록 비용이 커진다
관찰 근거:
- `dispatch-heartbeat.sh`는 `Dispatch Monitor`만 수정한다.
- 각 역할은 별도로 자기 결과 섹션을 남겨야 한다.

문제:
- 상태 가시화와 역할 결과 증빙이 같은 파일 안에서 이중으로 관리된다.
- live 업데이트와 최종 verdict 기록의 요구사항이 다른데 한 파일에 함께 들어가 churn이 크다.

개선:
- `run-log.md`는 사람용 live monitor와 요약 로그에 집중시킨다.
- 기계가 검증할 역할 결과는 `docs/features/<feature-id>/artifacts/<role>.json` 같은 구조화 파일로 분리한다.
- `role-chain` gate는 장기적으로 `run-log.md + artifacts/*`를 함께 보도록 확장한다.

예상 효과:
- 상태 기록 중복 감소
- gate 파싱 안정성 증가
- reviewer/security 승인 범위를 최종 상태와 연결하기 쉬워짐

### 7. `scripts/gates/run.sh`는 로컬에서도 항상 전체 체크를 끝까지 돈다
관찰 근거:
- `run.sh`는 실패가 나와도 나머지 gate를 계속 실행해 마지막에 summary를 낸다.

문제:
- 진단 정보는 풍부하지만, 로컬 수정 루프에서는 이미 앞 단계 구조 오류가 났는데 뒤의 비싼 체크까지 다 도는 경우가 생긴다.
- 특히 packet/brief/plan/handoffs 실패가 난 상태에서는 `tests`까지 가는 가치가 낮다.

개선:
- 두 모드를 둔다.
  - 기본 로컬: `scripts/gates/run.sh --fast`
  - CI / 최종 판정: `scripts/gates/run.sh --full`
- `--fast`는 구조적 FAIL 시 조기 종료하고, `tests`는 선택적이거나 마지막으로 미룬다.
- `--full`은 현재 동작을 유지한다.

예상 효과:
- 수정 루프 단축
- 최종 안전성은 기존과 동일

## 우선순위 제안

### 1단계: 즉시 적용 가능, 리스크 낮음
- 운영 규칙 문서 단일화
- tester 단계와 final gate 단계의 테스트 책임 분리
- `run.sh --fast` / `--full` 분리

### 2단계: 효과 큼, 구조 변경 필요
- handoff 자동 생성
- gate fingerprint 캐시
- completion 시 마지막 authoritative gate 재사용

### 3단계: 장기 안정화
- `run-log.md`와 구조화 artifact 분리
- reviewer/security 승인 대상을 final state hash 기준으로 고정

## 권장 KPI
- feature 1건당 planner 작성 문서 수
- 세션 bootstrap 시 기본 읽기 파일 수
- feature 1건당 `check-tests.sh` 실행 횟수
- feature 1건당 `scripts/gates/run.sh` 실행 횟수
- gate wall-clock time
- reviewer/security 재승인 발생 횟수

## 결론
- 현재 구조의 방향 자체는 맞다.
- 느린 이유는 "보호 장치가 많아서"보다 "같은 사실을 여러 문서와 여러 단계에서 다시 확인해서"에 가깝다.
- 따라서 최적화는 reviewer/security 제거가 아니라, 정본 축소, 파생 문서 자동화, 검증 재사용 조건 명시, 로컬 fast path 추가 순서로 가는 것이 맞다.
