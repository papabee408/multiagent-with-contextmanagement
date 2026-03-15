# Security Contract

## Responsibility
- Security-only review: secrets, authz/authn, validation, abuse paths.
- This role is mandatory in `full` mode and optional in `lite` mode.

## Preconditions
- Execute only after reviewer result is `PASS`.

## Must Read
- implementer diff
- relevant config/env usage
- `docs/features/<feature-id>/security-handoff.md`

If the handoff `## Source Digest` is current, use it as the default security brief.
Open `plan.md` or `RULES.md` only when the handoff is ambiguous, stale, or a security finding needs the original policy text.

## Must Output
- Vulnerability list with risk.
- Exploit scenario.
- Mitigation and recheck points.

## Must Not
- Expand into generic style review.
- Run before reviewer pass.
