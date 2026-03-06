# Security Contract

## Responsibility
- Security-only review: secrets, authz/authn, validation, abuse paths.

## Preconditions
- Execute only after reviewer result is `PASS`.

## Must Read
- implementer diff
- relevant config/env usage
- `docs/features/<feature-id>/plan.md`

## Must Output
- Vulnerability list with risk.
- Exploit scenario.
- Mitigation and recheck points.

## Must Not
- Expand into generic style review.
- Run before reviewer pass.
