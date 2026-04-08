# Multi-Agent Process Rollout Tracker

## 목적
- 멀티 에이전트 효율화 1-6번 구현의 진행 상황을 한 파일에서 관리한다.
- 단계별 완료 보고 문서 위치를 모아둔다.
- 중간에 컨텍스트가 끊겨도 다음 작업자가 바로 이어서 진행할 수 있게 한다.

## 구현 순서
1. item-1: `plan.md` 정본화 + handoff 동기화 도입
2. item-2: handoff `source digest` 도입
3. item-5: orchestration wrapper command 도입
4. item-6: tester / gate-checker 책임 경계 정리
5. item-3: fingerprint 기반 테스트 / gate 재사용
6. item-4: `run-log.md`와 structured role receipt 분리

## 해야할 일
- [ ] item-4용 structured role receipt 저장 / 검증 연동
- [ ] 전체 회귀 테스트 실행 및 문서 갱신

## 진행중
- [ ] item-4 structured role receipt 저장 / wrapper / gate 연동 구현

## 완수된 일
- [x] 전용 rollout 추적 폴더 생성
- [x] 단계 구현 순서 확정: `1 -> 2 -> 5 -> 6 -> 3 -> 4`
- [x] item-1용 handoff sync 방식 확정 및 구현
- [x] item-1 관련 템플릿 / gate / 테스트 정렬
- [x] item-2용 digest 필드 및 검증 규칙 추가
- [x] item-5용 wrapper command 구현
- [x] item-5 관련 run-log 갱신 흐름 테스트 추가
- [x] item-6 관련 역할 문서 / 실행 경로 정리
- [x] item-3용 fingerprint / receipt 포맷 설계
- [x] item-3 관련 `check-tests.sh`, `run.sh`, `complete-feature.sh` 캐시 연동

## 단계 보고 문서
- `STAGE-01-item-1-plan-canonicalization.md`
- `STAGE-02-item-2-handoff-source-digest.md`
- `STAGE-03-item-5-run-log-wrapper-commands.md`
- `STAGE-04-item-6-tester-gate-checker-boundary.md`
- `STAGE-05-item-3-validation-cache.md`

## 참고 메모
- 단계 보고 문서는 이 폴더 안에 `STAGE-0N-*.md` 형식으로 추가한다.
- 기존 `docs/plans/2026-03-14-multi-agent-process-efficiency-plan.md`는 설계 제안 문서이고, 실제 진행 기록은 이 tracker가 기준이다.
