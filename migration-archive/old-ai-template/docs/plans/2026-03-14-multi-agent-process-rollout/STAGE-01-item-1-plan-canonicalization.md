# Stage 01: Item 1 Complete

## 범위
- `plan.md` 정본화 + generated handoff / `test-matrix.md` sync 흐름 도입

## 완료 내용
- `scripts/sync-handoffs.sh`를 추가해 `brief.md`와 `plan.md`로부터 handoff 4종과 `test-matrix.md`를 생성/갱신하게 했다.
- `scripts/feature-packet.sh`가 packet 생성 직후 sync를 호출하도록 연결했다.
- planner / orchestrator / packet 운영 문서를 `plan -> sync-handoffs -> downstream handoff` 흐름으로 정렬했다.

## 검증
- `bash tests/gates.test.sh`
- `bash tests/sync-handoffs.test.sh`
- `bash scripts/gates/check-tests.sh`

## 메모
- handoff는 generated output으로 취급한다.
- planner의 직접 산출물은 `plan.md` 중심이고, downstream 전달본은 sync 결과를 기준으로 본다.
