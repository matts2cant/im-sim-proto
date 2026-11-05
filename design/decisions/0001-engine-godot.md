# 1. Engine: Godot 4

Status: Accepted

Date: 2026-11-05

## Context

The prototype is iterated on heavily with AI agents. That favours text-based assets, headless runs and fast iteration.

## Decision

Use Godot 4.7.2 (standard build): text scenes and resources, headless runs and tests, fast iteration.

## Alternatives considered

- Unreal 5.8 / UE6: the official Unreal MCP (5.8, experimental) drives a live editor and assets stay binary; UE6 (Verse) is not expected before end 2027.
- Unity: not chosen; same iteration-speed concerns as Unreal for agent-driven work.

## Consequences

- Scenes and resources are diffable text.
- Tests and tooling run headless via the console build.
- No Unreal-class rendering features; acceptable for a graybox prototype.
