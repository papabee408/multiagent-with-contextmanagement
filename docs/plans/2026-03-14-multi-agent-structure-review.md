# Multi-Agent Structure Review

## 목적
- 현재 멀티 에이전트 템플릿의 구조를 재평가한다.
- 속도 문제를 줄이되, 기존에 필요했던 안전장치는 유지한다.
- "절차를 약하게 만들기"가 아니라 "같은 안전성을 더 낮은 운영비로 유지하기"를 목표로 한다.

## 전제
- 이 템플릿은 프로덕트 개발용이다.
- 과거에는 단계 패싱이 자주 발생했다.
- 그래서 다음 장치는 의도적으로 강하게 들어갔다.
  - 역할별 고유 `agent-id`
  - `planner -> implementer -> tester -> reviewer -> security` 분리
  - `plan.md` 중심의 feature packet
  - 최종 gate 강제
- 따라서 개선 방향은 안전장치를 제거하는 것이 아니라, 중복 비용과 무결성 약점을 제거하는 쪽이어야 한다.

## 실제 프로젝트 기준점
- `HEAD` 기준 현재 템플릿의 feature packet 필수 파일은 아래 4개다.
  - `brief.md`
  - `plan.md`
  - `test-matrix.md`
  - `run-log.md`
- `HEAD` 기준 implementer/tester/reviewer/security는 기본적으로 `plan.md`를 직접 읽는 구조다.
- 현재 working tree에는 `implementer-handoff.md`, `tester-handoff.md`, `reviewer-handoff.md`, `security-handoff.md`와 관련 문서/게이트 변경이 섞여 있다.
- 따라서 이 문서는 아래 두 층을 구분해서 본다.
  - 현재 기준선: committed `HEAD`의 plan-centric 구조
  - 목표 방향: `plan.md`를 정본으로 유지하면서 downstream 역할 전용 handoff를 추가하는 구조

## 현재 구조에 대한 판단

### 유지해야 하는 설계
1. `plan.md`는 유지해야 한다.
   - 실제 프로젝트의 현재 기준선에서도 `plan.md`는 이미 feature packet의 정본이다.
   - handoff를 추가하더라도 `plan.md`를 없애는 방향은 맞지 않다.
   - planner와 gate가 믿는 원본 설계 문서는 계속 `plan.md`여야 한다.

2. 역할별 `*-handoff.md`는 "현재 구조 유지"가 아니라 "도입/정착 후보"로 봐야 한다.
   - actual `HEAD`에는 아직 role-specific handoff가 없다.
   - 다만 downstream 역할이 모두 `plan.md`를 직접 읽는 현재 구조는 context 비용과 역할별 입력 밀도 측면에서 비효율적이다.
   - 따라서 handoff는 기존 구조를 유지하는 항목이 아니라, 현 구조를 개선하기 위한 명시적 도입 항목으로 다루는 것이 맞다.

3. 고유 `agent-id`는 유지해야 한다.
   - 이 장치는 단순한 식별자가 아니라 역할 패싱 방지 장치다.
   - reviewer/security를 실제로 거쳤는지 강제하는 목적이 분명하다.
   - 따라서 이 규칙은 느리더라도 유지 가치가 있다.

4. reviewer/security 필수 단계도 유지해야 한다.
   - 이 템플릿은 "빠른 단일 에이전트 작업"보다 "패싱 불가한 검토 체인"을 더 중요하게 둔다.
   - 이 설계 철학 자체는 타당하다.

### 현재 구조의 실제 문제
1. 같은 tree 상태에 대한 검증이 중복 실행된다.
   - `tester`는 `scripts/gates/check-tests.sh`를 실행한다.
   - `gate-checker`는 `scripts/gates/run.sh`를 실행하는데, 이 안에 다시 `check-tests.sh`가 포함된다.
   - `scripts/complete-feature.sh`도 다시 `scripts/gates/run.sh`를 실행한다.
   - 결과적으로 동일한 코드 상태에서 테스트와 게이트가 2~3회 반복될 수 있다.
   - 이건 안전성 증가보다 속도 저하가 더 큰 중복이다.

