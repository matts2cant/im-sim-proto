# 39. Path propagation with SoundAttenuator areas

Status: Accepted

Date: 2026-11-06

## Context

[ADR 0027](0027-sound-propagation.md) chose navmesh path distance for noise. M2 has to define how the path is measured, what happens without a navmesh, and how closed doors (M8) make sound harder to hear.

## Decision

- PATH distance = |origin to its nearest navmesh point| + `NavigationServer3D.map_get_path` length (optimised path on the receiver's world navigation map) + |path end to receiver|.
- Attenuation: every enabled `SoundAttenuator` (an `Area3D` in group `sound_attenuator` with `extra_metres` and `enabled`) whose collision-shape volume one of the polyline's straight segments crosses adds its `extra_metres` once. The test is geometric (segment vs box/sphere, other shapes by bounding box), not a physics query. M8 doors toggle the attenuator in their doorway.
- No navmesh or no path: straight-line distance, still attenuated by attenuators on that line, and the reception is logged with `propagation: "straight_fallback"`.
- Receivers beyond the radius in a straight line are skipped before any path query.

## Alternatives considered

- **Navigation obstacles or link costs for doors**: doors would change where agents can walk, not only how far sound travels; and closed doors would make paths disappear instead of longer.
- **Physics ray/shape queries for attenuation**: need monitoring areas and a segment shape; the geometric test is deterministic and unit-testable.
- **Muffling factor (multiply intensity)**: a closed door would scale loud and quiet noises differently in metres; extra metres keep one unit.

## Consequences

- Levels need a baked navmesh for walls to block sound; without one, noise goes through walls (and the log says so).
- A receiver should sit close to the navmesh (or at head height above it); the vertical offset adds to the distance.
- One `map_get_path` per receiver within straight range per noise; fine for footsteps and a few guards, revisit if profiling says otherwise.
