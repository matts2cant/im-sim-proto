# 97. Warehouse roof security: high beams at the two roof arrivals, a camera over duct B's lit forecourt, on the yard network

Status: Accepted

Date: 2026-11-09

## Context

M9g playtest: "I was able to rush directly to the roof jumping on crates and drop into the office, grab the doc, then rush to the boat, all in 1:30." The roof was the level's safe layer (M9e review: "no guard, no camera"): the fastest way to the manifest, over the north-west fence, up the annex chain's pallets, container and crate and the annex stair, then straight across the roof into duct B, met no resistance. The user asked for laser tripwires ([ADR 0096](0096-laser-tripwires.md)) and a roof camera or patrol. Constraints: the careful player must still get through both ghost routes (fence, culvert) with Ghost and Pacifist, at least one route needs no augmentation and no tools, each roof obstacle has at least two answers, duct B stays the showcase ghost way to the manifest, and the roof's devices use the existing networks. No new device type and no change to perception, darkness or noise.

## Decision

### Layout

```text
 roof x -20..20, z -10..15 (top 9.5); north up
 z -10    ======== north parapet ==================================== M: mast x 17 (camera C 2.8 m up, lamp L on top)
 z -9..-6.6            SkylightEast x 6.2..8.6     F F F F   F: lit forecourt x 9.5..12.5, z -10..-6
 z -5.8                                              [mouth]  duct B, x 10.2..11.8, runs south under the roof by z -1.6
 z -4.5                                     w (9.4, -3)  |housing|  e (14.5, -4.5)       B2 | fire escape landing
 z -3.9                                                                     (18.5, -3.9) ...B2 gap z -4.52..-3.32, x 20..20.5
 z  0.5   (-16.5, 0.5) ---------------- route ------------- (8, 0.5)
 z  3.0   annex stair landing | B1 gap z 2.37..3.57, x -20.5..-20
```

w, e: dark waits beside the duct's housing. B1, B2: the high beams.

