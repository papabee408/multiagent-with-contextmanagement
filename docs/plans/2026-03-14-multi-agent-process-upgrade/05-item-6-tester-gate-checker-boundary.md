# Stage 05

## 완료 항목
- Item 6: tester / gate-checker 책임 경계 정리

## 핵심 변경
- tester 계약을 `scripts/gates/check-tests.sh --feature` 기준으로 고정했다.
- gate-checker 계약을 `scripts/gates/run.sh <feature-id>` 기준으로 유지하되, 실제 tests gate 동작이 `feature receipt reuse + infra 재실행`이라는 점을 문서에 맞췄다.
- `MULTI_AGENT_PROCESS.md`에서 tester와 gate-checker의 실행 책임을 실제 코드 기준으로 다시 서술했다.

## 정리된 책임
- tester
  - feature-facing test 실행
  - `test-matrix.md` finalize
  - feature-test receipt 생성
- gate-checker
  - full policy gate 실행
  - feature-test receipt 재사용 가능 여부 판단
  - infra smoke/regression 재실행
  - full-gate receipt 생성

## 안정성 영향
- 테스트 책임이 문서와 코드에서 더 일치하게 됐다.
- tester와 gate-checker가 같은 범위의 테스트를 반복 실행하지 않아도 되는 구조가 명확해졌다.
- 최종 정책 판정은 여전히 gate-checker와 `run.sh`가 가진다.

## 검증
- `bash tests/gate-cache.test.sh`
- `bash scripts/gates/check-tests.sh`

## 다음 단계
- Item 4: `run-log.md`와 structured role receipt 분리
