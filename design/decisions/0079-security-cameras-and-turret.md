# 79. Security cameras and the turret

Status: Accepted

Date: 2026-11-08

## Context

M8 needs cameras and a turret on the device network of [ADR 0077](0077-devices-cables-and-remote-commands.md). The systemic rules (AGENTS.md) ask that they see through the same perception rules as guards ([ADR 0067](0067-vision-and-detection.md)), choose targets by tags ([ADR 0069](0069-hostile-and-ally-tags.md)), shoot through the same weapon path as everyone ([ADR 0070](0070-guard-combat-and-loadouts.md)), and take remote commands as stimuli. Cloak must not hide the player from them.

## Decision

- **Shared detection meter** (`SightMeter`, pure, `objects/devices/sight_meter.gd`): a watching device's suspicion rises by the PerceptionSensor sighting's gain per second and falls by `decay` (0.25/s) while nothing is seen. At 1.0 it detects once; it cannot detect again until no target has been seen for `cooldown` (10 s). Cameras and turrets both use it; it is not tied to either.
- **Vision**: each device has a `PerceptionSensor` on its turning head (an `Eye` node, eye height 0, in front of its own collision so nothing of it blocks the rays) with its own `PerceptionConfig`. Light, distance falloff, stance, line of sight and the "2 m: at least half light" rule are the guards'. Neither has hidden tags (Cloak is only in the guards' `hidden_tags`), peripheral cones, or a wary factor.
- **Camera** (`objects/camera/security_camera.tscn`, `SecurityCamera`, `security_camera.tres`, `security_camera_perception.tres`): wall or ceiling mount (origin on the face, +Z out; mounted about 2.6 m up). Hostile `actor.player`; focus ±25° to 15 m; base gain 0.8 (lit at 4 m: 1.25 s; 6 m: 1.3 s; dim, L 0.25, at 4 m: 3.3 s; dark: never). Sweep (`CameraModel`, pure) ±40° around the rest yaw at 15°/s with 2 s holds at each end; **while it sees a target the sweep waits**, so it keeps a target in view (a target the sweep would leave after a moment could never be detected in dim light). Status lamp: green, amber above 0.3, red while detected; off while blind. On detection: `Device.report_incident(target position)`, a beep (noise 8), EventLog `camera.detected {camera, target, point, controllers}`. Health 20 of a new `material.electronics` profile (`objects/materials/electronics.tres`: blunt ×4, fire and stun ×0): one pistol round (25), one baton hit (5 blunt ×4) or an explosion breaks it.
- **Camera commands** (new constants on `Device`, receptrons in `objects/devices/receptrons/`): `command.disable` / `command.enable` (blind, lamp off), `command.stop_sweep`, `command.resume_sweep`, `command.pan_left`, `command.pan_right` (15° steps, clamped to ±40°; a pan step stops the sweep, resume carries on from where it points). Unpowered or broken: blind, lamp off, the sweep stops.
- **Turret** (`objects/turret/turret.tscn`, `Turret`, `turret.tres`, `turret_perception.tres`, weapon `turret_gun.tres`, aim `turret_aim.tres`): floor-standing (origin on the floor, +Z forward), head 1.15 m up. Focus ±60° to 15 m, base gain 2.0, no hidden tags. It turns toward what it sees (120°/s) and back to rest when idle. On a full meter: `report_incident(target position)` (with the same 10 s cooldown), then `TurretModel` (pure) winds up 1.0 s (warning beep noise 10 and a red laser to the first thing on its line) and fires bursts of 1.5 s with 0.75 s pauses through `WeaponHolder.trigger()` (one shot per 0.25 s cycle). It stops 1 s after losing sight. Spread `3° + 0.1° per metre beyond 4 m` as the holder's cone floor (`TurretModel.spread_deg`); no bloom, no sway. **Line of fire** is the guards' `CombatBehaviour.line_of_fire_clear()` over the target's aim points (hitboxes torso, head, limbs): it never fires while the first thing on every line is not the target. Health 60 of metal (three pistol rounds; batons barely scratch it; explosives).
- **Target presets are data**: `TurretConfig.presets` maps a command type to the hostile tags it sets (`command.target_intruders` -> `actor.player`, `command.target_guards` -> `actor.guard`, `command.target_everyone` -> both); one receptron per preset type. The turret copies its sensor's config at load so presets are per turret. Retargeted at guards it shoots guards through the same damage path and ignores the player.
- **Turret damage 15 a hit** (the brief proposed 8): measured by `tests/objects/turret/turret_test.gd` on the real player (hitboxes, body profile: dead at torso 100 or head 60 lost), lit, standing at 6 m, from stepping into view: 8 a hit took 6.2-8.5 s (mean 7.1 s), outside the 3-5 s aim; 15 takes 3.7-4.2 s (mean 4.0 s: 0.5 s to detect, 1 s wind-up, about 2.5 s under fire).
- EventLog: `turret.detected {turret, target, point, controllers}`, `turret.engaged {turret, target}`, `turret.disengaged {turret, reason}` (lost, disabled, unpowered, broken, retargeted, target_down, loaded), `turret.retargeted {turret, preset, tags}`; shots as `weapon.fired`.
- Saveable: camera (disabled, sweep, meter), turret (disabled, preset, meter; an engagement is transient like the guards').

## Alternatives considered

- **Reusing the guard's awareness model**: its states (suspicious, searching, wary) mean nothing to a device; the meter with a report cooldown is all a camera needs.
- **A camera that keeps sweeping while it sees you**: at 15°/s a 50° cone passes a still target in 3.3 s, so a dim target (3.3 s to detect) would almost never be seen and the lamp would flicker amber; holding on a target is readable (the lamp goes amber, the camera stops).
- **One hierarchical `command.target` receptron** with `command.target.<preset>` types: fewer files, but every turret would then "accept" every preset name, and the terminal would offer buttons that do nothing.
- **Turret accuracy as a hit roll**: the cone keeps misses real (they hit walls, make noise) and the same code as everyone's.

## Consequences

- Any entity with a Device, a turning node carrying a PerceptionSensor and a `SecurityCamera` (or a `WeaponHolder` and a `Turret`) behaves as a camera (or turret): tested on a minimal entity built in code (`tests/objects/camera/security_camera_test.gd`).
- Level builders place cameras on walls at about 2.6 m and need lamps where cameras should see (they obey light like guards); a camera cut off from its controller still detects but tells nobody.
- Cloak is no protection from devices; darkness, cover and breaking or disabling them are.
- Tests: `tests/objects/devices/sight_meter_test.gd`, `tests/objects/camera/camera_model_test.gd`, `security_camera_test.gd`, `tests/scenarios/security_camera_test.gd`, `tests/objects/turret/turret_model_test.gd`, `turret_test.gd` (showcase `tests/objects/fixtures/showcase/security_showcase.tscn`).
- See [security](../game/security.md).
