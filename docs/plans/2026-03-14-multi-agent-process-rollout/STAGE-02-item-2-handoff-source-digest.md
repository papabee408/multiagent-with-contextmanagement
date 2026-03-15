# Stage 02: Item 2 Complete

## 범위
- handoff / `test-matrix.md` source digest 도입 및 stale 상태 gate 검증

## 완료 내용
- generated handoff에 `brief/plan/project/architecture/gates` digest와 생성 시각을 기록하게 했다.
- `scripts/gates/check-handoffs.sh`가 source digest mismatch를 stale failure로 판단하도록 정렬했다.
- `scripts/gates/check-test-matrix.sh`에 `source-brief-sha`, `source-plan-sha` 검증을 추가했다.
- `tests/gates.test.sh`, `tests/sync-handoffs.test.sh`에 stale digest와 resync 복구 케이스를 넣었다.

## 검증
- `bash tests/gates.test.sh`
- `bash tests/sync-handoffs.test.sh`
- `bash scripts/gates/check-tests.sh`

## 메모
- sync를 생략한 오래된 handoff / matrix는 gate에서 바로 실패한다.
- downstream 역할은 digest가 최신이라는 전제 위에서 handoff만 읽고 진행할 수 있다.
