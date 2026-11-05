# 9. Debug tooling from day one

Status: Accepted

Date: 2026-11-05

## Context

Systemic behaviour is hard to understand without visibility into it.

## Decision

Build a debug panel autoload from M0 with Overlays, Spawn, Time, Stats and Event Log tabs.

## Alternatives considered

- Add debug tools ad hoc when needed.

## Consequences

- Every system is inspectable and spawnable.
- One of the three autoloads is spent on it.
- See [debug panel](../game/debug-panel.md).
