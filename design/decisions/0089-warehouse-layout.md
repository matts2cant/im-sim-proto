# 89. Warehouse layout: generated area scenes, see-through palisade fence, Stairs kit part, floodlights, breaker B in the basement

Status: Accepted

Date: 2026-11-09

## Context

M9 wave 1 builds the warehouse mission's level ([ADR 0086](0086-warehouse-mission.md), layout in [mission-warehouse.md](../levels/mission-warehouse.md)): a night compound of about 100 x 80 m with four layers, many entries and loops, built from the graybox kit. Wave 2 populates it in parallel (guards, devices, doors, props), and the geometry will be adjusted after playtests. Some needs had no kit part: tall stairs (catwalks, fire escape, a 20 m water tower), a fence the player can see through, and outdoor floodlights.

## Decision

- **Generated area scenes**: `tools/level_gen/warehouse.py` (Python, with a minimal `.tscn` writer) writes `levels/mission/areas/{exterior,hall,underground,layout_markers}.tscn` from named constants (heights, stairs computed from the riser rules, ducts chained like `VentSegment.exit_transform()`). The scenes are not edited by hand; population lives in separate scenes instanced by `warehouse.tscn`, so the geometry can be regenerated without losing wave 2's work. `--root` writes `warehouse.tscn` once.
- **`Stairs` kit part** (`levels/kit/stairs.tscn`): a straight flight from `rise`, `width`, `tread`, `max_riser`; equal risers no higher than `max_riser` (at most 0.3 m, on the navmesh); `solid` or a steel flight open underneath. Warns below 1.2 m wide, under 0.25 m treads, over 40 degrees.
- **`Fence` kit part** (`levels/kit/fence.tscn`): vertical bars and rails as one triangle-mesh collision shape and one MultiMesh (not CSG), on the world layer and in `navigation_source`. Gaps (0.17 m in the palisade) stop every body while sight, shots and light pass between the bars. Used for the 3 m compound fence, catwalk and roof railings (bars every metre, rails at 0.5 and 1.0 m) and the stair cages. No new physics layer was needed.
- **Floodlights**: `objects/light_fixture/flood_lamp.tscn`, a SpotLight3D lamp composed from the existing lamp components (Breakable glass, `Powered`), aimed with its -Z.
- **Circuits**: `warehouse_yard` (breaker A: every outdoor lamp) and `warehouse_building` (breaker B: hall, offices, basement). Breaker A sits in the annex outside the hall and breaker B in the basement store (the design sketch had B in the security room): cutting the building's lights should be a choice made before reaching the guarded rooms, from the underground route.
- **Vertical openings**: climbs up through a hole (duct B into the manager office ceiling) rely on the mantle's highest probe ray (1.615 m above the feet): the hole's edge is 1.7 m above the stand spot and the slab around it at least 0.45 m thick. Skylights are one-way drops onto pallet goods; the way back up is the annex door and stair or the fire escape.
- **Ducts** use 1.2 m interiors and 25 degree slopes: 40 degree slopes pinch a crouched capsule at the kinks (found by the traversal tests).

## Alternatives considered

- **Hand-written `.tscn`**: about 3000 lines of coordinates kept consistent by hand; every change (a stair, a hole and its railings) touches several places. Rejected for the blockout.
- **A see-through layer for fences** (blocks bodies, not sight or shots): needs every character and prop mask changed; the bar fence gives the same play with no framework change.
- **A solid wall as the compound fence**: no scouting from the road, and guards could not see out; rejected.
- **Ramps instead of stairs**: read as ramps, not stairs, at 4.5-20 m.

## Consequences

- Level tests run the real level: route moves driven by `PlayerDriver` (climb and passage suites), navmesh reach, light levels per spot, sightlines, doorways, coplanar faces and kit warnings (`tests/levels/mission/`).
- Wave 2 must not edit the area scenes; it reads the placeholders in `LayoutMarkers` and the tables in mission-warehouse.md.
- The generator is Python, outside the engine: kit part rules (riser counts, vent exits) are mirrored in it and checked by the tests.
