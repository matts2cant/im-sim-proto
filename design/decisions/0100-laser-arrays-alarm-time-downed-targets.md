# 100. Laser arrays, a 45 s alarm, downed hostiles are no target

Status: Accepted (amends [ADR 0096](0096-laser-tripwires.md) and [ADR 0075](0075-alarms-as-network-devices.md))

Date: 2026-11-09

## Context

M9h playtest feedback on the security devices, with the user's decisions:

1. The network map has too many devices: every beam of ADR 0096 was its own device, so the gallery's pair was two nodes, each with its own Disable. Nearby beams should be one device.
2. The alarm rings too long (90 s since ADR 0072).
3. A turret set to target guards keeps aiming or firing at a guard who is down.
4. After a turret kills a guard a noise loops for as long as the body lies there. Reproduced in the gallery security wing exactly as the user did it (booth terminal: target guards, open the vault, the turret kills the post guard): in the 6 s after the kill the EventLog held 350 `turret.engaged`, 350 `turret.disengaged {reason: target_down}` and 351 turret noises, and the turret's `Sound` (its warning beep, an `AudioStreamPlayer3D`) was playing on every frame. The sirens also rang, as they should for the alarm's duration.

**Root cause of 3 and 4**: `PerceptionSensor.look()` returned any entity with a hostile tag, a dead or unconscious one too. The turret dropped its target as `target_down` (it checked `ActorState.can_act`), then on the same tick saw the body again as its best sighting, its meter still full, and engaged it again: `_engage()` restarted the 0.6 s beep and emitted the warning noise (10) every tick, so the beep never got past its first frame and sounded as a loop; the head stayed on the body and the laser stayed on. Guards' combat (`CombatBehaviour`) already refused to engage a target that cannot act and drops one that goes down, but their awareness still saw a downed hostile as a sighting, and a nearer downed hostile (higher gain) hid a standing one behind it from both turrets and guards.

## Decision

- **Laser arrays** (replace ADR 0096's single tripwire):
  - A laser array is one device feeding 1 to 4 beams (`LaserArrayConfig.max_beams`): one entity, one `Device`, one status, one Disable / Enable, one node on the network map. Grouping is authored: the beams are the entity's `LaserBeam` children, placed with the array; nothing groups beams by distance.
  - `LaserBeam` (`objects/laser/laser_beam.gd`, look in `laser_beam.tscn`: emitter head with lens, receiver, ray) is a Node3D: the beam runs from its origin (the head's wall face at the beam's height) along its +Z for its own `length`. Each beam keeps its own height and length.
  - Component `LaserArray` (`objects/laser/laser_array.gd`, renamed from `LaserTripwire`; tuning `LaserArrayConfig`, `laser_array.tres`) checks every beam each tick with ADR 0096's rules (shape query, carried ghosts, guards ignored unless downed). One `TripwireModel` for the array: any beam's break reports one incident at that beam's break point (EventLog `laser.tripped {laser, beam, by, point, controllers}`), and the array re-arms once every beam has been clear for 1 s. A body breaking two beams at once, or moving from one beam into another, is one incident.
  - One emitter feeds every beam: each beam's head and receiver box, and a mast joining the heads of a multi-beam array, are collision shapes of the array's one body (built as shape owners at load), so a shot at any of them breaks the array (health 20, one pistol round) and every beam goes dark, the lenses too.
  - `objects/laser/laser_tripwire.tscn` is replaced by `objects/laser/laser_array.tscn`, a one-beam array (`Beam1`); a level adds beams by instancing `laser_beam.tscn` under it. The origin convention is unchanged (the first beam's emitter face at its height), so the warehouse roof's beams kept their transforms; their length moved from `LaserBehaviour.beam_length` to `Beam1.length`.
  - Gallery: the laser hall's pair is one two-beam array `LaserPair` (0.4 m and 1.3 m, z 16.4); `LaserLow` and `LaserHigh` are one-beam arrays. Warehouse: `LaserRoofWest` and `LaserRoofEast` are one-beam arrays (about 40 m apart: two arrays).
- **Alarm time**: the alarm controller rings for 45 s (`alarm_controller.tres` `duration`), down from 90 s; a new incident still restarts it. Mission reinforcements still come 30 s after the first alarm (`MissionData.reinforcement_delay`, independent of the ringing time).
- **Downed hostiles are no target**: `PerceptionSensor.look()` skips any hostile that cannot act (`ActorState.can_act`: `state.unconscious` or `state.dead`, the tags perception treats as bodies). This holds for every sensor (turrets with any preset, cameras, guards) and every character. Bodies stay visible to `look_for_bodies()` (allies' bodies, ADR 0071). The turret's own `target_down` disengage stays as the in-tick check.

## Alternatives considered

- **Grouping beams automatically by distance**: the user asked for authored grouping; automatic grouping would merge beams that a designer meant as separate puzzles.
- **Separate devices sharing a power or status**: still one node per beam on the map, which is what the feedback was about.
- **Collision shapes as scene nodes per beam**: a `CollisionShape3D` must be a direct child of the body, so a beam scene could not carry its own; shape owners built from the beams at load keep a beam a single instanced node.
- **Fixing the loop in the turret only** (skip a sighting that cannot act, or rate-limit the beep): it would leave cameras and guards seeing bodies as hostiles and a downed hostile hiding a standing one; the rule belongs where sightings are made.
- **A `downed_tags` list on PerceptionConfig**: the turret's and the camera's configs have empty `body_tags` (they discover no bodies), so the list would have to be duplicated; `ActorState.can_act` is the one rule every system already uses for "down".

## Consequences

- Tests: `tests/objects/laser/laser_array_test.gd` (one beam, ADR 0096's checks), `laser_array_beams_test.gd` (three beams: one device, one status and command; any beam trips at its own point; one incident per crossing; re-arm only when all beams are clear; broken stops all; the shipped scene's heads, mast and receivers are one body; at most four beams), `laser_array_player_test.gd` (the real player, the two-beam array), `tests/scenarios/laser_alarm_test.gd` (a three-beam array on a network: one terminal row, one Disable darkens all beams), the gallery and warehouse placement tests; alarm: `tests/scenarios/alarm_devices_test.gd` (45 s); downed targets: `perception_sensor_test.gd`, `turret_test.gd`, and the regression `tests/levels/gallery/security_wing/security_wing_turret_kill_test.gd` (the user's steps; no engagement, no turret noise and the beep stopped after the kill).
- A guard or camera no longer keeps a downed player as a sighting (their meter decays as for anything out of sight).
- See [security](../game/security.md#laser-arrays).
