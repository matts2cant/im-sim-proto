# 91. Warehouse population: generated from the layout markers, crossing gaps measured by simulation, breach panel and gas cylinders, duct B hatch lip

Status: Accepted

Date: 2026-11-09

## Context

M9 wave 2 populates the warehouse ([ADR 0086](0086-warehouse-mission.md), layout [ADR 0089](0089-warehouse-layout.md), [mission-warehouse.md](../levels/mission-warehouse.md)): eight guards with posts and patrol routes, the equipment to find, the mission props (the prototype, the shipment, the weak wall's breach) and throwables. The layout doc set a target, "patrols leave crossing gaps of at least 4 s", that nothing measured. Another agent places doors, devices and keycards in parallel (`Population/Security`). The climb back up into duct B was a 1.7 m mantle caught only by the mantle's highest probe ray.

## Decision

- **Generated population scene**: `tools/level_gen/warehouse_people.py` writes `levels/mission/population/people.tscn` (instanced as `Population/People`) from the layout markers in `warehouse.py` (`POPULATION`): a guard stands on its `Guards` marker, a route runs through its `PatrolPoints` (waits as marker metadata), an item rests on (or on furniture under) its `Items` marker. Moving a guard or an item is a marker change and two regenerations, and the markers the navigation tests read stay true. Markers moved for play: G1 out of the booth wall to the booth door facing the gate lane (lit 0.76), G8 next to the store lamp (0.68; it read 0.49, on the knife-edge of the 0.5 threshold), the east patrol's last point beside the back gate (lit by its flood, 0.67), the gas cylinders' spot beside the weak wall.
- **Crossing gaps** are measured, not estimated: `warehouse_patrol_timing_test.gd` runs the level with its patrols for 92 s of game time (synchronous navigation, time factor 9, no player). A guard passes a crossing point (where a player route crosses a patrol path) while within 5 m (horizontal, same floor). A gap is the time between two passes; for a point passed by one guard only it is taken round that guard's measured lap. Every listed crossing must be passed and every gap must be at least 4 s. Guards holding a post are removed from that test (they cross nothing and only cost simulation time).
- **New objects are compositions** (no new code): `objects/gas_cylinder/` (Explosive with the barrel's tuning, 15 kg so it can be carried and thrown), `objects/breach_panel/` (a static wall patch with the reinforced material: only explosive damage breaks it, health 50; in `navigation_source`), and the `prototype` item (`items/prototype/`). Three gas cylinders 0.4 m apart stand 1.4-1.9 m from the panel's centre, so one explosion chains to the others and any one of them breaks the panel (65 damage at 1.4 m).
- **The shipment** is ordinary props (large and small crates, cardboard boxes, a fuel drum: an explosive barrel) whose `Tags.initial_tags` add `mission.shipment`; the SabotageObjective needs nothing else.
- **Lamps for posts**: a wall lamp on the north catwalk and a ceiling lamp over the bridge (building circuit) light the rifle guard's route points A and C (0.04 before); the posts G1, G5-G8 already read lit. Yard patrol points stay dark: the patrols cross the lit pools (side door, dock apron, east flood, back gate).
- **Duct B**: the filing cabinet is 1.6 m (the player ends crouched on it, 1.0 m under the ceiling) and a 0.35 m hatch lip hangs from the hole's north edge, so the mantle's middle ray (0.86 m above the feet) finds the edge and the climb into the duct is 1.45 m instead of 1.7 m.
- **Geometry tests see the layout only**: the layout, sightline, climb and passage suites free `Population` (`WarehouseHelpers.strip_population()`): guards stop the player and doors and the breach panel close doorways on purpose. The light and navigation suites keep it, so wave 2 cannot darken a hiding spot or cut a guard route unnoticed.

## Alternatives considered

- **A hand-edited population scene**: easy to tweak in the editor, but positions would drift from the markers and the tables in the doc. The generator keeps one source.
- **Estimating crossing gaps from path lengths and walk speed**: cheap, but misses turns, acceleration and waits; the simulation costs about 11 s of test time.
- **Explosive barrels for the breach**: they work, but gas cylinders read as "the thing next to the weak wall" and are light enough to carry elsewhere.
- **A taller cabinet without the lip** (top 6.24-6.55 m, caught by the 0.86 m ray): the player could only stand on it under the hole, and getting onto it from the floor would be a 1.75-2.05 m mantle.

## Consequences

- The weak wall's panel is placed by this scene; if the security scene also gets a door or panel there, one of them must go at the merge.
- Guards cannot path through the breach once it is open (the navmesh is baked at load).
- The measured laps (west 55 s, east 73 s, catwalk 87 s) and gaps are in the doc's guards table; retuning a route reruns the test.
