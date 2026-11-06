# 45. Collision layers

Status: Accepted

Date: 2026-11-06

## Context

Until M2 everything sat on the default collision layer 1. M3 adds physics props, line-of-sight stimuli that walls must block but crates must not, a player who carries props, and debris. M4 adds hitboxes and M8 triggers. Queries (line of sight, pick-up ray, explosion impulse) need to pick what they hit by layer.

## Decision

Named in `project.godot` `[layer_names]`, constants in `core/physics_layers.gd` (`PhysicsLayers`):

| Layer | Name | What | Mask |
|---|---|---|---|
| 1 | world | Kit parts and all static level geometry, static props (wooden barricade, brazier) | (static) |
| 2 | player | The player's capsule | world, actors, objects |
| 3 | actors | Guards (M7) | |
| 4 | objects | Physics props (crates, barrels, bottles) | world, actors, objects (not player since [ADR 0053](0053-player-and-physics-props.md)) |
| 5 | hitboxes | Body-part hitboxes (M4) | |
| 6 | triggers | Trigger volumes (M8) | |

- `KitPart` sets `collision_layer = PhysicsLayers.WORLD` explicitly.
- LINE_OF_SIGHT stimuli are blocked by layer 1 only, so props never shield fire from each other while walls and barricades do.
- The pick-up and debug look rays use `LOOK_MASK` (world, actors, objects).
- **Debris** from broken objects is on no layer and collides with the world only: it is cosmetic and never blocks the player, who has no step-up ([ADR 0034](0034-ramps-not-stair-stepping.md)).
- A carried object and the player ignore each other through collision exceptions, not layers.

## Alternatives considered

- **Static props on layer 4** like the other objects: they would not block line of sight, so a barricade would let fire through and could not be "behind a wall"; and the navmesh bake (static colliders) would treat them differently from the level.
- **Debris on layer 4** (the M3 brief's first idea): pieces lying in a doorway stop the player, since there is no step-up; a burnt barricade would leave its doorway blocked by its own debris.

## Consequences

- Static props on the world layer are baked into the navmesh where it parses static colliders; a barricade that burns away leaves a stale navmesh until a re-bake (M7 decides when guards need that).
- New collision bodies must pick a layer from this table; tests use `PhysicsLayers` constants.
