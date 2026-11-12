# 127. Hit reactions, guards obeying recoil, retuned guard accuracy (M13b)

Status: Accepted (builds the "getting hit" and "guards obey recoil" parts of [ADR 0120](0120-weapon-feel.md) M13b; amends [ADR 0070](0070-guard-combat-and-loadouts.md) and [ADR 0123](0123-recoil-and-skill-aim.md))

Date: 2026-11-12

## Context

ADR 0120 asks that a hit kicks the view and adds spread for about 0.3 s, that a hit guard flinches (its next shot about 0.3 s later) and a limb hit staggers it, all without player-only or guard-only code; and that guards shoot with the weapon's own spread and recoil, compensating about 70 % and still firing short bursts, retuned so the ADR 0070 survival targets hold (a still player survives at least 3 s at 10 m, about 2 s at 4 m). Until now guards used their own cone (`guard_aim.tres`, `guard_rifle_aim.tres`) widened by `CombatModel.spread_deg()` (2.0 degrees + 0.15 per metre beyond 4 m), with `recoil_enabled` and `weapon_aim` off (ADR 0123).

## Decision

- **`HitReaction`** (`actors/common/hit_reaction/`, tuning `HitReactionConfig`): a component any character carries; the `hit_reaction` receptron (`damage`, after `body_damage`, blocked while dead or unconscious) runs `HitReactionEffect`, which hands the stimulus and the hitbox part to the component. It reacts to the types in its config (ballistic, blunt, stun, explosive: not a burn or a fall) from 1 damage up, only while the character can act:
  - **aim punch**: `RecoilState.add_punch()` on the character's WeaponHolder (`holder_path`): up `punch_up_deg`, sideways up to `punch_side_deg` away from the side the shot came from, returning with its own time constant `punch_recover_time` (armed or not). The punch shares the climb's split: the eye's owner turns the eye by `view_share` of it (the player's camera: the camera motion setting), the shots and the crosshair take the rest.
  - **spread**: an `aim_spread_add` Modifier for `spread_time` (the holder's cone floor jumps up at once, then the cone settles back at the weapon's settle time). The arm injuries use the same attribute.
  - **flinch**: `is_flinching()` for `flinch_time` after the hit (a new hit restarts it). `CombatBehaviour` passes it to `CombatModel.step()`: while flinching it does not fire (a burst ends, a swing waits) and the pause before the next shot does not run down, so the next shot comes exactly the flinch later.
  - **stagger**: a hit on a `stagger_parts` hitbox (arms, legs) multiplies `move_speed_mult` by `stagger_speed_mult` for `stagger_time`, and `lean()` tips the model away from the shot (top along the shot's horizontal direction, easing in over `lean_in_time`, back over the rest); `CharacterAnimator` applies it to the whole model about its feet. No hit clip exists in the Kenney characters.
  - Saveable (the timers), so the Modifiers a save keeps in the Attributes are removed when they run out after a load. Logged `actor.hit_reacted {actor, part, type, flinch, stagger}`.
- **Tuning**: the player (`player_hit_reaction.tres`): punch 1.0 up / 0.5 side, 0.1 s return; spread +1.5 degrees for 0.3 s; no flinch, no stagger (the player's control is the player's; its tuning turns them off). Guards (`guard_hit_reaction.tres`): the same punch and spread, flinch 0.3 s, stagger 0.5 s at x0.4 speed, 12 degrees of lean.
- **Guards obey recoil**: `recoil_enabled` on in `guard.tscn`, `weapon_aim` back on for every loadout (the rifle and SMG overrides and `guard_rifle_aim.tres` removed; the guards' pistol `pistol_unsilenced.tres` now names `pistol_aim.tres`). Guards have no Skills, so they shoot as Untrained (the configs' 1.5x patterns, full noise). **Compensation** is `CombatConfig.recoil_compensation` (0.7): the behaviour sets the holder's `RecoilState.view_share` to it and calls `view_recoil()` before each holder step; since it re-aims the eye at the target every tick, the followed share is pulled back and the shots keep `1 - share` of the climb (and of a hit's punch). 0 leaves the whole pattern, 1 none.
- **Retuned accuracy**: `CombatModel.spread_deg()` is now the shooter's own error on top of the weapon's cone: `spread_base_deg` 0, `spread_per_metre` 0.05 beyond 4 m (0.3 degrees at 10 m), +2 degrees on a target faster than 3 m/s, x1 -> x0.75 over 2 s on a still target. Bursts 3-4 shots (were 3-5: the rifle guard killed a still player at 4 m in 1.5 s).
- **Measurement through the real holder**: `tests/actors/guard/guard_fire_sim.gd` builds a shooter from a guard loadout scene's own data and fires the real `WeaponHolder` at the player's hitboxes on `CombatModel`'s timing (reaction, intervals, bursts, reloads, compensation), ticked in a loop without awaiting frames; medians over seeded engagements. It replaces the old cone-only simulation.

## Measured (medians, time under fire from the first shot to death, a player standing still unless stated)

| Target | Pistol guard | Rifle guard | SMG guard | ADR 0070 (pistol, mean) |
|---|---|---|---|---|
| Standing still, 4 m | 2.35 s | 1.98 s | 2.88 s | 2.25 s |
| Standing still, 10 m | 6.75 s | 5.37 s | 3.85 s | 4.4 s |
| Standing still, 15 m | 13.8 s | 11.8 s | 14.4 s | 15 s |
| Crouched still, 15 m | 18.0 s | 15.7 s | 15.5 s | 17 s |
| Running, 6 m | 6.8 s | 4.5 s | 4.5 s | 5.9 s |
| Running, 10 m | 14.1 s | 12.3 s | 14.6 s | 21 s |

The targets hold for every loadout (10 m at least 3 s, 4 m 2-3 s). The pistol guard is weaker at range than before (the pistol's own Untrained still cone is 2.0 degrees and it blooms 0.8 per shot); the automatic guards carry the threat at 10 m.

## Alternatives considered

- **A flinch tag (`state.flinching`) read by CombatBehaviour**: tags are saved with the entity and other systems would see a transient state; the component query is enough for one reader.
- **The aim punch as a recoil climb step**: it would only exist while a weapon with a RecoilConfig is drawn and return at that weapon's speed.
- **A spread bump on the cone instead of a timed floor**: its length would follow each weapon's settle time (0.3 to 0.8 s).
- **Guards with Weapons skill tiers (Skills component)** to keep the pistol guard as accurate at 10 m as before: more state per guard and the Skills UI's assumptions; a per-loadout `CombatConfig` is the simpler knob if the playtest wants it.
- **A live guard in the yard for the survival measurement**: slow (awareness, navigation) and fragile under tuning (CLAUDE.md, retrospective 2026-11-10).

## Consequences

- Any character with a HitReaction, a receiver with the `hit_reaction` receptron and (optionally) a WeaponHolder reacts to hits; the player and every guard do.
- The stagger leans the model, not the hitboxes or the static shadow proxy.
- Tests: `tests/actors/common/hit_reaction/hit_reaction_test.gd`, `tests/actors/guard/guard_hit_reaction_test.gd`, `tests/actors/player/player_hit_reaction_test.gd`, `tests/actors/common/combat/recoil_compensation_test.gd`, `tests/actors/common/combat/combat_model_test.gd` (flinch), `tests/items/weapons/recoil_state_test.gd` (punch), `tests/actors/guard/guard_accuracy_test.gd` and `guard_auto_accuracy_test.gd` (survival); review shots `tests/actors/guard/fixtures/stagger_shot.tscn`.
