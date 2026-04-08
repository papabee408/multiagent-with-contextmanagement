# Implementer Rules v2

## 목적
- 이 문서는 "반드시 지켜야 하는 최소선"을 정의한다.
- 구현자가 코드를 쓰는 순간 바로 적용할 수 있는 최소 규칙만 둔다.
- 가능한 규칙은 diff, 파일 경로, gate 결과로 검증 가능해야 한다.

## 적용 대상
- 모든 production/source/test/config 변경
- 문서-only 작업은 일부 규칙을 축약할 수 있지만, placeholder 제거와 범위 규칙은 그대로 적용한다.
- 정상 흐름에서는 `implementer`가 production/config 변경을 소유한다.
- `tester`는 `full` mode에서만 `tests/**`를 보강할 수 있고, production/config는 수정하지 않는다.

## Scope and RQ
1. 모든 구현 작업은 `RQ-xxx` 기준으로 진행한다.
2. `plan.md`의 target files 밖 수정은 금지한다.
3. 범위 밖 수정이 필요하면 구현을 멈추고 planner/orchestrator 승인을 다시 받는다.

## Reuse and Hardcoding
1. `CONVENTIONS.md`의 재사용/상수화 기본값을 거스르는 중복 구현을 새로 추가하지 않는다.
2. 이미 존재하는 공용 추상화와 겹치는 새 파일/함수/컴포넌트 생성은 금지한다.
3. 외부 의미가 있는 설정값, 상태값, 제한값을 production 코드에 산발적인 literal로 남기지 않는다.

## File and Function Size
1. 신규 소스 파일은 700줄 초과 금지.
2. 신규 함수는 80줄 초과 금지.
3. 기존 대형 파일 수정 시:
   - 줄 수를 유지하거나 감소시키는 방향을 우선한다.
   - 새 로직은 가능한 한 별도 모듈로 분리한다.

## Architecture Fit
1. 새 코드는 `ARCHITECTURE.md`의 레이어와 의존 방향을 따라야 한다.
2. 비즈니스 규칙은 UI/IO 코드에 섞지 않는다.
3. 공용 UI primitive와 도메인 특화 조합 코드는 같은 파일에 섞지 않는다.

## Testing
1. 기능 변경 시 테스트를 반드시 갱신한다.
2. `implementer`는 기본 테스트 갱신 책임을 가진다.
3. `full` mode의 `tester`는 coverage gap이 남았을 때만 `tests/**`를 강화한다.
4. 최소 커버리지 단위:
   - 정상 경로 1개
   - 오류 경로 1개
   - 경계값 1개
5. 테스트 작성 스타일은 `test-guide.md`를 따른다.
6. 테스트에서 구현 로직을 복붙해 기대값을 계산하지 않는다.

## Security and Reliability
1. 비밀값(API key, token, secret) 하드코딩 금지.
2. 외부 입력과 모델 출력은 정규화 및 기본 검증을 거친다.
3. 외부 호출 실패 시 fallback 또는 안전 실패 경로를 제공한다.
4. 에러 메시지는 원인 파악 가능하지만 민감정보는 포함하지 않는다.

## Forbidden Patterns
1. 근거 없는 `PASS` 선언
2. 미사용 디버그 코드/주석 잔존
3. 계획 외 파일 변경 후 무보고
4. 테스트 미갱신 상태로 기능 변경 완료 처리
5. 복붙 변형으로 중복 구현 추가
6. 새 설정/상수를 인라인 literal로 흩뿌리기

## 완료 보고 규칙
구현자 출력에는 반드시 포함한다.
1. 변경 파일 목록
2. `rq_covered` / `rq_missing`
3. 실행한 테스트/검증 커맨드
4. 잔여 리스크 또는 후속 작업
