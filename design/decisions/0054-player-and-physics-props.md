# 54. Player and physics props: no solver contact, scripted push and weight

Status: Accepted

Date: 2026-11-06

## Context

Playtest: stacking crates and jumping on them made the physics unstable. Stacking props to climb is a core immersive-sim verb and must be solid.

Headless measurements (M3 small crates, flat floor) showed stacks are stable on their own (a 3-crate column and a 2+1 pyramid drift < 0.001 m in 5 s) and so are jumping in place on them, landing on them and running into them. What broke them was the player moving *along or into* a crate it touches:

| Scenario | Crate drift | Peak crate speed |
|---|---|---|
| Walk across the top of a 2-crate column | 3.9 m (top crate dragged along, flipped) | 6.3 m/s |
| Mantle onto a 2-crate column holding forward | 11.6 m | 16.4 m/s |
| Hop on top of a column | 1.4 m | 3.5 m/s |

Cause: the player is a `CharacterBody3D`. Jolt moves a kinematic body to its new transform with `MoveKinematic`, i.e. with the velocity that covers the move in one tick, and gives it infinite mass. Friction from a walking player drags the crate under its feet, the scripted mantle (which the probe checks with a 2 cm slimmer capsule) scrapes the ledge at several m/s, and a crate overlapping the capsule when the player teleports away is flung (a crate spawned inside it hit 600 m/s and broke). Solver or tick settings cannot fix an infinite-mass contact.

Jolt pairs a rigid body with a kinematic one only when the rigid body's mask contains the kinematic body's layer (verified: with the crate mask lacking the player layer, the player still stands on, mantles and is blocked by crates through its own `move_and_slide`, and the crates feel nothing).

## Decision

- **Props do not scan the player layer.** `PhysicsLayers.OBJECT_MASK` = world, actors, objects; every prop scene uses it and `PhysicsObject._ready()` clears the player bit whatever the scene says (pickups owned by other features included). The player's own mask still has objects: it stands on, collides with and mantles onto props exactly as before (`PlayerProbe` unchanged).
- **The player moves props with bounded forces instead** (`PlayerPusher`, pure numbers in `PushRules`, tuning in `player_config.tres`, run after `move_and_slide()` each movement tick, not while mantling):
  - Weight: the bodies under the feet (a sphere query just below the capsule bottom) share a downward force of `body_mass` (80 kg) x engine gravity, through their centres so standing near an edge does not tip a crate; each body gets at most `weight_max_ratio` (4) x its own weight (the full 784 N on a 0.5 kg bottle flung it out from under the feet; solvers handle stacked mass ratios up to about 10:1).
  - Push: the bodies within `push_probe` (0.05 m) ahead of the capsule along the attempted horizontal velocity, above the feet (a cylinder query from 0.05 m up, so not what the player stands on), get a central impulse away from the capsule axis that brings them up to the player's speed toward them, at most `push_max_speed` (2 m/s), with a shared budget of `push_force` (250 N) x delta. The player's slide stops at the crate, so pushing slows the player to the crate's speed.
  - Bodies carried by the player and frozen bodies are skipped.
- **Props have friction 0.5** (`objects/materials/prop_physics.tres` on the six `objects/` props; was the default 1.0). A box pushed through its centre tips when friction exceeds its width/height ratio (1 for a cube), so at 1.0 pushed crates tumbled. Wood on wood is about 0.3-0.5. With 0.5 a prop on the floor needs 0.5 x mass x 9.8 N to slide: 250 N moves a small (10 kg) or metal (25 kg) crate, not a large one (60 kg, 294 N), which stays a fixed climbing aid.
- No Jolt solver settings and no tick rate changes (`physics_ticks_per_second` stays 60).

After the change (same scenarios): walking across the top, mantling and hopping all leave the column within 0.001 m (peak 0.03 m/s); walking or sprinting into a 2-crate column pushes it together at up to 1.9 m/s (top crate stays on, tilt < 1°).

## Alternatives considered

- **Solver tuning** (velocity/position steps, sleep thresholds, penetration slop, CCD): the stacks were already stable; the problem is an infinite-mass contact.
- **Raising the tick rate**: same reason, and many tests rely on 60 Hz.
- **Toggling the player's mask around `move_and_slide()`**: unnecessary once it was clear that only the prop's mask creates the pair.
- **A physics proxy for the player** (a velocity-driven RigidBody3D or a teleported StaticBody3D capsule that props collide with): would keep props from passing through the player, but a velocity-driven proxy drags crates the same way, and a teleported static body does not wake sleeping props resting on it. More moving parts for a prototype.
- **Applying the push low on the body instead of lowering friction**: needs each prop's extents; friction 1.0 was unrealistic anyway.

## Consequences

- Props pass through the player: a crate falling on the player's head, a thrown bottle or a crate blown by an explosion goes through the capsule, and the player is pushed out of a prop that ends up overlapping it (`move_and_slide` recovery). Their impacts no longer log `object.impact` against the player or deal `damage.blunt` to it. Revisit with a scripted response (cancel a prop's approach velocity near the capsule, forward impact damage) if playtests show it.
- Guards (layer 3, `CharacterBody3D`) still collide with props in the solver and can shove them with infinite mass; apply the same rule when guards start moving among props (M7).
- Teleports of the player (load, respawn, test placement) no longer disturb props.
- Lower friction: thrown and blown props slide a little further on the floor.
- Tests: `tests/objects/crate_stack_test.gd`, `tests/actors/player/player_crate_stack_test.gd`, `player_crate_push_test.gd`, `player_pusher_test.gd`, `push_rules_test.gd`.
