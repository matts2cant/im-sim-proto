# 69. Who perceives whom: hostile and ally tags

Status: Accepted

Date: 2026-11-06

## Context

A guard must watch for the player, ignore other guards' footsteps and be alerted only by attacks that matter. The systemic principle (AGENTS.md) forbids "is player" checks, and the player must not be special: whatever the guard reacts to must be a property any entity can have.

## Decision

- Allegiance is data in the perceiver's `PerceptionConfig`: `hostile_tags` (the guard's: `actor.player`), `ally_tags` (`actor.guard`) and `hidden_tags` (`state.cloaked`). Matching is hierarchical (`TagContainer`).
- **Sight** looks only for entities with a hostile tag and without a hidden one (ADR 0067).
- **Hearing** ignores noise whose source has an ally tag; all other noise counts (the player, thrown props, breaking crates, explosions), including entities with no tags.
- **Harm** alerts only when its source has a hostile tag (a bullet or baton from the player; not a crate thrown by physics or a barrel's blast, whose noise is investigated instead).
- The checks live in `PerceptionSensor.is_hostile()` / `is_ally()`; GradedAwareness applies them.

## Alternatives considered

- **Factions as a separate component** (a faction id and a relation table): more general, but nothing needs relations beyond hostile / ally yet; tags already exist and are saveable.
- **Checking the player group or class**: identity code; a decoy or a possessed guard could not take the player's place.

## Consequences

- A decoy entity tagged `actor.player` draws guards like the player; a disguise could remove the tag; a turned guard could swap `actor.guard` for a hostile tag.
- Another guard archetype (cameras, turrets, dogs) uses its own `PerceptionConfig`.
- Tests: `tests/actors/common/perception/perception_sensor_test.gd` (a non-player entity tagged `actor.player`), `tests/actors/guard/guard_test.gd` (ally noise, non-hostile harm).