2. 현재 gate는 "절차 기록" 검증이 강하고 "최종 상태 승인 무결성" 검증은 상대적으로 약하다.
   - `role-chain`은 `run-log.md`의 `agent-id/scope/result/evidence` 존재 여부와 상태 전이를 강하게 본다.
   - 반면 reviewer/security가 실제 최종 코드 상태를 승인했는지는 약하게 표현된다.
   - 특히 reviewer/security 입력이 `implementer diff` 기준으로 적혀 있어, tester 또는 이후 수정이 있으면 승인 범위와 최종 상태가 어긋날 수 있다.

3. 현재 기준선과 목표 구조가 문서에 혼재되어 있어 역할 입출력 정의가 완전히 정렬되어 있지 않다.
   - actual `HEAD`에서는 implementer/tester/reviewer/security가 모두 `plan.md`를 직접 읽는 계약이다.
   - 반면 working tree와 일부 검토 문서는 handoff 중심 모델을 목표 구조로 가정하고 있다.
   - 그래서 "현재 구조 설명"과 "개선 후 구조 설명"이 문서마다 섞여 있다.
   - `gate-checker`는 문서상 `plan.md + GATES.md + changed files`를 읽는 역할처럼 보이지만, 실제 핵심 책임은 `scripts/gates/run.sh` 실행이다.
   - reviewer/security는 현재도 최종 변경 집합보다 `implementer diff` 기준으로 정의되어 있어 범위가 좁다.

4. `run-log.md`가 너무 많은 책임을 가진다.
   - 현재는 진행 가시화, 역할 결과 기록, role-chain 증빙의 역할을 동시에 맡고 있다.
   - 사람이 읽기 좋은 로그와 gate가 믿는 정본 증빙은 요구사항이 다르다.
   - 이 둘을 같은 파일에 과도하게 실으면 운영 비용이 커진다.

## 핵심 결론
- 현재 구조의 본질적 방향은 맞다.
- 문제는 "안전장치가 많다"가 아니라 "같은 사실을 여러 단계와 여러 파일에서 반복 검증한다"는 데 있다.
- 따라서 개선 방향은 아래와 같아야 한다.
  - `plan.md` 유지
  - `*-handoff.md`는 신규 도입 후 정착 대상으로 검토
  - 고유 `agent-id` 유지
  - reviewer/security 유지
  - 대신 동일 상태 재검증과 절차 중심 증빙을 줄이고, 최종 상태 승인 무결성을 강화

## 개선 원칙
1. 같은 코드 상태는 한 번만 무겁게 검증한다.
2. reviewer/security 승인은 반드시 최종 코드 상태와 연결되어야 한다.
3. 사람이 읽는 로그와 gate가 믿는 증빙은 분리한다.
4. 중기적으로 downstream은 handoff 중심으로 움직이게 만든다.
5. 역할 분리는 유지하되, 역할의 읽기 범위는 더 선명하게 다듬는다.

## 권장 개선안

### 1. `tree hash` 대신 `approval_target_hash + validation_fingerprint`를 도입
각 역할 결과를 자유서술 `run-log.md`만으로 증명하지 말고, feature packet 안에 구조화된 결과 파일로 남긴다.

예시 위치:
- `docs/features/<feature-id>/artifacts/orchestrator.json`
- `docs/features/<feature-id>/artifacts/planner.json`
- `docs/features/<feature-id>/artifacts/implementer.json`
- `docs/features/<feature-id>/artifacts/tester.json`
- `docs/features/<feature-id>/artifacts/gate-checker.json`
- `docs/features/<feature-id>/artifacts/reviewer.json`
- `docs/features/<feature-id>/artifacts/security.json`