- **B1, B2: high laser beams** (1.3 m above the roof) across the two parapet gaps where the annex stair (west, z 2.37..3.57) and the fire escape (east, z -4.52..-3.32) arrive on the roof. The parapet is only 1.0 m, so the gaps' ends rise into 1.6 m posts (`Hall/Roof/Parapet` `PostWestN` ...); each beam runs post face to post face (1.2 m, origin on the north post's south face, +Z across). Crouched (0.95 m) the player passes 0.35 m under it; a jump (apex 1.0 m) cannot clear it. Not a low beam: a gap is entered from a stair landing at right angles, so a walking take-off 0.64-1.92 m before the beam would need a run-up the 1.3-1.4 m landings do not have (a standing jump leaves a 0.5 m window: a precise jump, against the level's targets). Not a pair: both ghost routes use both arrivals.
- **C: a roof camera** on a 3.4 m steel mast (M) in the roof's north-east corner (x 17, against the north parapet), 2.8 m up, rest yaw -20 degrees (south-south-west); **L: a flood lamp** on the mast's top (energy 5, range 10 m, half-angle 20 degrees) aimed at **duct B's forecourt** (F, north of the mouth at x 11, z -5.8). The forecourt reads 0.6-0.9 standing; the waits beside the duct's housing (w (9.4, -3.0), e (14.5, -4.5)) and both arrivals stay at 0.04 (`warehouse_roof_security_test.gd`, the light test's markers `RoofDuctB`, `RoofDuctBWest`, `RoofDuctBEast`). The lamp's range stops short of the hall below the skylights. Cameras have no dark floor ([ADR 0095](0095-darkness-and-flashlights.md)): outside the pool the camera sees nothing.
- **The sweep leaves a window.** The forecourt lies 38-55 degrees right of the camera's rest yaw, so it is in focus only near the sweep's west end: each forecourt spot is in focus 3.3-4.9 s of the 14.7 s cycle, and none is for 8.5 s in a row (measured). A careful player waits in the dark beside the housing, goes when the camera turns east past its rest yaw, and is in the duct within 3 s; coming back out, the player waits inside the mouth's drop (out of the camera's line through the mouth) for the same moment.
- **A second watcher, found by the tests:** the lit forecourt is in sight of the north catwalk's guard G4 up through the roof's east skylight (x 6.2..8.6, z -9..-6.6) while G4 walks east along the catwalk's west half (x -10 to 1, about 6 s of its 52 s lap): a player lit at 0.66 in the forecourt was seen from 15 m (Suspicious). Kept as design: the light that makes the camera work also shows the player to the hall below; the player can look down through the skylight to see G4 (lit by the catwalk lamps). The ghost routes wait for both (`warehouse_route_roof.gd`).

### Network: the yard's

All three devices are cabled to the yard switch (gate booth, breaker A), and the beams and the lamp are on the yard circuit (`warehouse_yard`); the camera, like the level's other cameras, is on no circuit. The roof is outside and reached from outside: its breaker sits at the foot of the annex chain (the annex, breaker A: in through the high window from two stacked crates, M9f), so cutting the roof's power is an option on the way up rather than a basement detour (breaker B is in the store, on the underground way, and by then the offices are reached by the service stair). Cutting A switches the beams off (no beam, no check) and the lamp off (the camera is blind in the dark), darkens the yard's pools and cuts the camera from every controller; breaking the yard switch (one pistol round through the booth's window: noise at G1's post) leaves the beams and the camera working but reporting to nobody. The console reaches them through the uplink and disables them. The network tab shows Camera Roof, Laser Roof West and Laser Roof East with their status lines, apart from the other labels (checked by `warehouse_security_network_test.gd` and the `terminal_network` shot).

### Camera, not a patrol

A camera: a guard on the roof would need its own route, a way up (guards cannot mantle the annex chain or the fire escape's bottom landing; the roof is a navmesh island), patrol-timing tests and a reaction when it sees the player that ripples through the radio to the whole compound; a fixed camera with a learnable sweep gives the same "the roof is watched" with one lit area, fits the network theme (its power and its switch are answers), and costs one condition in the route tests.

### Answers

| Obstacle | Answers (no tools first) |
|---|---|
| B1, B2 (high beams) | Crouch under (no tools, tested); the other arrival or duct A from the north catwalk (another way round); breaker A (no tools: the annex window, tested); the console (disable); shoot an emitter (one pistol round, noise); break the yard switch (the beam still beeps but rings nothing). Speed Enhancement's 1.6 m jump apex may clear it (untested) |
| C over the lit forecourt | Timing: the sweep's 8.5 s window, and G4 walking west (no tools, tested); breaker A (lamp off, camera blind and cut off: tested); the console (disable); shoot the camera or the lamp (noise); break the yard switch |

### The rush is caught

`warehouse_route_rush_test.gd` replays it: sprint from PlayerSpawn over the north-west fence, down the west strip, up the annex chain (fastest crate climb to the roof: the fire escape is reached only across the whole yard or through the culvert) and the annex stair, upright through B1 and across the roof into duct B. B1 trips at 15 s (roof reached) and reports to both controllers: the alarm rings; the player is in duct B at 23 s. The camera did not see this sprint (it crossed the lit forecourt in about a second): the beam is the reliable catch, the camera the second layer for a player who comes up the fire escape or crouches under a beam and then walks into the light.

## Alternatives considered

- **A low beam at a gap** (jump over): needs a run-up the stair landings do not have (see above).
- **Beams around duct B's mouth**: the forecourt is open on two sides and has nothing to mount on; posts across it would read as arbitrary; at the arrivals the parapet's gap is a natural doorway.
- **The building network (breaker B, the store's switch)**: the roof belongs to the building, but the cut would sit on the underground way, where the offices are already open by the service stair; the yard network puts the roof's off switch on the roof's own approach.
- **The roof lamp on no circuit and the camera on the yard circuit**: cutting A would leave the forecourt lit with a dead camera; with the lamp on A, the darkness itself blinds the camera (the systems already in place), and the camera keeps the convention of the level's other cameras.
- **A roof patrol**: see above.

## Consequences

- The roof is no longer free: a ghost run crouches through each arrival and times the forecourt (camera and G4), which can cost up to a sweep cycle or a G4 lap of waiting each way.
- Breaker A gains a second purpose (the roof's power) beside the yard's lights and alarms.
- Tests: `warehouse_roof_security_test.gd` (beams post to post with no world geometry across them and 1.3 m over the gap floor; forecourt lit, waits dark; the sweep watches the forecourt with an 8.5 s window; a lit intruder and an upright body ring both controllers, a crouched one passes; breaker A and the console switch it off), `warehouse_route_rush_test.gd`, `warehouse_route_roof_power_test.gd` (breaker A cut from inside the annex, the roof walked upright: no trip, no detection, no alarm), the ghost routes (fence, culvert, vault) crouch and wait and assert that no guard rose above Unaware on the roof stretches.
- Cost: physics process about +0.1-0.25 ms per frame on the roof (5.2 to 5.5 ms), within the noise elsewhere; render within the noise (one more shadowed spot light).
- See [mission-warehouse.md](../levels/mission-warehouse.md#roof-security-m9g), [security.md](../game/security.md#laser-arrays).
