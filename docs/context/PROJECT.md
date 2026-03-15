# Project Brief

이 문서는 "무엇을 왜 만드는가"를 정의한다.
다른 프로젝트에 템플릿을 복사했다면 가장 먼저 이 파일부터 갱신한다.

## Identity
- project-name: Multi-Agent Dev Template
- repo-slug: context+MultiAgentDev
- product-type: reusable engineering workflow template

## Product
- Primary goal: multi-agent 작업 흐름에서 요구사항 누락, 역할 혼선, 검증 누락을 줄이는 템플릿을 제공한다.
- Primary users: Codex 기반으로 기능 개발을 운영하는 개발자/팀
- Success signals:
  - 모든 변경이 feature packet과 gate를 통과한다.
  - 요구사항이 `RQ` 단위로 추적된다.
  - 구현 전에 프로젝트 규칙과 구조를 읽는 흐름이 유지된다.

## Stack
- Shell automation: Bash
- CI: GitHub Actions
- Test runner: `node --test` + shell smoke tests
- Primary operating model: feature packet + role contracts + gate scripts

## Constraints
- 로컬과 CI는 같은 gate 명령을 사용해야 한다.
- 문서 규칙은 diff와 스크립트로 검증 가능해야 한다.
- 역할별 책임과 산출물 소유권은 명시적으로 분리한다.

## Working Agreements
- 새 작업은 반드시 `docs/features/<feature-id>/` packet으로 시작한다.
- 요구사항은 `RQ-xxx` 형식으로 분해하고 `brief -> plan -> test-matrix -> run-log`로 추적한다.
- planner는 구현 전에 `ARCHITECTURE.md`를 읽고 이를 `plan.md`에 요약한 뒤 `scripts/sync-handoffs.sh <feature-id>`로 역할별 `*-handoff.md`와 `test-matrix.md`를 갱신한다.
- downstream 역할은 기본적으로 자기 handoff 파일만 읽고, 원문 문서는 handoff가 부족할 때만 다시 연다.
- 재사용 가능한 UI/로직/상수/설정은 공용 모듈로 올리고, 프로덕션 코드에서 산발적인 하드코딩을 남기지 않는다.