핵심 구분:
- `approval_target_hash`
  - reviewer/security가 실제로 승인하는 대상의 hash
  - 기본 정의: 현재 repo 상태를 해시하되, 증빙을 쓰기 위해 뒤늦게 바뀌는 운영 파일은 제외
  - 최소 제외 대상:
    - `docs/features/<feature-id>/run-log.md`
    - `docs/features/<feature-id>/artifacts/**`
- `validation_fingerprint`
  - "이 검증 결과를 재사용해도 되는가"를 판단하는 키
  - `approval_target_hash`만으로 만들지 않고, 아래 입력을 함께 묶는다:
    - diff 기준 정보 (`GATE_DIFF_RANGE`, base ref 등)
    - changed file set
    - `.baseline-changes.txt` 스냅샷
    - 실행 커맨드
    - 필요한 환경 플래그

권장 필드:
- `role`
- `agent_id`
- `result`
- `timestamp_utc`
- `scope`
- `evidence`
- `approval_target_hash`
- `validation_fingerprint`
- `fingerprint_inputs`
- `input_artifact_refs`

reviewer/security 전용 추가 필드:
- `reviewed_approval_target_hash`
- `verdict`
- `findings`

효과:
- `agent-id` 고유성은 계속 강제 가능
- run-log 문장 파싱 의존도를 줄일 수 있음
- 승인 대상과 운영 로그를 분리할 수 있음
- artifact를 기록하는 행위 자체가 승인 대상을 오염시키는 문제를 피할 수 있음

### 2. 동일 `validation_fingerprint`에 대한 중복 실행만 제거
현행 중복:
- tester: `bash scripts/gates/check-tests.sh`
- gate-checker: `scripts/gates/run.sh <feature-id>`
- complete: `scripts/complete-feature.sh` 내부에서 `scripts/gates/run.sh <feature-id>`

개선 방식:
1. tester가 테스트 실행 후 `tester.json`에 다음을 기록한다.
   - `approval_target_hash`
   - `validation_fingerprint`
   - `commands`
   - `status`
   - `executed_at_utc`
2. gate-checker는 계속 "권위 있는 전체 gate 실행자"로 남는다.
3. 다만 `tests` 서브체크에 한해서 현재 `validation_fingerprint`가 tester artifact와 정확히 같으면 `check-tests.sh` 결과를 재사용할 수 있다.
4. `scope`, `file-size`, `role-chain`, `secrets`처럼 diff/policy/current packet에 직접 의존하는 항목은 계속 gate-checker가 현재 상태 기준으로 실행한다.
5. `complete-feature.sh`는 "현재 fingerprint와 정확히 일치하는 마지막 PASS gate artifact"가 있으면 이를 재사용하고, 아니면 `scripts/gates/run.sh <feature-id>`를 다시 실행한다.

중요한 점:
- 이 방식은 최종 authoritative gate를 제거하지 않는다.
- 제거하는 것은 "같은 fingerprint에 대한 반복 실행"뿐이다.
- `tree`만 같다고 재사용하지 않고, gate 의미에 영향을 주는 입력이 모두 같을 때만 재사용한다.

### 3. reviewer/security를 최종 승인 단계로 재정의하되, 승인 무효 조건을 명시
현재 정의의 약점:
- reviewer/security가 `implementer diff` 중심으로 서술되어 있다.
- 하지만 실제 최종 상태는 tester 수정, test-matrix 갱신, 후속 보완까지 포함한 packet 전체다.

개선:
- reviewer 입력 기본값을 `reviewer-handoff.md + final diff + latest gate summary + approval_target_hash`로 바꾼다.
- security 입력 기본값도 `security-handoff.md + final diff + approval_target_hash + config/env touchpoints`로 바꾼다.
- reviewer/security의 PASS artifact는 `reviewed_approval_target_hash`를 반드시 기록한다.
- reviewer/security PASS 이후, `run-log.md`와 `artifacts/**`를 제외한 파일이 바뀌면 승인은 자동 무효 처리한다.
- code-changing role을 명시한다.
  - 수정 가능: implementer, tester
  - 수정 불가: gate-checker, reviewer, security, orchestrator
