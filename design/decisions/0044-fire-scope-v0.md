# 44. Fire scope in v0

Status: Accepted (user-approved)

Date: 2026-11-06

## Context

M3 adds fire. Fire in an immersive sim can grow without bound: burning characters, burning level geometry, extinguishing with water, spreading along floors. v0 needs a fire that is readable, testable and cheap, and that leaves damage and AI for M4 and M7.

## Decision

- **Characters do not catch fire.** They only receive `damage.fire` stimuli while in range of a fire (RADIUS, line of sight). Actual health arrives in M4; until then the player logs `player.hurt`.
- **Only dedicated objects burn**: objects with a `Flammable` component (wooden crates, cardboard boxes, wooden barricades). Kit parts and other level geometry never burn.
- **Burning objects can be carried.** The carrier receives `damage.fire` (CONTACT) on every fire pulse, on top of being in range.
- **No extinguishing in v0.** Fires burn out when their fuel runs out (permanent fires such as braziers never do). Water is parked ([backlog](../backlog.md)).

## Alternatives considered

- **Burning characters** (guards running around on fire): spectacular, but needs AI states, animation and damage-over-time rules that belong to M4/M7.
- **Flammable level geometry** (wooden floors, walls): needs per-surface fire state and navmesh/collision changes when it burns away; out of scope for a graybox kit.
- **Extinguishing** (water, fire extinguisher items): needs water, an item and a new stimulus; parked.

## Consequences

- Fire is entirely a property of objects: `Flammable` + the `heat_from_fire` receptron ([ADR 0046](0046-heat-accumulation-fire-model.md)).
- A carried burning crate is a deliberate risk/reward tool (carry fire to a barricade, take damage while doing so).
- Level designers place fire hazards with objects (braziers, crates), never by tagging geometry.
