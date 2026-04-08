# Stage 05: Item 3 Complete

## 범위
- fingerprint 기반 test / full gate 재사용

## 완료 내용
- `scripts/gates/_validation_cache.sh` 기반으로 feature-test receipt와 full-gate receipt 경로를 실제 검증 흐름에 연결했다.
- `scripts/gates/run.sh`는 tester가 남긴 feature-test receipt를 재사용할 수 있고, `--reuse-if-valid`로 full-gate PASS receipt도 재사용할 수 있게 했다.
- `scripts/complete-feature.sh`는 `run.sh --reuse-if-valid` 경로를 사용하도록 정렬됐다.
- `tests/gate-cache.test.sh`를 통해 feature receipt 재사용, full gate 재사용, fingerprint 변경 시 무효화를 smoke로 고정했다.

## 검증
- `bash tests/gate-cache.test.sh`
- `bash scripts/gates/check-tests.sh`

## 메모
- 캐시는 fail-open이 아니라 fail-closed로 동작한다.
- fingerprint가 다르거나 receipt가 없으면 즉시 재실행한다.
