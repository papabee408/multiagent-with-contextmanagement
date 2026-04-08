# Stage 01

## 완료 항목
- Item 1: `plan.md` 정본화 + handoff 자동 생성

## 핵심 변경
- `scripts/sync-handoffs.sh`를 기준 진입점으로 두고 `brief.md` + `plan.md`에서 아래 파일을 재생성하도록 정리했다.
  - `implementer-handoff.md`
  - `tester-handoff.md`
  - `reviewer-handoff.md`
  - `security-handoff.md`
  - `test-matrix.md` RQ row
- planner 계약과 운영 문서에서 handoff refresh를 직접 편집이 아니라 `scripts/sync-handoffs.sh <feature-id>` 호출로 명시했다.
- feature packet 문서에서 `brief.md` 또는 `plan.md` 수정 후 sync를 다시 돌리는 흐름을 운영 명령으로 고정했다.

## 안정성 영향
- handoff 파일 자체는 유지된다.
- downstream role 입력 형식은 유지된다.
- 바뀐 것은 planner가 같은 의미를 여러 파일에 손으로 반복 입력하지 않도록 만든 점이다.

## 검증
- `bash tests/sync-handoffs.test.sh`
- `bash tests/gates.test.sh`
- `bash scripts/gates/check-tests.sh`

## 다음 단계
- Item 2 handoff source digest를 role read 규칙과 gate 검증에 더 선명하게 연결
