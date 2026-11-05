# 33. Floor surface via collider metadata

Status: Accepted

Date: 2026-11-06

## Context

Footstep loudness and sound depend on the floor surface (concrete, carpet, wood, metal, grass). Levels are CSG graybox, which has no physics materials, and one CSG combiner produces a single collider.

## Decision

A floor declares its surface with node metadata `surface` (StringName) on the collider the player stands on. Missing metadata means `concrete`. The player reads it from a short downward ray under its feet (`RayCast3D.get_collider()`). For CSG the collider is the CSG root node with `use_collision` (verified by a test), so each surface needs its own CSG root. Multipliers and sounds per surface live in `actors/player/surface_table.tres`.

## Alternatives considered

- PhysicsMaterial on the body: CSG cannot carry one, and it is meant for friction and bounce.
- Collision layers per surface: uses up layers and mixes gameplay data with collision filtering.
- Groups: works, but a node could end up in several surface groups.

## Consequences

- Level authors must put surfaces on separate collider roots, not as children of a shared CSG combiner.
- Surfaces that touch at the same height make the reported surface ambiguous at the seam; the movement course raises its surface strips 2 cm.
- Physics objects (M3) can reuse the same lookup for impact noise.
- See [movement](../game/movement.md).