- reviewer/security가 수정을 요구하면 흐름은 `implementer -> tester -> gate-checker -> reviewer -> security`로 다시 돈다.

효과:
- reviewer/security 패싱 방지를 더 강하게 만든다.
- "승인받고 나서 다시 바뀐 코드"를 자동으로 잡을 수 있다.
- 최종 승인 범위가 실제 packet 상태와 일치한다.

### 4. `role-chain`을 run-log 단독 검증에서 "이원 무결성 검증"으로 확장
현재 `role-chain`은 유용하지만, 검증 단위가 텍스트 로그에 치우쳐 있다.

개선 방향:
- 1단계: 기존 `run-log.md` 검증 유지
- 2단계: artifact 존재, `agent_id` 고유성, 상태전이, `reviewed_approval_target_hash` 일치 여부를 함께 검증
- 3단계: gate를 두 층으로 나눈다.
  - `run-log.md`: live dispatch monitor, 현재 active role, 상태전이
  - `artifacts/*`: immutable verdict, 승인 대상 hash, 재사용 가능한 검증 fingerprint

유지할 규칙:
- 7개 역할 고유 `agent-id`
- reviewer FAIL 시 security BLOCKED
- reviewer PASS 없이 security PASS 불가
- planner PASS 없이 implementer PASS 불가

바꿀 규칙:
- "로그 필드가 채워졌는가" 단독 중심에서
- "live monitor가 정상인가 + 최종 승인 artifact가 현재 승인 대상을 가리키는가" 중심으로 확장

### 5. 역할별 읽기 범위 재정리

#### planner
- 유지
- 현재처럼 `brief.md`, `PROJECT.md`, `ARCHITECTURE.md`, `GATES.md`, `test-matrix.md`를 읽고 handoff를 만든다.

#### implementer
- 유지
- 기본 입력은 계속 `implementer-handoff.md + RULES.md`
- `plan.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`는 fallback read만 허용

#### tester
- 단기: 현재 구조 유지 가능
- 중기 개선:
  - 기본 입력은 `tester-handoff.md + test-matrix.md + test-guide.md + current diff + approval_target_hash`
  - `GATES.md`는 planner handoff가 충분히 성숙할 때 fallback read로 내린다.

이유:
- 현재 철학상 gate 기대치는 planner가 handoff에 녹이는 쪽이 맞다.
- 다만 즉시 제거는 리스크가 있으므로 단계적으로 전환하는 편이 안전하다.

#### gate-checker
- 역할은 유지
- 다만 역할 정의를 더 정확히 적는다.
- 실제 책임은 "권위 있는 full gate 실행 + 서브체크 재사용 가능 여부 판정 + artifact 기록"이다.
- `plan.md`, `GATES.md`, changed file list는 진단과 설명에 필요하지만, 계약의 중심은 `scripts/gates/run.sh <feature-id>` 실행이다.

#### reviewer
- 기본 입력을 `reviewer-handoff.md + final diff + latest gate summary + approval_target_hash`로 재정의
- `implementer diff` 표현은 제거하고, 필요하면 `final diff`의 일부 근거로만 본다

#### security
- 기본 입력을 `security-handoff.md + final diff + approval_target_hash`로 재정의
- `config/env touchpoints`는 `security-handoff.md`의 정규 필드로 유지하고, contract 문서도 그에 맞게 정렬한다

### 6. `run-log.md`의 역할은 줄이되, live monitor 책임은 유지
`run-log.md`는 계속 남겨야 한다. 다만 역할을 명확히 나누는 것이 좋다.

유지 역할:
- 운영자 가시화
- 현재 active role 추적
- 상태전이와 Dispatch Monitor의 실시간 근거
- 사람 읽기용 진행 요약

artifact로 옮길 역할:
- immutable 승인 기록
- gate/test 재사용 판단 키
- reviewer/security가 정확히 무엇을 승인했는지에 대한 정본

