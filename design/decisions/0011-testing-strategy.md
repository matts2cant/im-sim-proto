# 11. Testing: three layers with GdUnit4

Status: Accepted

Date: 2026-11-05

## Context

Systemic interactions regress easily, and AI agents write much of the code.

## Decision

Use GdUnit4 in three layers (unit, integration, scenario) written alongside every feature; nothing merges without them. Use a manual playtest checklist for feel.

## Alternatives considered

- Manual testing only.
- Unit tests only: miss emergent chains.

## Consequences

- Scenario tests assert EventLog chains.
- Determinism requirements shape the stimulus tick ([architecture](../tech/architecture.md)).
- See [testing](../tech/testing.md).
