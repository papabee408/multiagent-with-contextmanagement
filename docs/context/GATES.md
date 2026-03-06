# Gate Policy v1

## 목적
- 사람이 아닌 명령 결과로 pass/fail를 판정한다.
- gate-checker와 CI가 동일 명령을 사용하도록 고정한다.

## 기본 원칙
1. Gate 결과는 `PASS` 또는 `FAIL`만 허용한다.
2. FAIL 항목이 하나라도 있으면 구현 완료로 간주하지 않는다.
3. gate-checker는 결과를 해석하지 않고 원시 결과를 전달한다.

## 실행 커맨드
레포 루트에서 실행:

```bash
scripts/gates/run.sh <feature-id>
```

`<feature-id>`는 `docs/features/<feature-id>/` 패킷과 연결된다.
인자를 생략하면 `.context/active_feature` 값을 사용한다.

## Gate 항목
1. `packet`: feature packet 필수 파일 존재 여부
2. `role-chain`: run-log에 7개 역할(`orchestrator..security`)의 필수 필드(`agent-id/scope/result/evidence`)가 모두 채워졌는지 + `agent-id` 중복 여부 + 상태전이 규칙 준수 여부 + `plan.md` 소유권 규칙 준수 여부
3. `scope`: 변경 파일이 `plan.md` target files 범위를 벗어나는지
4. `file-size`: 신규 파일/수정 파일의 라인 수 정책 위반 여부
5. `unit-tests`: `node --test tests/unit/*.test.mjs`
6. `context-log-tests`: `bash tests/context-log.test.sh`
7. `secrets`: 하드코딩된 비밀 패턴 탐지

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

## 상태전이 규칙 (role-chain에서 강제)
1. `reviewer = FAIL`이면 `security = BLOCKED`여야 한다.
2. `security = PASS`는 `reviewer = PASS`일 때만 허용된다.
3. `implementer = PASS`는 `planner = PASS`일 때만 허용된다.

## plan 소유권 규칙 (role-chain에서 강제)
1. `planner.scope`는 반드시 `plan.md`를 포함해야 한다.
2. `orchestrator.scope`는 `plan.md`를 포함하면 안 된다.

## 멀티 에이전트 무결성 규칙 (role-chain에서 강제)
1. 7개 역할은 각각 고유한 `agent-id`를 가져야 한다.
2. 동일 `agent-id`가 두 역할 이상에 재사용되면 FAIL이다.
3. `agent-id`가 역할명 자체(`planner`, `implementer` 등)면 FAIL이다.

## 완료 선언 규칙
- 완료 보고는 `scripts/complete-feature.sh`로만 수행한다.
- 수동 완료 선언(게이트/role-chain 검증 없이)은 허용하지 않는다.
