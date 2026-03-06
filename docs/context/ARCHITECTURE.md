# Architecture Boundaries v1

## 목적
- 컨텍스트 리셋 이후에도 모듈 책임과 의존 방향을 빠르게 파악한다.
- 기능 추가 시 어디에 코드를 넣어야 하는지 일관된 기준을 제공한다.

## 현재 시스템 개요
- UI shell: `builder/index.html`, `builder/styles.css`
- 런타임 엔트리: `builder/src/app.mjs`
- 상태/순수 로직: `builder/src/app-state.mjs`, `builder/src/data.mjs`
- 렌더/뷰 유틸: `builder/src/app-view.mjs`
- 상세 프리뷰: `builder/src/design-preview*.mjs`, `builder/src/ia-preview*.mjs`
- LLM 계층: `builder/src/llm-design-space.mjs`, `builder/src/llm-recommendation.mjs`
- 품질 계층: `builder/src/quality-gate.mjs`
- 코드 내보내기: `builder/src/swiftui-export.mjs`

## 레이어 규칙
1. `app.mjs`는 오케스트레이션 레이어다.
   - 상태 전이 트리거, 이벤트 바인딩, 모듈 호출 조합만 담당
2. `app-state.mjs`는 pure state helper 레이어다.
   - DOM 접근 금지
3. `app-view.mjs`는 렌더 포맷 레이어다.
   - 네트워크 호출 금지
4. `llm-*` 모듈은 외부 모델 통신/정규화 레이어다.
   - DOM 직접 접근 금지
5. `quality-gate.mjs`는 품질 판정 레이어다.
   - UI 문자열 결합 로직 최소화

## 의존 방향
- 허용: `app.mjs -> state/view/llm/preview/quality/export`
- 허용: `preview -> ia/*`, `preview -> shared util`
- 금지: `state -> app.mjs`
- 금지: `view -> llm`
- 금지: `llm -> DOM`

## 변경 지침
1. 새 기능이 UI 상호작용이면:
   - `app.mjs` 이벤트 훅 + 필요한 모듈 함수 추가
2. 새 계산 규칙이면:
   - `app-state.mjs` 또는 별도 pure helper 모듈 추가
3. LLM 스키마/정규화 변경이면:
   - `llm-design-space.mjs`와 대응 테스트 함께 갱신
4. 품질 기준 변경이면:
   - `quality-gate.mjs`와 `quality-gate.test.mjs` 동시 갱신

## 대형 파일 대응 원칙
현재 대형 파일(`app.mjs`, `design-preview.mjs`, `llm-design-space.mjs`)은 레거시로 간주한다.
1. 신규 로직은 대형 파일 내부에 추가하기보다 `src/<domain>/` 하위 모듈로 분리한다.
2. 대형 파일 수정 PR에서는 최소 1개 이상의 helper 추출을 권장한다.
3. 장기적으로 화면/도메인 단위 모듈화(예: `src/workflows/`, `src/preview/`, `src/llm/`)를 목표로 한다.
