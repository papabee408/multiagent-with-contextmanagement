# Multi-Agent Process Upgrade Tracker

## 목적
- 멀티 에이전트 프로세스 개선 작업의 해야 할 일, 진행 중 작업, 완료된 작업을 한 곳에서 관리한다.
- 단계별 완료 보고 문서 위치를 추적한다.
- 구현 순서는 효과와 의존성을 기준으로 유연하게 조정하되, 상태는 이 파일에서만 관리한다.

## 작업 원칙
- 안정성 기준은 유지한다.
- 기존 source of truth와 실제 스크립트 동작이 충돌하면 스크립트와 테스트를 기준으로 판단한다.
- 단계가 끝날 때마다 이 폴더에 별도 보고 md 파일을 남긴다.
- 새 보고 파일은 이 폴더 밖으로 만들지 않는다.

## 안정성 기준
- feature packet 구조 유지
- `planner -> implementer -> tester -> gate-checker -> reviewer -> security` 역할 체인 유지
- `plan.md` 소유권은 planner 유지
- 최종 완료 조건은 gate 기준 유지
- 고유 `agent-id` 유지

## 구현 순서
1. Item 1: `plan.md` 정본화 + handoff 자동 생성
2. Item 2: handoff `source digest`
3. Item 5: orchestration wrapper command
4. Item 3: fingerprint 기반 테스트/게이트 재사용
5. Item 6: tester / gate-checker 책임 경계 정리
6. Item 4: `run-log.md`와 structured receipt 분리

## 해야 할 일
- 없음

## 진행 중
- 없음

## 완료된 일
- 전용 추적 폴더 생성
- tracker 파일 생성
- 현재 packet/template/gate/test 구조를 읽고 변경 범위를 확정
- Item 1 구현 완료
- Item 2 구현 완료
- Item 5 검증 완료
- Item 3 구현 완료
- Item 6 정리 완료
- Item 4 구현 완료
- 전체 테스트 및 회귀 검증 완료
- 최종 보고 정리 완료
- stage 01 / stage 02 보고 작성
- stage 03 보고 작성
- stage 04 / stage 05 보고 작성
- stage 06 보고 작성

## 단계 보고 파일
- `01-item-1-plan-source-and-handoff-sync.md`
- `02-item-2-handoff-source-digest.md`
- `03-item-5-orchestration-wrapper-commands.md`
- `04-item-3-validation-cache.md`
- `05-item-6-tester-gate-checker-boundary.md`
- `06-item-4-structured-role-receipts.md`

## 메모
- 이 폴더는 진행 관리와 단계 보고 전용이다.
- 실제 운영 스크립트/템플릿/테스트 수정은 기존 경로를 유지한다.
- 최종 상태는 6개 개선 항목 완료, `bash scripts/gates/check-tests.sh` 통과다.
