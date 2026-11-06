# 71. Bodies: discovery, waking and carrying

Status: Accepted (extends [ADR 0067](0067-vision-and-detection.md), [ADR 0068](0068-awareness-states-and-guard-behaviour.md) and [ADR 0053](0053-ghosted-upright-carry-safe-release.md))

Date: 2026-11-06

## Context

M7 wave 2: guards must find knocked-out or dead allies and raise the alert, wake the unconscious ones, and the player must be able to hide bodies. A knockout already adds `state.unconscious` (BodyParts, ADR 0049) and DownedPose lays the character down; nothing found or woke it. Carrying worked only for RigidBody3D props. The systemic rule applies: nothing guard-specific, properties only.

## Decision

- **What a body is**: an entity with one of the watcher's `ally_tags` and one of its `body_tags` (`PerceptionConfig`, the guard's: `state.unconscious`, `state.dead`). No class or scene check: a minimal character with those tags is a body.
- **Seeing bodies**: `PerceptionSensor.look_for_bodies(wary)` returns every body seen, with the vision gain of ADR 0067 (cones, the body's light level from its LightExposure, line of sight, wary x1.5; no stance factor), the distance and angle taken to the middle of its first collision shape (`center_of()`). Sight rays now aim at fractions of the shape's **world** height (`_vertical_extent()`): a capsule laid flat is 0.7 m high, so a low wall hides it; standing and crouched targets are unchanged.
- **Discovery** (`BodyDiscovery` component + pure `BodyDiscoveryModel`; tuning in `AwarenessConfig` group "Bodies"): per body, progress += gain x delta while seen, -0.5/s while not; found at 1.0. Lit at 4 m: 0.8 s; dark: only within the 2 m close override (1.6 s at 1.5 m). Each body is found once per watcher, keyed by its node path from the watcher (saved); the key is forgotten when the body can act again, so a guard knocked out a second time is found again.
- **Reaction**: logged `actor.body_found {actor, body, state, point}`; the `body_found` signal makes `AlertComms` shout (ADR 0072); `GradedAwareness.notice_body()` -> `AwarenessModel.discover_body(at, approach, tend)`: wary for at least `body_wary_duration` (180 s), and unless Alerted, Searching (reason `body`, bark "Man down!") with the first destination `approach` (0.5 m out from the body's bounds on the guard's side, run pace). An Alerted guard (possibly engaged in combat, ADR 0070) only becomes wary: it does not stop fighting to tend a body.
- **Waking**: for an unconscious body the model marks `tending`; on arrival the phase is **TEND** (AwarenessBehaviour: stop and face the point, like LOOK). BodyDiscovery counts the time the guard's centre is within `wake_distance` 1.2 m (horizontal) of the body's bounds; at `wake_time` 3 s it emits a `revive` CONTACT stimulus at the body (`actor.wake`) and ends the tend (look around, search on). The body's **`revive` receptron** (`actors/common/body/receptrons/revive.tres`: requires `state.unconscious`, blocked by `state.dead`) runs **`ReviveEffect`** (`BodyParts.revive()`: stun 0, `unconscious` false, the tag removed; health and injuries stay, so a woken guard is as hurt as before; `actor.revived {actor, by}`) then an `AwarenessEffect` of the new kind SEARCH (reason `woken`). The tend ends without waking after `tend_timeout` 8 s (could not get close), when the body stands or dies, or on sight of a hostile (Alerted). Calls (ADR 0072) do not interrupt a tend.
- **Wariness**: `make_wary(s)` keeps the longer of the current and `s`; the end of a search uses it too, so a body's 180 s outlasts the usual 60 s.
- **Carrying characters** (PlayerCarry, ADR 0053 generalised to any `PhysicsBody3D`):
  - `Carryable` gains `enabled_tags` (offered only while the entity has one: the guard's `state.unconscious`, `state.dead`), `carry_mass` (the mass the carry rules use; characters have no physics mass) and `carry_speed_factor`. The guard: 15 kg (carried over the shoulder: within the unaugmented 20 kg limit, above the 10 kg heavy-load mark) and x0.75, so the player moves at 0.8 x 0.75 = 0.6 of normal speed; a throw is the usual 40 N s / 15 kg = 2.7 m/s, a gentle toss.
  - Ghosting covers the body **and its Hitboxes** (layer and mask 0, restored on release), so weapon and interaction rays pass through what is carried.
  - Held still: a RigidBody3D is frozen kinematic as before; any other body (a CharacterBody3D) has its physics processing paused and its velocity zeroed, so its controller neither walks it nor drops it under gravity while it is placed every tick. Released, processing resumes and the release velocity becomes its `velocity`; its controller's gravity puts it on the floor. This is dispatch on the engine's physics-body kind (how to hold it still), not on what the entity is.
  - The hold point now places the **middle of the body's shapes** (their AABB centre) rather than its origin, and the release cast moves the shapes' middle from the chest to the target. A character's origin is at its feet and a lying capsule's middle is 0.9 m along it; props, whose shapes are centred, are unchanged.
  - The interaction: E on a downed character's hitbox ("E: carry Guard"); the Interactor and PlayerCarry find the entity through the hitbox (`Interactor.entity_of`).
  - Saved like any character: dropped, its position, tags and pose come back; saved while carried, it is saved where it is held and falls to the floor on load (the carry itself is not saved, as for props).

## Alternatives considered

- **Bodies as a separate perception pass with its own cones**: the same rules already exist; reusing the gain keeps darkness and distance meaning the same thing for bodies and intruders.
- **Discovery at first sight (binary)**: a body glimpsed at the edge of the cone in the dark would always be found; the brief asked for about a second of looking.
- **Waking by calling into the body's BodyParts**: systems talk through stimuli; a `revive` stimulus lets a medkit-like item, a gas or a script do the same later.
- **A TEND state in the awareness model**: Searching already means "something is wrong here"; TEND is a phase of it, so the search, wariness and barks need no new state.
- **Turning a downed character into a RigidBody3D ragdoll to carry it**: a large change to the character components (BodyParts, Hitboxes, saving) for a prototype; pausing the controller keeps one body.
- **Bodies always carryable whatever the mass**: a special case; `carry_mass` keeps the one carry limit rule (Combat Strength still matters for props).

## Consequences

- Any character with an ally tag, a body tag and the `revive` receptron is found and woken; a non-guard body (a civilian with `actor.guard`?) would need its own ally tag in the watchers' config.
- The player hides bodies in the dark: past 2 m a body in darkness is not found.
- Two guards may head for the same unconscious body; the second ends its tend when it stands.
- Woken guards keep their injuries and fight normally (combat engages on sight).
- `PlayerCarry.held` and its signals are typed `PhysicsBody3D`.
- Tests: `tests/actors/common/awareness/body_discovery_model_test.gd`, `awareness_model_calls_test.gd`, `tests/actors/common/perception/body_sight_test.gd`, `tests/scenarios/body_discovery_test.gd` (unconscious found, walked to and woken; dead never woken; dark only close up; a minimal non-guard character), `tests/scenarios/guard_body_combat_test.gd` (a tending pistol guard drops the body to engage; a woken pistol guard engages), `tests/actors/player/player_carry_body_test.gd` (carry, drop, save/load held and dropped).
- See [perception and AI](../game/perception-and-ai.md), [controls](../game/controls.md).
