# Stage 04: Item 6 Complete

## 범위
- tester / gate-checker 책임 경계 정리

## 완료 내용
- `scripts/gates/check-tests.sh`를 `--feature`, `--infra`, `--full` 모드로 분리했다.
- `scripts/gates/run.sh`는 `tests` gate에서 `check-tests.sh --full`을 명시적으로 호출하도록 정리했다.
- tester 계약은 `--feature`를, gate-checker 계약은 full `run.sh` 경로를 담당하도록 문서화했다.
- `tests/check-tests-modes.test.sh`를 추가해 각 모드가 실제로 기대 범위만 실행하는지 검증했다.

## 검증
- `bash tests/check-tests-modes.test.sh`
- `bash scripts/gates/check-tests.sh --feature`
- `bash scripts/gates/check-tests.sh --infra`
- `bash scripts/gates/check-tests.sh`

## 메모
- tester는 feature-facing test 실행자, gate-checker는 최종 정책 판정자로 경계를 분리했다.
- 이후 item-3 캐시는 `check-tests.sh --feature` 결과와 full gate 결과를 별도로 재사용하는 기반이 된다.
