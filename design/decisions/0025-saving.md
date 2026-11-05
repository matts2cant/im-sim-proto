# 25. Saving: saveable contract from M0, F5/F9 in M6

Status: Accepted

Date: 2026-11-05

## Context

Retrofitting save support into stateful systems is expensive.

## Decision

Every stateful node joins group saveable and implements save_state() -> Dictionary and load_state(data: Dictionary) -> void from M0. Quicksave F5 and quickload F9 land in M6.

## Alternatives considered

- Add saving late.

## Consequences

- Every feature carries a small saving cost.
- See [saving](../game/saving.md).
