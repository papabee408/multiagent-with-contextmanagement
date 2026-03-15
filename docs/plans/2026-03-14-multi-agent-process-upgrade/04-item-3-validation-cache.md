# Stage 04

## 완료 항목
- Item 3: fingerprint 기반 테스트/게이트 재사용

## 핵심 변경
- `scripts/gates/_validation_cache.sh`를 추가해 feature-test / full-gate fingerprint와 receipt 경로를 공용화했다.
- `scripts/gates/check-tests.sh`가 `--feature-id <feature-id>`를 받을 때 feature-test receipt를 `docs/features/<feature-id>/artifacts/tests/feature.json`에 기록하도록 만들었다.
- `scripts/gates/run.sh`가 tests gate에서 아래 순서로 동작하도록 바꿨다.
  - 현재 feature-test receipt가 fingerprint와 일치하면 feature 테스트 재사용
  - 아니면 `check-tests.sh --feature --feature-id <feature-id>` 실행
  - 그 다음 `check-tests.sh --infra`는 항상 재실행
- `scripts/gates/run.sh --reuse-if-valid <feature-id>`와 `scripts/complete-feature.sh`를 연결해 최신 PASS full-gate receipt가 현재 fingerprint와 일치하면 전체 gate를 재사용하도록 만들었다.

## 안정성 영향
- receipt는 `PASS`이고 fingerprint가 현재 값과 정확히 같을 때만 재사용된다.
- feature packet `artifacts/**`는 fingerprint 입력에서 제외해서 receipt 기록 자체가 cache invalidation 원인이 되지 않게 했다.
- full gate는 여전히 authoritative path이고, 재사용은 완전 일치 시에만 허용된다.

## 검증
- `bash tests/gate-cache.test.sh`
- `bash scripts/gates/check-tests.sh`

## 다음 단계
- Item 6: tester / gate-checker 책임 경계 문서 정리
