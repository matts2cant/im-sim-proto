# 70. Guard combat: one weapon path for every actor, loadouts as data

Status: Accepted, amended by [ADR 0127](0127-hit-reactions-and-guard-recoil.md) (guards shoot with the weapon's cone and recoil; accuracy retuned and re-measured) (extends [ADR 0068](0068-awareness-states-and-guard-behaviour.md); amends [ADR 0045](0045-collision-layers.md) and [ADR 0054](0054-player-and-physics-props.md))

Date: 2026-11-06

## Context

M7 wave 2 arms the guards. The systemic rule (AGENTS.md) says the player is not special: a guard's shot must be the same `damage.*` RAY stimuli, noise and hitbox delivery as the player's, and a loadout must be data. Since M4 the player's weapons already lived in `WeaponHolder` (stimuli, aim cone, ammo), but it was typed to a `Camera3D`. Guards also need a combat behaviour that shares the `NavWalker` with the awareness behaviour, accuracy that leaves the player time to reach cover, and a fix for a wave-1 regression: props passed through training dummies.

## Decision

- **One weapon path.** `WeaponHolder` takes any `Node3D` as its eye (`setup(user, eye)`: the player's camera, a guard's `Aim` node); shots and sweeps leave the eye along -Z. Nothing in it reads input: the player's script feeds mouse look and the trigger, a combat component points the eye and pulls the trigger. `physics_step(delta, stance, floor_add)` lets a driver widen the cone floor. Guards' shots are therefore the same `damage.ballistic` RAY + `force.impact` RAY, muzzle and impact `noise`, hitboxes and BodyParts as the player's. A ranged weapon with `WeaponData.muzzle_flash_size` > 0 shows a `MuzzleFlash` (an unshaded box and a 4 m light, 0.06 s) at the front of its box.
- **Loadouts are data.** `guard.tscn` has an `Aim` node (1.6 m, the eye height) with an empty `WeaponHolder` (aim tuning `guard_aim.tres`) and a `Combat` (`CombatBehaviour`, tuning `guard_combat.tres`): unarmed it never engages, and the AwarenessBehaviour stands off at 1.5 m as before. `guard_pistol.tscn` and `guard_baton.tscn` are inherited scenes that only set the holder's `weapons`. The guards' pistol is `items/weapons/pistol/pistol_unsilenced.tres`: the player's numbers (25 ballistic, 10 rounds, 1.6 s reload, 30 spare) but 25 m of muzzle noise (silenced: 6 m) and a flash.
- **`CombatBehaviour`** (`actors/common/combat/`, pure timing and accuracy in `CombatModel`, tuning `CombatConfig`): engaged while the `GradedAwareness` is Alerted **and** the `PerceptionSensor`'s sighting this tick is a target that can act. No new awareness state: losing the target for 0.5 s ends the engagement and the existing Alerted -> Searching flow runs (chase to the last known position, 4 s unseen, search).
- **Arbitration: one owner of the walker.** `NavWalker.take_control(node)` / `release_control(node)`; the default controller (`AwarenessBehaviour`) skips its tick while `is_controlled_by_other(self)`. Combat takes the walker on engaging and hands it back on any disengagement (lost, calm, incapacitated, unarmed, target_down). `NavWalker.hold_facing(point)` keeps it facing the target while it walks (backing away).
- **Pistol**: 0.5 s of sight before the first shot of an engagement (a sight loss within the grace keeps it); then a random 0.6-0.9 s between shots; reloads an empty magazine from its reserve (the weapon's 1.6 s), and tops up a part-used one when not fighting; keeps 6-12 m centre to centre (beyond 12 it advances to 11 at 2.5 m/s, under 6 it backs off to 7 at 1.8 m/s facing the target; cornered, it stands); fires only standing (< 0.3 m/s) and facing within 15°. **Line of fire**: a weapon-mask ray from the eye to each aim point in turn (the target's hitboxes: torso, head, arms, legs; without hitboxes chest, head, feet of its shape); it aims at the first whose first hit belongs to the target, and does not fire while none does (an ally, a wall or a prop in the way). Blocked for 1 s it steps 1.5 m sideways (alternating) and finishes the step before firing, so it does not shoot past an ally's edge.
- **Baton**: runs in (5 m/s) to 1.2 m plus its braking distance, swings while the aim point is within the baton's reach (1.8 m from the eye) minus 0.3 m, facing within 15°, after the reaction; the swing rate is the baton's 0.6 s cycle. The knockout rule is the target's awareness (ADR 0049): guards fight hostile-tagged targets, and the player has no `Awareness`, so it always counts as aware: 20 stun a hit, never the sneak x10.
- **Accuracy** (`CombatModel.spread_deg`, the cone floor of the guard's `AimModel`, whose own floor is 0 standing, +3 walking): `(2.0 + 0.15 x (metres beyond 4)) + 2.0 if the target moves faster than 3 m/s`, times a settle factor falling linearly from 1 to 0.75 over 2 s of sight of a still (< 0.5 m/s, smoothed over 0.15 s) target. 2.0 at 4 m, 2.9 at 10 m, 3.65 at 15 m; the player's settled cone is 0.5 (0.2 at Master). Arm injuries add `aim_spread_add` as for the player; no shot bloom, sway 0.1.
- **Static characters block props** ([ADR 0054](0054-player-and-physics-props.md) refined). Wave 1 took the actors layer out of the props' mask, so thrown crates flew through training dummies. A new layer 7 `static_actors` holds characters whose body never moves by script (a `StaticBody3D`: the dummy, on layers 3 and 7). Props scan it (`PhysicsLayers.OBJECT_MASK` = world, objects, static actors; `PhysicsObject` forces it): a static body has no infinite-mass push to fear, so the solver bounces a crate off a dummy and the crate's ImpactNoise reports the hit (the dummy's ImpactSensor turns itself off: no double count). Kinematic characters (player, guards) stay off layer 7 and keep pushing with BodyPusher.
- EventLog: `actor.engaged {actor, target}`, `actor.disengaged {actor, reason}`; the shots and swings log as the player's (`weapon.fired`, `weapon.swung`, `weapon.reload_started`, `weapon.reloaded`).
- Not saved: an engagement is transient (a loaded game re-engages on sight with a fresh reaction); the holder saves the loadout's magazine and reserve.

### Tuning check (measured)

Measured by `tests/actors/guard/guard_accuracy_test.gd` on the real hitboxes, the guard's `AimModel` and the player's body profile (25 a hit, x2 on the head; dead at torso 100 or head 60 lost: 4 torso or 2 head hits). "Time under fire" runs from the first shot (the 0.5 s reaction comes before it); a still target settles the aim. Hit chance: the first shot's cone.

| Target | Hit chance (any part) | Mean time under fire to death |
|---|---|---|
| Standing still, 4 m | 100 % | 2.25 s (3 intervals) |
| Standing still, 10 m | 76 % | 4.4 s |
| Standing still, 15 m | 28 % | 15 s |
| Crouched still, 15 m | 26 % | 17 s |
| Running (> 3 m/s), 6 m | 82 % | 5.9 s |
| Running, 10 m | 32 % | 21 s |

The brief's targets hold: at 10 m in the open the player survives 4.4 s on average (≥ 3 s), at 4 m about 2 s. Crouched-and-still at 15 m is hit about a third as often as running at 6 m. Arm and leg hits do not kill but disable limbs (spread, speed).

**Amended by [ADR 0127](0127-hit-reactions-and-guard-recoil.md) (M13b)**: guards now shoot with the weapon's own cone, bloom and recoil (70 % of the climb pulled back), and `CombatModel.spread_deg()` is only their own error on top of it (0 + 0.05 degrees per metre beyond 4 m, the fast-target and settle terms unchanged). Re-measured through the real `WeaponHolder` (`guard_fire_sim.gd`), medians of time under fire for a pistol / rifle / SMG guard: standing still 4 m 2.35 / 1.98 / 2.88 s, 10 m 6.75 / 5.37 / 3.85 s, 15 m 13.8 / 11.8 / 14.4 s; crouched still 15 m 18.0 / 15.7 / 15.5 s; running 6 m 6.8 / 4.5 / 4.5 s, running 10 m 14.1 / 12.3 / 14.6 s. The targets above still hold.

## Alternatives considered

- **A guard-only gun script**: two code paths for the same stimuli; the player-is-not-special rule forbids it.
- **A Camera3D as the guard's eye**: a camera in the scene can become the current one; the eye is just a transform.
- **Combat as a new awareness state**: the Alerted state already holds "a known threat"; seeing it is the extra condition. A state would duplicate the chase/lose timers.
- **Arbitration by process order** (combat runs after the behaviour and overrides it): alternating `move_to` targets re-plan the path every tick, and the order is implicit.
- **Firing whenever the target is seen** (no line-of-fire check): guards would shoot each other; accidents remain possible only inside the cone after a clear check.
- **Hit chance as a die roll per shot**: the cone keeps the player's model (the shot lands somewhere real, hits a wall or a prop, makes impact noise) and is shown by the same code.
- **Putting dummies on the world or objects layer**: weapon rays scan both and would hit the capsule instead of the hitboxes; a separate layer keeps the dummy a character for weapons and sight.

## Consequences

- Any NavWalker character with a GradedAwareness, a PerceptionSensor, an `Aim/WeaponHolder` and a `CombatBehaviour` fights; a turret or a hostile civilian is a scene and a `.tres`.
- The other agents' arena switches to `guard_pistol.tscn` / `guard_baton.tscn`.
- Thrown props bounce off dummies again; a new static character must also sit on layer 7.
- Open: guards do not take cover, flank, strafe while firing or lead moving targets; muzzle flash is a placeholder box; guards reload only from their fixed reserve and drop nothing.
- Tests: `tests/actors/common/combat/combat_model_test.gd`, `tests/actors/guard/guard_pistol_test.gd`, `guard_baton_test.gd`, `guard_accuracy_test.gd`, `tests/scenarios/guard_combat_test.gd` (fixtures `combat_yard.tscn`, `combat_yard_player.tscn`), `tests/items/weapons/muzzle_flash_test.gd`, `tests/actors/common/impact_sensor/impact_sensor_test.gd` (crate off a dummy).
