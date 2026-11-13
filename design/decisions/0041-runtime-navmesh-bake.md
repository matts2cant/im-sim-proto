# 41. Runtime navmesh bake on level load

Status: Accepted

Date: 2026-11-06

## Context

Guards (M7) need a navigation mesh. Levels are built from parametric kit parts that the user keeps editing in the editor ([ADR 0037](0037-graybox-kit.md)); a navmesh baked in the editor and saved with the scene goes stale whenever someone moves a part and forgets to re-bake. CSG builds its own mesh and collision deferred (a frame after entering the tree), so the engine's default source parsing sees nothing at `_ready`.

## Decision

- Each level has one `LevelNavigation` node (a NavigationRegion3D script, `levels/kit/level_navigation.gd`) as its last child. It bakes the navmesh in `_ready`, on the main thread, with `NavigationServer3D.bake_from_source_geometry_data`; nothing is saved in the scene.
- Source geometry: the collision faces of every CSG root with `use_collision` under the level root, computed from an out-of-tree copy of each root (CSG's in-tree bake is empty right after loading and stale right after an edit), plus static colliders of nodes in group `navigation_source`.
- Agent: radius 0.35 m, height 1.8 m (the standing player), max slope 45°. Cells 5 cm (a divisor of the radius; the navigation map's cell size is set to match). Vents and crawl spaces (< 1.8 m) drop out by agent height alone.
- Max climb is one cell (0.05 m), not 0: with 0, Recast treats every voxel row of a ramp as a step and ramps disconnect. Steps of 10 cm or more stay unclimbable, matching the player's "no step-up" rule ([metrics](../levels/metrics.md)).

## Alternatives considered

- **Bake in the editor, save the navmesh resource**: no load cost, but stale navmeshes after edits and large diffs in the scene files.
- **Asynchronous bake**: no hitch, but guards would spawn before their navmesh exists; levels are small (the hub plus movement course bakes in about 0.3 s).
- **Max climb 0** (as first briefed): breaks every ramp; one cell is the smallest value that keeps 45° slopes walkable.

## Consequences

- Level load includes the bake (about 0.3 s for the hub and movement course at 5 cm cells); revisit cell size if the warehouse mission gets slow.
- Code that changes geometry at runtime (breakable walls, doors) calls `LevelNavigation.bake()` again or uses navigation obstacles.
- Roofs of rooms and tops of ducts are on the navmesh as unreachable islands; harmless for path queries between reachable points.

## Amendment (2026-11-13, ADR 0132)

The hub bake grew to about 1 s (Recast) with the gallery rooms. `LevelNavigation` keeps its last 4 bakes per exact source geometry and bake settings for the running process, so a level loaded again with the same geometry (level reset, quickload, the hub after a mission) reuses its navmesh; different geometry bakes anew. See [ADR 0132](0132-test-suite-speed-pass.md).
