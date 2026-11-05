# 34. Ramps instead of automatic stair stepping

Status: Accepted

Date: 2026-11-06

## Context

`CharacterBody3D` has no built-in step-up. Stair stepping needs extra shape casts every frame and is a common source of jitter and edge-case bugs, while the graybox levels can be built with any geometry.

## Decision

The player controller does not step up automatically. Height changes in levels are ramps of at most 45° (the controller's max floor angle) or ledges that are mantled ([ADR 0035](0035-mantle-rules.md)). Lips up to about 0.1 m are crossed by the rounded capsule bottom.

## Alternatives considered

- Automatic stair stepping via shape casts: more code, more per-frame physics queries, more feel bugs.
- Invisible ramp colliders over visual stairs: no visual stairs exist in graybox, so not needed yet.

## Consequences

- Level rule: no steps between 0.1 and 0.3 m (too high to walk over, too low to mantle). Use ramps.
- If art-pass stairs arrive later, they get invisible ramp colliders.
- See [movement](../game/movement.md).
