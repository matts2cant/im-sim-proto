# 31. Agent workflow: chief engineer and sub-agents

Status: Accepted

Date: 2026-11-05

## Context

Keeping the main session's context lean and the code reviewed improves quality.

## Decision

The main session is the chief engineer: it designs, plans, briefs sub-agents, reviews diffs, runs tests and commits, but does not write game code directly. Sub-agents implement. Sonnet is used for simple or mechanical tasks, the stronger model for system code.

## Alternatives considered

- Main session writes all code.

## Consequences

- Briefs must be self-contained.
- See [CLAUDE.md](../../CLAUDE.md) and [AGENTS.md](../../AGENTS.md).
