# 90. Door size as data, a free side for any lock, and the warehouse's security population

Status: Accepted

Date: 2026-11-09

## Context

M9 wave 2 populates the warehouse ([mission-warehouse.md](../levels/mission-warehouse.md), layout [ADR 0089](0089-warehouse-layout.md)) with its doors, locks, keys and security devices. Three needs had no answer in M8 ([ADR 0078](0078-doors-locks-and-door-navigation.md)):

- The loading dock's roller doors (4 x 4 m), the 6 m vehicle gate and the 3 m-high back gate in the palisade fence are bigger than `door.tscn` (1.2 x 2.2 m, sliding 1.3 m into the wall).
- The back gate is picked from the river side but opens freely from inside (an exit handle); the same holds for the tunnel gate, the annex roof door and the office doors a player may come through by a duct.
- About 60 nodes (25 doors with their locks, 20 devices, cables, keys, datapads, desks) placed from the layout's coordinates, kept in step with the generated geometry.

## Decision

- **Door size is data.** `DoorSettings` gains `doorway` (width, height), `travel` (where the panel moves to open, in door-local metres: +X slides into the wall beside the doorway, +Y rises into the wall above), `panel_thickness` and `panel_offset` (a panel off the wall's middle plane: a gate sliding past its posts on one side of a fence). `Door._ready` sizes the panel (shape and mesh, copied first: the scene's are shared), the doorway's noise attenuator, its navigation carve and places the control panels from the settings. One scene fills every doorway; new sizes are new `.tres` files: `roller_door_settings.tres` (4 x 4 m, rises 4.1 m in 2.5 s, loud: noise 15), `vehicle_gate_settings.tres` (6 x 3 m, slides 6.2 m past the post outside the fence in 3 s), `fence_gate_settings.tres` (1.2 x 3 m). The weak wall is not a door: the people population closes it with a breach panel ([ADR 0091](0091-warehouse-population.md)). `slide_distance` is replaced by `travel`.
- **A free side for any lock.** `Lock.free_side` (none, FRONT = the entity's +Z side, BACK = its -Z side; pure rule `LockRules.on_free_side`). A user standing on that side opens the locked entity without the key: the Door says "E: open" and makes an authorised open (it stays locked, so it is locked again once closed; logged `door.opened_freely`), and `Lockable.grants_passage` lets a character there through (DoorOpener). Navigation links are not one-way, so guards without the key still do not plan through such a door.
- **The warehouse's security population is one generated scene**: `tools/level_gen/warehouse_security.py` writes `levels/mission/population/security.tscn` (instanced as `Population/Security` in `warehouse.tscn`) from `warehouse.py`'s doorway table and its own tables (doors and locks, devices, cables, keys, datapads, desks). Doors are named after their doorway markers; devices after their marker spot, so tests and M12 find them by name.
- **One security switch** in the basement store, on breaker B's circuit, carries every security device (cameras, turret, console, alarm controller, sirens, panic buttons, radio base station, the cabled doors): breaking or unpowering it cuts the cameras and panic buttons from the controller and the controller from the sirens. The office PCs hang on their own wall jack and the guest access point stands alone until M12's gateway joins the subnets.

## Alternatives considered

- **A roller door and a gate as separate scenes or scripts**: per-door code, against the systemic rule; a door's size and motion are tuning.
- **Scaling the door node**: scales the control panels, the navigation link and the noise attenuator with it, and a non-uniform scale on physics bodies is unsupported.
- **A free side as a separate "exit handle" lock**: every lock would then also need its own reason and prompt rules; an option on the base `Lock` keeps it one rule for all of them.
- **Free side = unlock**: a door opened from inside would stay unlocked for the next person outside; an authorised open keeps it locked once closed.
- **Hand-written population scene**: 600 lines of transforms to keep in step with the generated geometry by hand.

## Consequences

- Big doors need wall above (roller) or fence beside (gates) for their travel; the doorway-side checks are in `tests/objects/door/door_size_test.gd` and `tests/levels/mission/warehouse_doors_test.gd`.
- Doors in narrow corridors (1.5 m) have one control panel inside the cross wall; the door panel itself still takes E.
- The layout's geometry and traversal suites strip `Population` (they test the shell); the security population has its own suites (doors, key graph, network, navigation through doors).
- A guard post behind a keycard door needs a guard with the access tag (`access.warehouse_security` for the security operator); the reinforcements carry none, so a gate locked from the console keeps them out.
- M12 upgrades the hooks in place: `AccessPointGuest`, `OfficeWallJack`, `OfficePc1`, `OfficePc2`, `SecurityConsole`.
