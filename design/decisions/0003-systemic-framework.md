# 3. Systemic framework: own Act/React stimulus framework

Status: Accepted

Date: 2026-11-05

## Context

Emergent gameplay needs a general way for world events to cause reactions. Deus Ex style abilities also need attributes and modifiers.

## Decision

Build an own Dark Engine style Act/React stimulus framework (stimuli, receptrons, effects) including attributes, modifiers and tags so a Deus Ex ability system fits later.

## Alternatives considered

- Forge: GAS-like, C#-only, v0.4, ability-centric. Reconsidered only if moving to C#.

## Consequences

- Full control over propagation, determinism and the EventLog.
- More code to build and test in M2.
- Progression can later be expressed as modifiers.
