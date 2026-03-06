# Multi-Agent Dev Quick Guide

이 저장소에서 자주 쓰는 명령을 한 곳에 모아둔 운영용 메모다.
명령이 기억 안 나면 여기부터 보면 된다.

## 가장 자주 쓰는 흐름

### 1. 새 요청 시작

```bash
scripts/context-log.sh resume-lite
scripts/start-feature.sh <feature-id>
```

- `resume-lite`: 직전 handoff와 resume snapshot을 만든다.
- `start-feature.sh`: feature packet을 만들거나 활성 feature로 전환한다.

### 2. 지금 에이전트가 뭘 하는지 보기

```bash
scripts/dispatch-heartbeat.sh show
```

- 보통은 `run-log.md`를 직접 열지 말고 이 명령으로 본다.
- `.context/active_feature`가 잡혀 있으면 feature id를 따로 안 넣어도 된다.
- 다른 feature를 보고 싶으면:

```bash
scripts/dispatch-heartbeat.sh show --feature <feature-id>
```

### 3. 오케스트레이터가 상태 갱신할 때

```bash
scripts/dispatch-heartbeat.sh queue <role> "<next action>"
scripts/dispatch-heartbeat.sh start <role> "<first concrete action>"
scripts/dispatch-heartbeat.sh progress <role> "<file/command/blocker>"
scripts/dispatch-heartbeat.sh risk <role> "<why at risk>"
scripts/dispatch-heartbeat.sh blocked <role> "<why blocked>"
scripts/dispatch-heartbeat.sh done <role> "<what finished>"
```

- `queue`: 다음 역할로 넘기기 직전
- `start`: 역할이 실제로 시작했을 때
- `progress`: 파일/명령 기준으로 의미 있는 진행이 생겼을 때
- `risk`: 45초 안에 의미 있는 진행이 안 보여서 주의가 필요할 때
- `blocked`: 120초 내 actionable output이 없거나 진행이 막혔을 때
- `done`: 해당 역할 작업이 끝났을 때

### 4. 중간/최종 검증

```bash
bash scripts/gates/check-tests.sh
scripts/gates/run.sh
scripts/gates/run.sh <feature-id>
```

- `check-tests.sh`: 로컬 smoke + gate regression 테스트
- `gates/run.sh`: packet, role-chain, test-matrix, scope, file-size, tests, secrets 확인

### 5. 작업 완료 기록

```bash
scripts/complete-feature.sh <feature-id> "<summary>" "<next-step>"
```

- gates 통과 후 handoff/context-log까지 마무리한다.

## 언제 어떤 명령을 쓰나

### 새 feature를 시작할 때

```bash
scripts/start-feature.sh <feature-id>
```

### 진행 중인 feature를 바꿀 때

```bash
scripts/set-active-feature.sh <feature-id>
```

### gate만 다시 확인하고 싶을 때

```bash
scripts/gates/run.sh
```

### test-matrix / run-log 규칙이 잘 지켜지는지 보고 싶을 때

```bash
bash scripts/gates/check-tests.sh
```

## 기다릴지 끊을지 판단 기준

`scripts/dispatch-heartbeat.sh show` 결과를 기준으로 본다.

- 기다려도 되는 경우:
  - `last-progress-at-utc`가 최근 45초 이내
  - `last-progress`에 실제 파일 경로 또는 명령이 적혀 있음
- 끊는 게 좋은 경우:
  - `current-status`가 `AT_RISK` 또는 `BLOCKED`
  - 최근 진행 업데이트가 45초 넘게 없음
  - `last-progress`가 "thinking", "checking"처럼 추상적임

## 상세 문서

- Feature packet 구조: `docs/features/README.md`
- Gate 정책: `docs/context/GATES.md`
- 에이전트 역할 계약: `docs/agents/README.md`
