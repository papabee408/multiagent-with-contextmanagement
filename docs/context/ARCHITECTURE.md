# Architecture Boundaries v2

## 목적
- 이 문서는 "어디에 넣고 어떻게 의존해야 하는가"를 정의한다.
- 컨텍스트 리셋 이후에도 모듈 책임과 의존 방향을 빠르게 파악한다.
- 기능 추가 시 어디에 코드를 넣어야 하는지 일관된 기준을 제공한다.

## System Map
- Entry/Application layer:
  - 요청 흐름 시작점, 이벤트 연결, orchestration
- Feature/Domain layer:
  - 비즈니스 규칙, 상태 전이, 유스케이스
- UI/Presentation layer:
  - 렌더링, 입력 수집, 화면 조합
- Infrastructure/Integration layer:
  - 외부 API, DB, 파일, 모델, 네트워크, 런타임 어댑터
- Shared layer:
  - 공용 컴포넌트, 헬퍼, schema, constants, test support

## Layers
1. Entry/Application 레이어는 orchestration만 담당한다.
   - 상태 전이 트리거, 모듈 호출 조합, 흐름 제어
2. Feature/Domain 레이어는 핵심 규칙을 가진다.
   - 가능하면 pure 하게 유지하고 UI/IO 세부사항을 모르게 한다.
3. UI/Presentation 레이어는 사용자 표시와 상호작용만 담당한다.
   - 비즈니스 규칙과 외부 호출 로직을 직접 소유하지 않는다.
4. Infrastructure/Integration 레이어는 외부 시스템과의 경계다.
   - 입력/출력을 정규화해서 상위 레이어로 전달한다.
5. Shared 레이어는 중복 제거를 위한 공용 기반이다.
   - 특정 화면/기능에 강하게 결합된 코드를 shared로 올리지 않는다.

## Dependency Direction
- 허용: `entry/application -> feature/domain -> infrastructure`
- 허용: `entry/application -> ui/presentation`
- 허용: `feature/domain -> shared`
- 허용: `ui/presentation -> shared`
- 금지: `feature/domain -> ui/presentation`
- 금지: `infrastructure -> ui/presentation`
- 금지: 하위 레이어가 상위 orchestration 레이어를 import 하는 구조

## Placement Guide
1. 새 기능이 사용자 흐름 추가라면:
   - entry/application에 연결하고, 핵심 규칙은 feature/domain에 둔다.
2. 새 계산 규칙이나 상태 전이라면:
   - feature/domain 또는 하위 pure helper에 둔다.
3. 새 외부 연동이나 응답 정규화라면:
   - infrastructure/integration 모듈에 둔다.
4. 반복되는 UI 패턴이라면:
   - shared UI primitive 또는 feature-composed component로 분리한다.

## Shared Abstractions
1. 둘 이상의 feature에서 쓰이는 UI/로직/상수만 shared로 올린다.
2. shared abstraction은 구체적인 feature 이름을 품지 않게 한다.
3. 재사용 후보가 보이면 먼저 기존 shared 레이어를 확인하고 없을 때만 새 abstraction을 만든다.

## Legacy and Large Files
현재 큰 파일은 레거시 후보로 본다.
1. 신규 로직은 대형 파일 내부에 계속 추가하기보다 하위 모듈로 분리한다.
2. 대형 파일 수정 PR에서는 최소 1개 이상의 helper 또는 shared abstraction 추출을 권장한다.
3. 장기적으로는 화면/도메인/연동 경계를 기준으로 더 작은 모듈로 나눈다.
