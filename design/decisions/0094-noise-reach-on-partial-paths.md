# 94. Noise reach on partial navmesh paths; investigation arrival needs height too

Status: Accepted

Date: 2026-11-09

## Context

Playtest of the warehouse: entering the manager office by duct B (the ghost route) made G5, G6 and G7 Suspicious the moment the player dropped onto the filing cabinet, and G7, who then looked around right outside the office door, was Alerted when the player opened it. The landing (1.45 m onto metal, loudness 13.8) was heard through solid walls:

- PATH stimuli (noise, shouts, sirens; [ADR 0039](0039-path-propagation-sound-attenuators.md)) measure origin -> nearest navmesh point -> `map_get_path` -> receiver. The cabinet top bakes into a small navmesh island no path leaves. `map_get_path` then returns a path that stops at the island's point nearest the receiver, and the old code bridged the rest in a straight line: through the office wall to G7 (6.2 m instead of 9.0 m plus the closed door's 6 m) and through the floor slab to G6 in the break room below (6.7 m instead of about 77 m). The doc listed this tail as an open question.
- G6, sent to investigate a point 6 m above him, counted as arrived where he stood: `NavWalker` arrival only looked at the horizontal distance (0.45 m), so he looked around in the break room instead of walking the navmesh path.

## Decision

- **Gaps are bridged only through open air.** A PATH polyline is origin, navmesh path, receiver. A gap at either end (origin to the path's first point, the path's last point to the receiver) longer than `PATH_GAP_FREE` (0.6 m: a point beside its polygon, the bake's agent radius and height offset) counts only when a ray between its ends, lifted `PATH_GAP_LIFT` (0.25 m) off the surfaces they rest on and trimmed `PATH_GAP_SKIN` (0.1 m) at each end (a bullet's impact on a wall is not blocked by that wall), hits no world geometry (layer 1, as fire's line of sight), straight or round one corner (level first or vertical first: over a cabinet's edge, off a table top).
- **Otherwise the way is searched backwards**: a path from the receiver to the origin, whose open end is then at the source (from the office floor up to the cabinet top). The same gap rule applies.
- **Both blocked: not heard** (no delivery). There is no per-wall penalty: a noise either finds an open way or does not arrive. This keeps the rule to one ray test per long gap and one extra path query only for partial paths.
- The rule is about geometry only: no special case for furniture, islands or a level.
- **Arrival needs height too.** `NavWalker` arrives within `arrive_distance` (0.4 m) horizontally **and** `arrive_height` (1 m, new in `NavWalkerConfig`) vertically of its target, or of the closest point its navmesh path reaches. A target a storey above or below is reached by walking the path. Without a navmesh (walking straight) it still stops right under or over the target: as close as it gets.

## Consequences

- Duct B's careful entry is heard by no guard outside the office (G7: margin -2.3 m); with Speed Enhancement on (landings x1.5) G7 hears it (margin 4.6) and investigates. `tests/levels/mission/warehouse_duct_b_entry_test.gd`.
- Noise from places no path leaves and no open air connects (inside a sealed duct over a room, a closed cupboard) is heard by nobody; it used to leak through walls. Crawling in a duct above a room can be silent below it now.
- A suspicious guard whose investigation point is on another floor walks the navmesh path towards it (as close as the path gets) instead of looking around under it.
- Tests: `tests/core/stimulus/path_partial_test.gd` (an island next to a wall: nothing behind a solid wall, the doorway route with a doorway, open air in the same room, an impact on a wall face), `tests/actors/common/movement/nav_walker_arrival_test.gd`.
