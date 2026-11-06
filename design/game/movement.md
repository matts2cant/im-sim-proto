# Movement

Milestone: M1 (Movement course).

## Purpose

First-person player controller whose movement modes feed the noise system.

## Player-facing behaviour

Walk, crouch, sprint, jump, mantle (ledges, crates), and vents (crouch-only paths). Lean and ladders are v1 (see [../backlog.md](../backlog.md)).

## Rules

All numbers live in `actors/player/player_config.tres`; movement noise in `actors/player/player_movement_noise.tres` (surfaces in `actors/common/movement/surface_table.tres`); the code holds none.

### Body and look

| Value | Number |
|---|---|
| Capsule radius | 0.35 m |
| Capsule height standing / crouched | 1.8 m / 0.95 m |
| Eye height standing / crouched | 1.65 m / 0.9 m, camera moves between them in 0.15 s |
| Max walkable slope | 45° |
| Mouse sensitivity | 0.0025 rad per pixel; pitch clamped to ±89° |

- The crouched capsule is 0.95 m so it passes 1.0 m vents with a 5 cm margin (a 1.0 m capsule in a 1.0 m vent jams).
- Crouch is held. Releasing it stands the player up only when a standing capsule fits (headroom check); otherwise the player stays crouched until there is room.
- Falling below y = -30 puts the player back at its spawn point (safety net for open doorways that lead nowhere yet).

### Speeds

| Mode | Speed (m/s) |
|---|---|
| Walk | 4.0 |
| Sprint | 6.0, only while the move input is within 50° of straight ahead and not crouched |
| Crouch | 2.0 |

