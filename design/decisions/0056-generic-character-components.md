# 56. Generic character components: movement noise, falls, impacts, knockback, state tags

Status: Accepted

Date: 2026-11-06

## Context

A code audit against the systemic design principle (AGENTS.md) found character behaviour that only the player had, typed to player classes or called directly between systems:

- Footstep and landing noise lived in `PlayerNoise` / `PlayerNoiseRules`, typed to `PlayerConfig` and `PlayerMotion.Mode`, driven from `player.gd`.
- Fall damage was a direct call `body.take_fall(speed)` from `player.gd`.
- Since ADR 0054 props do not collide with the player in the solver, so `ImpactNoise` never sent the player `damage.blunt`: a thrown crate hurt the training dummy, not the player. (It still reported a stray contact while the crate passed through, at a meaningless speed, about 1.2 damage instead of 12.)
- Nothing turned blast or impact forces into a shove for characters (a parallel change adds `force.blast` / `force.impact` stimuli).
- `WeaponHolder`, `Player`, `Interactor` and the inventory screen asked `BodyParts.can_act()` / `arms_disabled()`, so a sleep-gas or handcuff effect adding a `state.*` tag would not stop anything.
- How area damage is shared over the body was hardcoded per type in `BodyProfile`, and aim tuning (`AIM_MOVING_SPEED`, `AIM_AIR_GRACE`) was in `player.gd`.

Guards arrive in M7 and must get all of this by composing components and `.tres`, with no new code.

## Decision

- **`MovementNoise`** (`actors/common/movement/`, config `MovementNoiseConfig`, the player's in `actors/player/player_movement_noise.tres`): a Node3D at the feet of any CharacterBody3D. Every physics tick, after its parent moved (parents process first), it reads `is_on_floor()`, the velocity and the stance tags `stance.crouch` / `stance.sprint`; every stride of horizontal travel on the ground is a footstep, a touchdown is a landing. It reads the floor's surface with its own short ray (WORLD layer, as the player's old `FloorRay`). Events are now `actor.footstep` / `actor.landed` (source = the body). The player's numbers are unchanged (walk 6 / sprint 14 / crouch 2 x surface; landing 6 x clamp(v / 5, 1, 4) x surface from 3 m/s). `SurfaceTable` and `FootstepTracker` moved to `actors/common/movement/`. The player sets the stance tags; any controller does the same.
- **`LandingTracker`** (pure): a touchdown's impact speed is rebuilt from the two ticks before it (last airborne vertical velocity + one more tick of the same downward acceleration), because the landing move has already zeroed the velocity. In free fall this equals the velocity the move started with, whatever the body's gravity scale, so no controller has to report it.
- **`FallImpact`** (same folder): on a touchdown of at least 3 m/s, emits `damage.fall` CONTACT on its own body, intensity = impact speed (m/s), source = the body. The **`fall_damage` receptron** (`actors/common/body/receptrons/fall_damage.tres`, `include_self`) runs `BodyDamageEffect` with the new `threshold` 10 and `scale` 16; the profile shares `damage.fall` 50/50 over the legs: (v - 10) x 8 per leg, as before. The generic `body_damage` receptron ignores it because it is the entity's own stimulus. Swapping or blocking the receptron (an augmentation) changes falls; the profile's type multipliers still apply (armour). `BodyParts.take_fall()` and `BodyProfile.fall_*` are gone.
- **`ImpactSensor`** (`actors/common/impact_sensor/`): on a body whose collision layer is not in the props' mask (`PhysicsLayers.OBJECT_MASK`), it overlaps the body's own shape with the props each tick; a prop newly overlapping it (not seen within `ImpactSettings.throttle`), moving towards the body's axis at `min_speed` or more and not carried, deals `damage.blunt` CONTACT = `ImpactRules.damage()` (source = the prop). On bodies props collide with it switches itself off (the training dummy has one, inactive). `ImpactNoise` now ignores contacts with bodies outside its own collision mask, so the stray pass-through contact no longer adds a second, wrong hit.
- **`Knockback`** (`actors/common/knockback/`, config `KnockbackConfig`, the player's in `actors/player/player_knockback.tres`) and the **`knockback` receptron** on `force` (matches `force.blast` and `force.impact`) with `KnockbackEffect`: velocity change = impulse x `impulse_scale` / `mass`. RAY pushes along the ray; RADIUS away from the origin towards the receiver (where the falloff is measured). The upward part goes into the body's velocity, capped at `max_up_speed` 3 m/s (feet rise at most 0.23 m under the player's 2 g, 0.46 m under 1 g). The horizontal part (capped at 8 m/s) is carried by the component, which moves the body itself after the controller moved (`move_and_collide`, sliding along walls) and damps it (8 m/s^2 on the ground, 2 in the air). A barrel at 2 m (about 56 N s at the player's receiver) shoves the player about 4 m/s, roughly a metre.
- **State through tags**: `ActorState` (`actors/common/actor_state.gd`) reads `state.dead`, `state.unconscious`, `state.arms_disabled`, `state.legs_disabled` and the stance tags from the entity's `Tags`. Weapons, input, the Interactor, the inventory screen and the crawl check use it; `BodyParts.can_act()`, `arms_disabled()`, `legs_disabled()` are removed so nothing bypasses the tags.
- **Area damage as data**: `BodyProfile.area_weights_by_type` maps a damage type to part shares (most specific type wins): explosive torso 40 % / 12 % each other part, fire even, blunt torso, fall legs 50/50; `default_part` (torso) for types without an entry.
- **Aim tuning**: `aim_moving_speed` (0.5 m/s) and `aim_air_grace` (0.1 s) moved to `PlayerConfig`.

## Consequences

- A guard (CharacterBody3D) gets footsteps, landing noise, fall damage, knockback and (if props pass through it) impact damage by adding the nodes, the receptrons and its `.tres`; its controller only sets the stance tags.
- The knockback shove is not part of the body's `velocity`: aim bloom and footsteps do not see it, and a controller cannot steer against it. It is transient and not saved.
- Footstep distance now comes from the post-move horizontal velocity instead of the position change; on the floor they are the same. A mantle (velocity zero, no move) makes no footsteps, as before.
- **Open:** a kinematic body that does scan props (mask includes objects, e.g. a guard on the actors layer) is pushed out of a crate that hits it by its own `move_and_slide` recovery, and `ImpactNoise` reads that as the body moving away: about 1.2 damage instead of 12 for a 10 m/s small crate (the static dummy reads 12). Fix before guards take thrown props (M7), e.g. by measuring against the body's own velocity, or by giving guards the player's arrangement (props pass through, ImpactSensor). Resolved in M7 ([ADR 0068](0068-awareness-states-and-guard-behaviour.md)): props no longer scan the actors layer, so guards (and training dummies) get the player's arrangement and an active ImpactSensor.

## Alternatives considered

- **Controller reports footsteps / landings / fall speed to the components**: exact but every controller would need the calls; polling needs none.
- **Fall stimulus carrying the damage amount** (formula in the emitter): the receiver could not change the threshold without changing the emitter.
- **Excluding `damage.fall` from `body_damage` with a new receptron field**: a framework change; the own-source rule already separates them.
- **Knockback as a velocity change the player's motion damps** (an overspeed rule in `PlayerMotion`): every controller would need the same rule, and the player's normal braking from sprint to walk would change.
- **Calling the prop's `ImpactNoise.impact()` from the sensor**: would also make the prop's noise and self-damage on a pass-through hit, but reaches into another component; kept to the brief's `damage.blunt` only.
