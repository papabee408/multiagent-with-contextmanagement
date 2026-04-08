# Stage 06

## 완료 항목
- Item 4: `run-log.md`와 structured role receipt 분리

## 핵심 변경
- `scripts/_role_receipt_helpers.sh`를 추가해 역할별 receipt 경로, JSON 필드 조회, input digest 계산, receipt 기록을 공용화했다.
- `scripts/record-role-result.sh`가 `run-log.md` 역할 섹션을 갱신할 때 동시에 `docs/features/<feature-id>/artifacts/roles/<role>.json` receipt를 기록하도록 만들었다.
- `scripts/gates/check-role-chain.sh`가 `run-log.md` 값과 role receipt 값을 교차 검증하도록 정리했다.
- `docs/context/MULTI_AGENT_PROCESS.md`, `README.md`, `docs/features/README.md`에 사람이 읽는 로그와 기계 검증용 receipt의 역할 차이를 문서화했다.

## 분리된 책임
- `run-log.md`
  - dispatch monitor와 역할 결과를 사람이 읽기 쉽게 유지
  - 운영 흐름 추적과 handoff 확인에 사용
- `artifacts/roles/<role>.json`
  - gate가 읽는 구조화된 결과 receipt
  - `role`, `agent_id`, `scope`, `rq_covered`, `rq_missing`, `result`, `evidence`, `next_action`, `input_digest`, `updated_at_utc`를 고정 필드로 유지

## 안정성 영향
- gate는 markdown 파싱 결과만 믿지 않고 receipt와 일치하는지 함께 본다.
- role receipt는 `record-role-result.sh`로만 생성되므로 형식 드리프트를 줄인다.
- `input_digest`와 `updated_at_utc`를 강제해 stale하거나 불완전한 역할 결과를 더 빨리 잡을 수 있다.

## 검증
- `bash tests/run-log-ops.test.sh`
- `bash tests/gates.test.sh`
- `bash scripts/gates/check-tests.sh`

## 다음 단계
- 전체 작업 종료 보고
