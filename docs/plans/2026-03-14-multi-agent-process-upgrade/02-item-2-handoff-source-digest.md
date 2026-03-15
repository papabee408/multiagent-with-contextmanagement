# Stage 02

## 완료 항목
- Item 2: handoff `source digest`

## 핵심 변경
- generated handoff에 `## Source Digest` 블록을 포함시켰다.
- `scripts/gates/check-handoffs.sh`가 handoff digest와 현재 `brief.md`, `plan.md`, `PROJECT.md`, `ARCHITECTURE.md`, `GATES.md` hash를 비교해 stale handoff를 fail 처리하도록 만들었다.
- downstream role 문서에 digest가 최신이면 handoff를 기본 신뢰하고, stale/ambiguous일 때만 원문을 재오픈하도록 명시했다.
- `test-matrix.md`에도 source digest 필드를 남겨 planner sync와 tester verify 시점을 분리해서 추적할 수 있게 했다.

## 안정성 영향
- handoff 최신성 검증이 기계화됐다.
- downstream이 방어적으로 `plan.md`나 shared doc를 다시 읽어야 하는 상황이 줄었다.
- sync가 누락되면 gate가 바로 잡기 때문에, 오래된 handoff를 들고 진행하는 리스크가 내려갔다.

## 검증
- `bash tests/sync-handoffs.test.sh`
- `bash tests/gates.test.sh`
- `bash scripts/gates/check-tests.sh`

## 다음 단계
- Item 5 orchestration wrapper command