- Ground acceleration 40 m/s², deceleration 50 m/s² (no input).
- Every ground speed is multiplied by the `move_speed_mult` attribute (injuries x0.6 per leg, Speed Enhancement x1.5: walk 6, sprint 9, crouch 3 m/s).
- Air control 0.3: in the air only 30% of ground acceleration steers, and without input momentum is kept. A jump keeps the speed cap of the mode it started from (a sprint jump stays at 6 m/s).
- Gravity is the engine default 9.8 m/s² times `gravity_scale` 2.0 = 19.6 m/s², for the player only ([ADR 0036](../decisions/0036-player-gravity-scale.md)). Jump apex 1.0 m; launch speed = sqrt(2 g h) = 6.26 m/s. Air time on flat ground 0.64 s, so a flat jump covers about 2.6 m from walk and 3.8 m from sprint (plus up to ~0.25 m capsule overhang at each edge).
- Steps ([ADR 0058](../decisions/0058-step-climbing.md)): walking (any speed) into an obstacle whose top is at most the step height (0.35 m, `actors/player/player_step.tres`, editable in the debug panel's Player tab) above the feet moves the player onto it, with no jump and no speed loss, when the top is walkable (≤ 45°) and the capsule fits there at its current height (standing 1.8 m or crouched 0.95 m). Only from the floor, not while jumping or mantling. Higher obstacles block: 0.35-1.0 m are jumped onto, 1.0-1.9 m mantled.
- Stairs and small drops: walking off a ledge of at most the step height (or down stairs) keeps the player on the floor: no air time, no landing noise, no fall damage. A deeper drop falls as before.
- The camera eases over a step's height change (about 0.1 s, `smooth_time`). Interaction, carry and weapon rays start from the eased camera, so they match the crosshair (at most 0.35 m off the real eye for under 0.1 s).
- Steps are the generic `StepClimber` component (any CharacterBody3D that moves with `move_and_slide()`, guards included); props that collide with a body in the solver are not stepped onto (the player is not in their mask, so it stands on props).

### Mantle

See [ADR 0035](../decisions/0035-mantle-rules.md).

- Triggered by pressing jump on the ground, or by holding jump in the air, when facing a ledge.
- The ledge top must be at least 1.0 m above the ground the player last stood on (grounded or in the air) and above the feet, and at most 1.9 m above both the feet and that ground (a jump neither extends the maximum nor lowers the minimum). The maximum is `PlayerConfig.mantle_max_height` through the `mantle_max_height` attribute: Speed Enhancement adds 0.6 (2.5 m), so a 2.3 m ledge is mantled from standing with it and refused without. Ledges below 1.0 m are jumped onto physically.
- The ledge face must be within 0.8 m of the capsule axis, measured horizontally.
- The player needs standing or crouched clearance for the whole move (rise, move over, end position). With only crouched clearance (a vent entrance) the mantle ends crouched.
- Duration 0.25 s + 0.15 s per metre of height. It is a scripted move (rise, then move over the edge), no physics during it.
- Not allowed while carrying a body or object (when carrying exists).

### Noise

Loudness unit = audible distance in metres ([ADR 0032](../decisions/0032-noise-loudness-audible-metres.md)).

- Footsteps fire by ground distance travelled, not by time:

| Mode | Stride | Base loudness |
|---|---|---|
| Walk | 2.0 m | 6 |
| Sprint | 2.6 m | 14 |
| Crouch | 1.2 m | 2 |

- Footstep loudness = base loudness x surface multiplier.
- The stance comes from the character's tags: `stance.crouch` (crouch wins), `stance.sprint`, else walk; the player sets them from its crouch state and movement mode, any other controller does the same ([ADR 0056](../decisions/0056-generic-character-components.md)).
- The surface comes from node metadata `surface` (StringName) on the collider the character stands on; default `concrete` ([ADR 0033](../decisions/0033-floor-surface-metadata.md)). For CSG the collider is the CSG root node with `use_collision`, so the metadata goes there.

| Surface | Multiplier |
|---|---|
| concrete | 1.0 |
| carpet | 0.5 |
| wood | 1.2 |
| metal | 1.6 |
| grass | 0.7 |

- Landing: on touchdown with a downward impact speed of at least 3 m/s, loudness = landing base (6) x clamp(impact speed / 5, 1, 4) x surface multiplier. The impact speed is rebuilt from the two ticks before the touchdown (`LandingTracker`). A 1 m jump lands at 6.3 m/s (loudness 7.5 on concrete), a 2 m drop at 8.9 m/s (10.6), a 5 m drop at 14.0 m/s (16.8).
- Each footstep and landing plays a Kenney impact sound for the surface (random variant, ±8% pitch around a per-surface base pitch: 1.0, except metal 0.8 with the impactPlate sounds); volume follows loudness (0 dB at 6, 10 dB per decade, clamped to -18..+6 dB).
- Events in the `EventLog` (source = the character's node name): `actor.footstep` {mode, surface, loudness}, `actor.landed` {impact_speed, surface, loudness}, `player.mantled` {height}.
- Footstep and landing noise is the generic `MovementNoise` component (`actors/common/movement/`, ADR 0056), a child of any CharacterBody3D: after the body moves each tick it reads the floor state, the horizontal speed and the stance tags. It emits `noise` stimuli (M2, [stimulus-response.md](stimulus-response.md)): RADIUS, PATH propagation, intensity = radius = loudness, origin at the feet, source = the character, next to the `actor.footstep` / `actor.landed` log entries. Guards hear them via path distance ([perception-and-ai.md](perception-and-ai.md)) and make them with the same component.

### Other

- Speed Enhancement augmentation: speeds x1.5, jump apex 1.0 → 1.6 m (`jump_apex_height` attribute, base `PlayerConfig.jump_apex_height`), mantle up to 2.5 m, landing loudness x1.5. Run Silent: footstep and landing loudness x0 (`footstep_noise_mult`, `landing_noise_mult` attributes read by `MovementNoise`; a noise scaled to 0 is not made: no log entry, stimulus or sound). See [abilities.md](abilities.md).
- Injuries (M4, [damage.md](damage.md)): every ground speed is multiplied by the `move_speed_mult` attribute (one leg at 0: x0.6); both legs at 0 (tag `state.legs_disabled`, from injuries or any effect) force a crawl: crouched, cannot stand, 1.0 m/s. Landing faster than 10 m/s hurts both legs ((speed - 10) x 8 each: 32 from a 5 m drop): `FallImpact` emits `damage.fall`, the `fall_damage` receptron hurts the legs ([damage.md](damage.md)).
- Knockback: `force.blast` / `force.impact` stimuli shove the player through the generic `Knockback` component (`actors/player/player_knockback.tres`): velocity change = impulse x 6 / 80 kg, horizontal part carried and damped (8 m/s² on the ground, 2 in the air, at most 8 m/s), upward part at most 3 m/s (feet rise at most 0.23 m). A barrel blast at 2 m shoves the player about a metre ([ADR 0056](../decisions/0056-generic-character-components.md)).
- Vents are paths only passable while crouched (1.0 m high).
- Physics props: the player stands on, jumps from and mantles onto them like level geometry, presses on what it stands on with its weight (80 kg, at most 4 x the prop's own weight) and pushes props it walks into (at most 250 N, up to 2 m/s); props do not collide with the player's body in the solver ([ADR 0054](../decisions/0054-player-and-physics-props.md), [objects-and-fire.md](objects-and-fire.md)).
- The player is saveable: position, yaw, pitch, crouched, velocity ([saving.md](saving.md)).
- The debug panel's Player tab shows speed, mode, grounded, height, crouched, surface and the last footstep and landing loudness, and edits the step height ([debug-panel.md](debug-panel.md)).

## Code

| Path | Role |
|---|---|
| `actors/player/player.gd`, `player.tscn` | CharacterBody3D adapter: input, physics, crouch, mantle execution, save/load |
| `actors/player/player_config.gd`, `.tres` | All tuning |
| `actors/player/player_motion.gd` | Pure: mode selection, speed caps, acceleration, jump speed, eye height |
| `actors/player/mantle_rules.gd` | Pure: mantle eligibility, duration, path |
| `actors/player/player_probe.gd` | Physics queries: headroom, ledge detection, mantle path clearance |
| `actors/common/pusher/push_rules.gd` | Pure: push impulse and weight share for physics props |
| `actors/common/pusher/body_pusher.gd`, `push_config.gd` | Component (any CharacterBody3D; the controller calls `after_move()` after `move_and_slide()`): props underfoot (weight) and walked into (push); the player's tuning in `actors/player/player_push.tres` (was `PlayerPusher` and `PlayerConfig` fields until M7) |
| `actors/common/movement/footstep_tracker.gd`, `landing_tracker.gd`, `movement_noise_rules.gd` | Pure: footstep distance, touchdown impact speed, loudness math |
| `actors/common/movement/surface_table.gd`, `.tres` | Surface multipliers and sounds, metadata lookup |
| `actors/common/movement/movement_noise.gd`, `movement_noise_config.gd` | Component (any CharacterBody3D): footsteps and landings, logs, `noise`, cue; the player's tuning in `actors/player/player_movement_noise.tres` |
| `actors/common/movement/fall_impact.gd` | Component (any CharacterBody3D): `damage.fall` on touchdown |
| `actors/common/knockback/` | Component, effect and receptron: shoves from `force.*` |
| `actors/common/movement/step_climber.gd`, `step_config.gd`, `step_rules.gd` | Component (any CharacterBody3D): walk up steps, down stairs; tuning (the player's in `actors/player/player_step.tres`); pure rules and view easing |
| `ui/debug_panel/tabs/player_tab.*` | Debug panel Player tab |

## Interactions

- Controls: [controls.md](controls.md)
- Movement course: [../levels/hub-and-gallery.md](../levels/hub-and-gallery.md)
- Roof route of the mission (stacked crates + mantle or Speed aug, then vent): [../levels/mission-warehouse.md](../levels/mission-warehouse.md)

## Open questions

- Holding jump in the air lets the player catch a ledge after falling short, which makes gaps more forgiving (the catch needs the ledge top at least 1.0 m above the last ground, so it cannot save a same-level gap; a sprint jump plus catch onto a ledge 1.0-1.9 m higher reaches about 4.6 m). Keep, limit to the falling phase, or shorten reach: decide after playtest.
- With Speed Enhancement a sprint jump covers about 7.3 m and a mid-air catch onto a higher ledge more: see the Augmented column in [metrics](../levels/metrics.md).
