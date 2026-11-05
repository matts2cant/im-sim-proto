# 12. Guard awareness: graded states, communication, alarm

Status: Accepted

Date: 2026-11-05

## Context

Binary seen/unseen AI is brittle and unreadable.

## Decision

Use graded awareness states (Unaware, Suspicious, Searching, Alerted/Combat) with guard-to-guard communication and a level-wide alarm.

## Alternatives considered

- Binary alert/not-alert.

## Consequences

- Needs pure transition logic with unit tests.
- See [perception and AI](../game/perception-and-ai.md).
