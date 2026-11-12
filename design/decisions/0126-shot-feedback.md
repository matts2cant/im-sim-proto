# 126. Shot feedback: hit markers, impacts by material, tracers (M13b)

Status: Accepted (builds part of [ADR 0120](0120-weapon-feel.md))

Date: 2026-11-12

## Context

ADR 0120 asks M13b for hit markers on the crosshair (subtle, distinct for a headshot and a kill, no damage numbers), impacts by material group (holes and puffs, capped and fading), a dark-red puff on body hits, a blue-white spark on stun hits, and tracers on the automatic weapons and guards' shots. The systemic rule holds: the player is not special, materials are data on surfaces, the HUD does not get called by weapon code.

## Decision

- **Hit markers come from the EventLog.** `HitMarkerRules` (pure) remembers the ids of the watched shooter's `damage.*` stimuli from `stimulus.emitted` (source = the player's node name, the attribution MissionTally already uses) and turns `actor.damaged` (`part` head: HEAD, else BODY), `actor.stunned` (STUN), `actor.knocked_out` (KNOCKOUT) and `actor.died` (KILL) whose `by` is one of them into a marker; nothing on the shooter itself or from anyone else's stimuli. Only direct hits: a barrel's blast or a fire the player started gives no marker. `HitMarker` (a HUD control over the reticle) draws four diagonal ticks (white body, yellow head, pale blue stun) or an X (red kill, pale blue knockout), a stronger marker replacing a weaker one, with a placeholder tick (PlaceholderBeep; the X's lower and louder; pellets landing together tick once). A knockout gets the kill's X in the stun colour (not in the brief: it is the baton's "kill").
- **Material is data the surfaces already carry.** `ShotFxConfig.group_for()`: a body (a hitbox or BodyParts) is `body`; else the collider's `wall_surface` metadata on any face that is not a floor (new: a kit `Room` writes `concrete`, so its walls and ceiling are concrete whatever its floor), else its `surface` metadata (every kit part, ADR 0033), else the `material.*` tags of the nearest entity above the collider (props already have them: `material.metal`, `material.electronics` -> metal; `material.wood`, `material.cardboard` -> wood; `material.glass` -> glass), else concrete. The tables are in `items/weapons/fx/shot_fx.tres`.
- **One pooled effects node per viewport** (`ShotFx.in_world()`, not an autoload): bullet holes are two `ImpactMarks` (round holes; glass crack stars), capped at 200 (the oldest reused), fading over 3 s after 30 s; puffs are six one-shot `CPUParticles3D` per material group, reused in turn; tracers are 16 pooled streaks moved by `TracerMotion` (pure: 300 m/s, 3 m streak, 60 ms fade). It is built when the first holder enters the tree (deferred), not on the first shot, and cleared on `scene_changed`. Visual only, not saved.
- **`ImpactMarks` is reused**, extended with per-mark size and colour, an optional texture and a fade (`fade_after`, `fade_time`); the range's spray wall keeps its marks as before.
- **Holes only on static surfaces** without their own ImpactMarks: never on bodies, rigid props, doors or characters (a hole on a moving body would hang in the air). Puffs everywhere.
- **Every holder gets a `ShotFeedback` child.** A shot's projectiles each leave the impact of what they hit; a tracer from the muzzle to the first projectile's end on every N-th round: N is the holder's `tracer_every` (guards: 1, set in `guard.tscn`), else the weapon's `WeaponData.tracer_every` (assault rifle and SMG 3, others 0). A melee hit on a body: a blue-white spark when the weapon deals `damage.stun`, else the body puff; on a surface, nothing.

## Alternatives considered

- **Markers from the weapon code** (the holder calling the HUD): couples weapons to the player's HUD and shows hits that did no damage. The brief asked for the damage events.
- **A physics material or a new component per surface**: the kit parts and props already carry `surface` metadata and `material.*` tags; a third channel would drift from them.
- **Impact effects through stimuli** (a receptron on every surface): kit geometry has no receivers, and a visual effect needs no gameplay chain.
- **GPU particles**: one-shot CPU particles are cheap at this count and need no per-shot reallocation.
- **Delaying the impact until the tracer arrives**: hits are instant rays everywhere else; the hole appears with the shot.

## Consequences

- `WeaponData.tracer_every`, `WeaponHolder.tracer_every` and every `ShotFxConfig`/`ImpactPuff`/`HitMarkerConfig` value are `@export_range` values (the range's tuning panel lists the weapon's).
- Measured, 30-round assault rifle spray at the range's spray wall (`tests/items/weapons/fixtures/fx_spray_cost.tscn`): the effects take about 0.05 ms per shot inside the physics step (slowest 0.09 ms; 1.4 ms over the whole spray); the physics and process frame times with and without the effects differ by less than the run-to-run noise (about 10 ms and 3.5 ms per frame in the hub on a busy machine).
- A guard's fire is now readable from a distance by its tracers, before M13b's guard recoil changes their accuracy.
