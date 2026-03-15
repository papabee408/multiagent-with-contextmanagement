# Coding Conventions

이 문서는 "보통 어떻게 쓰는가"를 정리한다.
`RULES.md`가 gate 가능한 최소 규칙이라면, 이 문서는 구현 품질의 기본값을 정의한다.
여기서는 선호하는 기본 방향을 다루고, pass/fail 기준은 `RULES.md`에 둔다.

## Reuse First
- 같은 화면 패턴, 비즈니스 계산, 직렬화 규칙, 상태 전환이 2회 이상 반복되면 공용 컴포넌트/헬퍼/상수로 올린다.
- 비슷하지만 조금 다른 구현을 복붙해서 늘리기보다, 공통 축을 먼저 추출한 뒤 변형 지점을 주입한다.
- 이미 존재하는 추상화가 있으면 이름만 바꾼 새 모듈을 만들지 않는다.

## Configuration and Constants
- 엔드포인트, 제한값, feature flag, 상태값, 라벨 세트, 디자인 토큰, 환경 의존 값은 가능한 한 named constant/config/schema로 모은다.
- 반복되거나 외부 의미가 있는 값은 인라인 literal보다 명시적 이름을 선호한다.
- 테스트용 샘플 데이터는 fixture/fake/test helper로 모은다.

## Components and Modules
- UI 공통 패턴은 shared component로 만들고, 화면별 조합은 feature module에서 담당한다.
- 도메인 로직은 UI 프레임워크와 분리한다.
- 새 파일을 만들 때는 "이 책임이 정말 새 모듈이어야 하는가"를 먼저 확인한다.

## Performance Hygiene
- 눈에 띄는 중복 계산, 반복 변환, 불필요한 재조회, 같은 데이터에 대한 다중 순회를 hot path에 남기지 않는다.
- 성능 개선은 추측보다 구조 개선을 우선한다: 중복 제거, 책임 분리, 필요한 곳의 캐시/전처리.
- 가독성을 해칠 정도의 미세 최적화는 피하고, reviewer는 "명백한 낭비"만 실패 사유로 본다.

## Naming and Data Shapes
- 이름은 역할이 아니라 책임을 드러내야 한다.
- 같은 개념은 저장소 전체에서 같은 용어를 쓴다.
- 외부 입력은 내부 모델로 정규화한 뒤 사용한다.

## Tests and Change Hygiene
- 테스트는 구현을 복사하지 않고 기대 결과를 명시한다.
- 디버그 로그, 임시 플래그, 미사용 코드, TODO 주석은 머지 전에 제거한다.

## Reviewer Focus
- reviewer는 중복 구현, 하드코딩, 아키텍처 경계 위반을 우선적으로 본다.
- reviewer는 공용 컴포넌트/헬퍼로 올려야 할 반복 구현이 남아 있는지 본다.
- reviewer는 외부 의미가 있는 값이 산발적 literal로 남았는지 본다.
- reviewer는 명백한 성능 낭비가 남아 있는지 본다.
- planner는 구현 전에 재사용 후보와 상수/설정 분리 계획을 `plan.md`에 기록한다.
