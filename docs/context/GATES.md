# Gate Policy v2

## 목적
- 사람이 아닌 명령 결과로 pass/fail를 판정한다.
- gate-checker와 CI가 동일 명령을 사용하도록 고정한다.

## Reader Intent
- `planner`: 전체 gate 정책을 읽고 역할별 handoff에 필요한 검증 기대치를 내려준다.
- `orchestrator`: 상태전이, 완료 조건, merge-block 의미만 읽는다.
- `tester` / `gate-checker`: 실제 검증 커맨드와 pass/fail 기준을 읽는다.

## 기본 원칙
1. Gate 결과는 `PASS` 또는 `FAIL`만 허용한다.
2. FAIL 항목이 하나라도 있으면 구현 완료로 간주하지 않는다.
3. gate-checker는 결과를 해석하지 않고 원시 결과를 전달한다.
4. `brief.md`의 workflow mode와 `plan.md`의 implementer mode는 gate가 읽는 실행 계약이다.
5. `full` mode의 reviewer는 기능 승인뿐 아니라 코드 품질 승인도 담당한다.

## 실행 커맨드
레포 루트에서 실행:

```bash
scripts/gates/run.sh <feature-id>
scripts/gates/run.sh --reuse-if-valid <feature-id>
```

`<feature-id>`는 `docs/features/<feature-id>/` 패킷과 연결된다.
인자를 생략하면 `.context/active_feature` 값을 사용한다.

재사용 정책:
- `check-tests.sh --feature`는 feature-test receipt를 기록할 수 있다.
- `run.sh`는 현재 feature-test receipt를 재사용해 feature 테스트 중복을 줄일 수 있다.
- `run.sh --reuse-if-valid`는 current fingerprint와 일치하는 full-gate PASS receipt가 있을 때 gate 전체를 재사용한다.

## Gate 항목
1. `project-context`: `PROJECT.md`, `CONVENTIONS.md`, `ARCHITECTURE.md`, `RULES.md`가 존재하고 placeholder/이전 프로젝트 잔재 없이 채워졌는지
2. `packet`: feature packet 필수 파일 존재 여부
3. `brief`: `brief.md`의 feature-id, Goal, Constraints, Acceptance, Workflow Mode, Requirement Notes, RQ 설명이 비어 있지 않은지
4. `plan`: `plan.md`의 target files, `RQ -> Task Mapping`, `Architecture Notes`, `Reuse and Config Plan`, `Execution Strategy`, task cards가 비어 있지 않은지 + parallel implementer mode면 task cards가 file-disjoint worker package인지
5. `handoffs`: `implementer/tester/reviewer/security-handoff.md`가 존재하고 각 역할에 필요한 handoff 필드가 비어 있지 않은지 + `brief/plan/project/architecture/gates` source digest가 최신인지
6. `role-chain`: workflow mode에 맞는 역할 체인(`lite` 또는 `full`)의 필수 필드(`agent-id/scope/result/evidence`)가 채워졌는지 + `Dispatch Monitor` 필드가 채워졌는지 + `agent-id` 중복 여부 + 상태전이 규칙 준수 여부 + `plan.md` 소유권 규칙 준수 여부 + role receipt의 `touched_files` 존재 여부 및 역할별 수정 범위 정책 준수 여부
7. `test-matrix`: `test-matrix.md`가 `VERIFIED` 상태인지 + 모든 RQ row가 테스트 파일/normal/error/boundary/status를 채웠는지
8. `scope`: 변경 파일이 `plan.md` target files 범위를 벗어나는지
9. `file-size`: 신규 파일/수정 파일의 라인 수 정책 위반 여부
10. `tests`: `bash scripts/gates/check-tests.sh --full`
11. `secrets`: 하드코딩된 비밀 패턴 탐지

## Legacy 예외 정책
- 기존 대형 파일은 `scripts/gates/size-exceptions.txt`에 상한선을 명시한다.
- 예외 파일이라도 상한 초과 시 FAIL.
- 신규 파일은 예외 없이 기본 상한 적용.
- feature packet 생성 시점의 기존 dirty 파일은 `.baseline-changes.txt`로 스냅샷되어 scope/file-size 판정에서 제외된다.

## CI 원칙
- PR에서는 `scripts/gates/run.sh <feature-id>`를 필수 체크로 둔다.
- 로컬과 CI 명령이 다르면 안 된다.
- 브랜치 보호 규칙에서 `Gates` 워크플로우를 required check로 설정한다.

## 실패 대응
1. 실패 항목과 원시 출력 확인
2. implementer가 수정
3. 동일 커맨드 재실행
4. 모두 PASS일 때만 reviewer/security 단계로 진행
5. reviewer의 품질 FAIL도 동일하게 구현 수정 후 재검증 대상으로 본다.

## 상태전이 규칙 (role-chain에서 강제)
0. `lite` mode는 `gate-checker`에서 종료할 수 있다.
1. `full` mode는 `reviewer`, `security`를 반드시 포함한다.
2. `reviewer = FAIL`이면 `security = BLOCKED`여야 한다.
3. `security = PASS`는 `reviewer = PASS`일 때만 허용된다.
4. `implementer = PASS`는 `planner = PASS`일 때만 허용된다.

## plan 소유권 규칙 (role-chain에서 강제)
1. `planner.scope`는 반드시 `plan.md`를 포함해야 한다.
2. `orchestrator.scope`는 `plan.md`를 포함하면 안 된다.
3. `Execution Strategy.merge owner`는 `implementer`여야 한다.

## 멀티 에이전트 무결성 규칙 (role-chain에서 강제)
1. 7개 역할은 각각 고유한 `agent-id`를 가져야 한다.
2. 동일 `agent-id`가 두 역할 이상에 재사용되면 FAIL이다.
3. `agent-id`가 역할명 자체(`planner`, `implementer` 등)면 FAIL이다.

## 완료 선언 규칙
- 완료 보고는 `scripts/complete-feature.sh`로만 수행한다.
- 수동 완료 선언(게이트/role-chain 검증 없이)은 허용하지 않는다.
