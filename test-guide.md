# Test Guide

Use this guide when writing or updating tests in repositories that adopt this template.

## Minimum Coverage

Every behavior change should cover:

- one normal path
- one error path
- one boundary path

## Naming

Prefer names that read like behavior statements:

- `returns the existing session when the cache is warm`
- `fails safely when the token is missing`

Avoid generic names like:

- `works`
- `test`
- `should work`

## Structure

Keep tests easy to scan:

1. arrange
2. act
3. assert

## Reliability

- no hidden test order dependency
- no production API or production DB calls
- no copied implementation logic inside assertions
- no flaky timers or random assertions without control

## Scope Discipline

Tests should verify the task's acceptance, not unrelated code paths outside the task.