이유:
- 사람이 읽기 좋은 문장과 기계가 신뢰할 증빙은 최적 형태가 다르다.
- 하지만 live orchestration은 여전히 `run-log.md`가 가장 잘 표현한다.

## 단계별 적용 순서

### Phase 1: 승인 대상 모델 명확화
- role artifact 파일 추가
- 각 artifact에 `agent_id`, `result`, `approval_target_hash`, `validation_fingerprint` 기록
- reviewer/security에 `reviewed_approval_target_hash` 기록
- hash 계산에서 `run-log.md`, `artifacts/**`를 제외하는 규칙 명시
- 기존 `run-log.md`와 `role-chain`은 그대로 유지

목표:
- 자기참조 없는 승인 모델을 먼저 만든다.

### Phase 2: 중복 실행 제거
- tester artifact와 gate-checker의 `tests` 서브체크를 `validation_fingerprint` 기준으로 재사용
- `complete-feature.sh`도 현재 fingerprint와 정확히 일치하는 마지막 PASS gate artifact만 재사용

목표:
- 가장 큰 속도 병목을 안전하게 줄인다.

### Phase 3: 역할 계약 정리
- reviewer/security 입력을 final-state 기준으로 수정
- code-changing role과 non-mutating role을 명시
- `gate-checker` 계약을 실제 실행 역할에 맞게 단순화
- `security` contract 문서를 `security-handoff.md` 구조와 정렬

목표:
- 역할 정의와 실제 책임을 일치시킨다.

### Phase 4: `role-chain` 이원 검증화
- run-log 파싱 기반 검증은 유지
- 동시에 artifact 기반 승인 무결성 검증을 추가
- gate는 "운영 모니터 검증"과 "최종 승인 검증"을 둘 다 본다

목표:
- 절차 기록과 결과 무결성을 동시에 강하게 만든다.

### Phase 5: tester의 `GATES.md` 기본 읽기 축소
- planner handoff 품질이 안정된 뒤에만 적용
- 즉시 제거하지 말고, fallback read로 내리는 식으로 전환

목표:
- handoff 중심 모델을 실제로 완성한다.

## 유지할 것 / 바꿀 것

### 유지할 것
- `plan.md` 정본 구조
- 고유 `agent-id`
- reviewer/security 필수 단계
- 최종 gate 강제
- `run-log.md`의 live monitor 역할

### 새로 도입하거나 정착시킬 것
- 역할별 `*-handoff.md`
- handoff를 검증하는 gate/contract
- handoff 중심 downstream read model

### 바꿀 것
- 동일 `validation_fingerprint` 상태 재검증
- reviewer/security의 승인 기준을 `implementer diff`에 묶는 구조
- `run-log.md`를 immutable 승인 정본으로 삼는 구조
- gate-checker 계약의 과도하게 추상적인 설명
- `security` contract와 `security-handoff.md`의 불일치

## 최종 판단
- 현재 템플릿은 폐기 대상이 아니다.
- 구조 철학은 맞고, 특히 `plan.md` 정본은 유지해야 한다. 역할별 handoff 분리는 현재 구조 유지가 아니라 다음 개정에서 도입·정착시킬 대상이다.
- 다만 속도를 깎는 병목은 실제로 존재하며, 그 병목은 대부분 "같은 fingerprint에 대한 반복 실행"과 "운영 로그와 승인 정본의 혼재"에서 나온다.
- 따라서 다음 개정은 안전장치를 완화하는 방향이 아니라, 아래 방향으로 가는 것이 맞다.
  - 동일 `validation_fingerprint` 재검증 제거
  - reviewer/security 승인 범위를 최종 승인 대상에 연결
  - `run-log.md`와 immutable 승인 artifact 분리
  - artifact 기반 무결성 검증 강화
  - live dispatch monitor는 계속 `run-log.md`에 유지

이 방향이면 현재 템플릿의 핵심 목표인 "패싱 방지"를 유지하면서도, 가장 큰 속도 병목을 줄일 수 있다.
