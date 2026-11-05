# Movement

Milestone: M1 (Movement course).

## Purpose

First-person player controller whose movement modes feed the noise system.

## Player-facing behaviour

Walk, crouch, sprint, jump, mantle (ledges, crates), and vents (crouch-only paths). Lean and ladders are v1 (see [../backlog.md](../backlog.md)).

## Rules

All numbers live in `actors/player/player_config.tres` (surfaces in `actors/player/surface_table.tres`); the code holds none.

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
- Air control 0.3: in the air only 30% of ground acceleration steers, and without input momentum is kept. A jump keeps the speed cap of the mode it started from (a sprint jump stays at 6 m/s).
- Jump apex 1.0 m; launch speed = sqrt(2 g h) = 4.43 m/s with the project default gravity 9.8 m/s². Air time on flat ground 0.90 s, so a flat jump covers about 3.6 m from walk and 5.4 m from sprint (plus up to ~0.25 m capsule overhang at each edge).
- No automatic stair stepping: levels use ramps of at most 45° ([ADR 0034](../decisions/0034-ramps-not-stair-stepping.md)). Lips up to ~0.1 m are climbed by the rounded capsule bottom; anything higher is a mantle.

### Mantle

See [ADR 0035](../decisions/0035-mantle-rules.md).

- Triggered by pressing jump on the ground, or by holding jump in the air, when facing a ledge.
- The ledge top must be 0.3 to 1.9 m above the feet and at most 1.9 m above the ground the player last stood on (a jump does not extend mantle reach; the Speed augmentation will raise the limit).
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
- The surface comes from node metadata `surface` (StringName) on the collider the player stands on; default `concrete` ([ADR 0033](../decisions/0033-floor-surface-metadata.md)). For CSG the collider is the CSG root node with `use_collision`, so the metadata goes there.

| Surface | Multiplier |
|---|---|
| concrete | 1.0 |
| carpet | 0.5 |
| wood | 1.2 |
| metal | 1.6 |
| grass | 0.7 |

- Landing: on touchdown with a downward impact speed of at least 3 m/s, loudness = walk base x clamp(impact speed / 5, 1, 4) x surface multiplier. A 1 m jump lands at 4.4 m/s (loudness 6 on concrete), a 2 m drop at 6.3 m/s (7.5), a 5 m drop at 9.9 m/s (11.9).
- Each footstep and landing plays a Kenney impact sound for the surface (random variant, ±8% pitch); volume follows loudness (0 dB at 6, 10 dB per decade, clamped to -18..+6 dB).
- Events in the `EventLog` (source = player node name): `player.footstep` {mode, surface, loudness}, `player.landed` {impact_speed, surface, loudness}, `player.mantled` {height}.
- M2 turns footsteps and landings into `noise` stimuli ([stimulus-response.md](stimulus-response.md)); the single emit point is `PlayerNoise._make_noise()` in `actors/player/player_noise.gd`. Guards hear them via path distance ([perception-and-ai.md](perception-and-ai.md)).

### Other

- Speed Enhancement augmentation: faster, higher jump/mantle, louder landings. Run Silent: footstep noise x0. See [abilities.md](abilities.md).
- Leg damage: one leg at 0 = slow, both = crawl. See [damage.md](damage.md).
- Vents are paths only passable while crouched (1.0 m high).
- The player is saveable: position, yaw, pitch, crouched, velocity ([saving.md](saving.md)).
- The debug panel's Player tab shows speed, mode, grounded, crouched, surface and the last footstep and landing loudness ([debug-panel.md](debug-panel.md)).

## Code

| Path | Role |
|---|---|
| `actors/player/player.gd`, `player.tscn` | CharacterBody3D adapter: input, physics, crouch, mantle execution, save/load |
| `actors/player/player_config.gd`, `.tres` | All tuning |
| `actors/player/player_motion.gd` | Pure: mode selection, speed caps, acceleration, jump speed, eye height |
| `actors/player/mantle_rules.gd` | Pure: mantle eligibility, duration, path |
| `actors/player/player_probe.gd` | Physics queries: headroom, ledge detection, mantle path clearance |
| `actors/player/footstep_tracker.gd`, `player_noise_rules.gd` | Pure: footstep distance, loudness math |
| `actors/player/surface_table.gd`, `.tres` | Surface multipliers and sounds, metadata lookup |
| `actors/player/player_noise.gd` | Component: logs noise events and plays the cue |
| `ui/debug_panel/tabs/player_tab.*` | Debug panel Player tab |

## Interactions

- Controls: [controls.md](controls.md)
- Movement course: [../levels/hub-and-gallery.md](../levels/hub-and-gallery.md)
- Roof route of the mission (stacked crates + mantle or Speed aug, then vent): [../levels/mission-warehouse.md](../levels/mission-warehouse.md)

## Open questions

- Holding jump in the air lets the player catch a ledge after falling short, which makes gaps more forgiving (a sprint jump plus catch reaches roughly 8 m). Keep, limit to the falling phase, or shorten reach: decide after playtest.
- Leg damage speeds: TBD in M4. Speed augmentation values: TBD in M6.
