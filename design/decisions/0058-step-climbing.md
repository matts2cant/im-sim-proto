# 58. Step climbing as a generic character component

Status: Accepted (supersedes [ADR 0034](0034-ramps-not-stair-stepping.md); raises the navmesh max climb of [ADR 0041](0041-runtime-navmesh-bake.md))

Date: 2026-11-06

## Context

ADR 0034 chose ramps over automatic stair stepping. Playtest feedback: the character gets stuck against low obstacles, which feels wrong next to other games; the player should walk onto steps without jumping, and the height should be tunable. `CharacterBody3D` still has no step-up. Guards arrive in M7 and must get the same behaviour with no new code.

## Decision

- **`StepClimber`** (`actors/common/movement/step_climber.gd`), a component of any CharacterBody3D, tuned by a **`StepConfig`** `.tres` (the player's: `actors/player/player_step.tres`): `step_height` 0.35 m (feet, the bottom of the shape, to the obstacle's top surface), `step_reach` 0.13 m, `smooth_time` 0.1 s. Pure rules in **`StepRules`** (RefCounted).
- It runs after the controller's `move_and_slide()` (parents process first), so a controller needs no calls: any body that moves with `move_and_slide()` and has the node gets it. The intended motion is the first slide collision's travel + remainder (the move's whole motion before sliding; checked on Jolt), else `velocity × delta`. It acts only when the body was on the floor before the move and the asked-for vertical speed is not a launch (≤ 0.1 m/s: a jump or a blast does not step; walking up ramps gives 0).
  - **Step up**, when the move hit a wall (a contact steeper than the max floor angle that is not a ceiling) while moving into it: cast the body's own shape up by `step_height`, forward along the motion, then down to the start height (`PhysicsServer3D.body_test_motion`). Accept when the obstacle's top (highest supporting contact point) is ≤ `step_height` above the feet, the body rose at least that high before its head hit anything (headroom for its current shape, crouched or standing), it lands > 1 cm higher and the landing normal is walkable (≤ 45°). The body is put there, keeps the horizontal velocity it asked for (no speed loss) and is snapped to the floor.
  - **Forward distance**: this tick's motion first, then `step_reach` if that is longer. A capsule's rounded bottom lands on a step's edge; the edge contact is walkable only once the axis is within radius × sin 45° (0.25 m) of the edge, about 0.10 m further than where the capsule first touches it. Landing on the edge is fine: the capsule then rides up the walkable edge contact over a few ticks, which also softens the rise.
  - **Step down**, when the move took the body off the floor and no step up happened: cast down to `step_height` below the floor it left; when the capsule still hangs on the edge it left (steep contact), cast again from a little further along the motion (same distances). On a walkable floor the body is put there and `apply_floor_snap()` sets the floor state, so `is_on_floor()` never goes false on stairs: no `actor.landed`, no `damage.fall`, footstep strides continue. A drop deeper than `step_height` falls as before.
  - Each step emits `stepped(rise)`.
- **Order**: the component makes itself its parent's first child, so sibling components (MovementNoise, FallImpact, Knockback) read the stepped state in the same tick.
- **Scripted moves**: a controller that moves its body by script tags it `stance.mantle` (`ActorState.MANTLING`); the component then does nothing (slide collisions from the last real move are stale).
- **Props**: the body steps onto any collider in its mask. It does not step onto a rigid body that collides with it in the solver (not frozen, its mask contains the body's layer): putting a kinematic body on such a prop flings it (seen in a probe: a 200 kg slab launched 0.6 m). The player is not in the props' mask (ADR 0054), so it steps onto debris and dropped items; a body on the actors layer shoves props as before.
- **Camera**: the player keeps the camera where it was on `stepped` and eases the offset out (`StepRules.ease_offset`: exponential, 5 % left after `smooth_time`, the offset limited to `step_height` so stairs do not pile it up). The camera is a child of the head, so the weapon and the carried object move with it.
- **Rays use the smoothed eye**: `Player.eye_transform()` is the camera, so the Interactor, carry and weapon rays start where the view is and match the crosshair. The difference is at most 0.35 m for under 0.1 s.
- **Tuning in play**: the debug panel's Player tab has a step height field (edits the loaded `player_step.tres` in memory).
- **Levels**: walk-up steps ≤ 0.3 m (margin below 0.35), 0.35-1.0 m jumped onto, 1.0-1.9 m mantled; 0.3-0.35 m is a grey zone (`Ledge.band` "between bands"). Small props (cardboard 0.5 m, small crate 0.6 m) stay above the step height, so stacking them is still a jump. The navmesh max climb rises from 0.05 to 0.3 m, so guards path over the same steps and stairs.

## Alternatives considered

- **Keep ramps only (ADR 0034)**: the playtest found it wrong; low lips, debris and art-pass stairs would all need invisible ramps.
- **A move function controllers call instead of `move_and_slide()`**: exact intent, but every controller must call it; the post-move component needs nothing from the controller, like the other ADR 0056 components.
- **Pre-move test (step before `move_and_slide()`)**: needs the controller's velocity before it moves, which a child component does not see.
- **Forward reach of the full radius (land on top, not on the edge)**: no edge riding, but a 0.35 m horizontal jump per step.
- **Cylinder collision shape**: no edge riding at all, but changes every other contact of the character.

## Consequences

- Guards (M7) get steps and stairs by adding a `StepClimber` with a `StepConfig`.
- A step moves the body up to ~0.1 m further than its velocity that tick (the forward reach); on stairs at walk speed the extra is mostly under one tick of motion. Playtest whether it reads as a hitch.
- Walking off a 0.35 m or lower ledge no longer falls: no landing noise, no air time.
- Debris and dropped items can be walked over by the player; ADR 0045's reason for keeping debris off the props layer (it would block the player) no longer holds, but nothing changes.
- **Open**: guards on the actors layer will not step onto dynamic props (they shove them). If guards get the player's arrangement (ADR 0056's open question), they step onto props too.
