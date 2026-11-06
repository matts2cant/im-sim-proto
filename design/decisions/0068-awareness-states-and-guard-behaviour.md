# 68. Awareness states and guard behaviour

Status: Accepted (refines [ADR 0012](0012-guard-awareness.md); applies [ADR 0054](0054-player-and-physics-props.md) to guards)

Date: 2026-11-06

## Context

ADR 0012 chose graded states (Unaware, Suspicious, Searching, Alerted/Combat); M7 settles the triggers, timings and what a guard does in each, without combat, body discovery, radio or alarms (the next wave). Guards must be built from the generic character components (ADR 0056, 0058) with no guard-only rules, hear through the stimulus framework, and not shove props with infinite mass.

## Decision

- **Model**: the pure **`AwarenessModel`** (`actors/common/awareness/`, tuning **`AwarenessConfig`**, the guard's `guard_awareness.tres`) holds the meter, the state and the phase (what to do: routine, look, move, look around, chase), the pace (walk, investigate, run) and the destination. **`GradedAwareness`** (extends `Awareness`) is the node adapter: it asks the PerceptionSensor each tick, takes heard noises and harm through stimuli, logs, saves. **`AwarenessBehaviour`** carries out the phase with **`NavWalker`**, the generic non-player controller (NavigationAgent3D path, speeds from the pace: walk 1.8, investigate 2.5, run 5.0 m/s, turn 240°/s, gravity, `stance.sprint` from 4 m/s so MovementNoise is louder). Patrols are a **`PatrolRoute`** (ordered Marker3D children, `wait` metadata per point, looped) the behaviour points at.
- **States** (timings in the `.tres`):
  - Unaware: patrol, or hold the post (spawn position and facing) glancing ±45° for 1.5 s every 6 s. Meter ≥ 0.3 (0.2 while wary) on sight, or a heard noise: Suspicious. Meter 1.0: Alerted.
  - Suspicious (`?`): stop and face the point for 2 s, walk there (investigate pace), look around 4 s, then Unaware and wary. New evidence moves the point (a glimpse each tick; a noise; far evidence while looking around sends it there again). A noise perceived ≥ 10 (a break within 5 m, an explosion) skips the look and runs. Meter 1.0: Alerted.
  - Alerted (`!`): meter held at 1; runs to the last known position, which follows the target while it is seen; within 1.5 m of a seen target (plus its braking distance) it stops and faces it (attacks: next wave). Also entered when harmed by an entity with a hostile tag, and by **`alert_at(position)`**, the external input for alarms, radio and shouts (or an `ALERT` AwarenessEffect on a stimulus). Unseen for 4 s: Searching.
  - Searching (`?`, orange): 4 random points within 8 m of the last known position (snapped to the navmesh; the first at run pace, then walking), looking around 3 s at each; 30 s at most; then Unaware and wary. Seeing the target: Alerted at once. A noise sends it there.
  - Wary: 60 s after any return to Unaware: vision gain × 1.5, Suspicious from 0.2.
  - Not able to act (`state.dead`, `state.unconscious`): the model is reset, nothing is seen or heard, the receptrons block the tags. `is_aware()` (the knockout rule, ADR 0049) is true only while Alerted or Searching, so a baton from behind still knocks out an Unaware or Suspicious guard.
- **Deviation from the first diagram**: investigation lives in Suspicious; Searching follows a lost target (after Alerted), not a suspicion.
- **Hearing**: the `heard_noise` receptron (`noise`, min perceived 1.0, `AwarenessEffect` NOISE) on a second receiver, **`Ears`, at floor level (0.1 m)**. Noise distance is the navmesh path to the receiver; at head height the last leg added ~1.6 m, so the guard heard as if 1.6 m further away. Walking on concrete (6) is heard at 3.5 m path distance (perceived about 2.3), not at 6.5 m. Noise whose source has an ally tag (other guards' footsteps) is ignored; everything else (the player, props, breaking crates) is heard. Harm: the `harmed` receptron (`damage`, `AwarenessEffect` HARM, after `body_damage`) alerts only when the source has a hostile tag.
- **Props pass through guards** (ADR 0054 applied to the actors layer): props no longer scan layer 3 (`PhysicsLayers.OBJECT_MASK` = world | objects; `PhysicsObject` clears both character layers). Guards push props with bounded forces through **`BodyPusher`**, the player's pusher made a generic component (`actors/common/pusher/`, tuning `PushConfig`). Unlike the other ADR 0056 components it needs one call: the controller (Player, NavWalker) passes the velocity it tried to move at to `after_move()` right after `move_and_slide()`. Reading it from the slide collision (as StepClimber does) was tried and broke a quickload test: a body pushed out of an overlap reports the recovery as travel, so a player loaded against a table of pickups shoved them and itself. The ImpactSensor turns props flying into a guard into `damage.blunt` (it switched itself on), and StepClimber may step guards onto props: both open points of ADR 0056 and 0058 close.
- **Feedback** (ADR 0022): **`AwarenessIndicator`** above the head: `?` yellow (Suspicious), `?` orange (Searching), `!` red (Alerted); a bark Label3D for 2 s on each state change (lines from **`BarkLines`**, `guard_barks.tres`) with a generated placeholder beep (`PlaceholderBeep`, no audio files); a reset (knocked out) does not bark. The debug panel's Overlays tab toggles the icons (on by default) and a state + meter + wary text.
- **Lying down**: **`DownedPose`** tips the figure and hitboxes over while the character cannot act and lays the capsule flat (about 0.7 m high).
- EventLog: `actor.awareness {actor, from, to, reason, meter, point}`, `actor.heard {actor, perceived, point}`, `actor.bark {actor, line, from, to}`.
- Saved: position, facing and velocity (NavWalker), the model (state, meter, wary time, points, timers, RNG), patrol index, wait and post (AwarenessBehaviour). A spawned guard is restored by the snapshot's spawned-scene rule like any entity.

## Alternatives considered

- **A state machine of nodes per state**: harder to unit-test; the pure model is tested without the scene tree.
- **Hearing measured from the head with a lower threshold**: hides the error in a tuning number; distances along the floor are what path propagation measures.
- **A guard root script with patrol and perception logic**: identity code; the guard is a scene of generic components.
- **Keeping props colliding with guards in the solver**: infinite-mass shoves (ADR 0054), and the ImpactNoise under-read of ADR 0056.

## Consequences

- Props pass through training dummies too (static, actors layer): a thrown crate flies through a dummy; its ImpactSensor reports the hit (same damage, one hit).
- Combat, body discovery, waking guards, carrying bodies, shouts, radio and the alarm plug into Alerted and `alert_at()` (next wave).
- Tests: `tests/actors/common/awareness/`, `tests/actors/guard/`, `tests/scenarios/guard_awareness_test.gd` (fixture `tests/scenarios/fixtures/guard_post.tscn`), `tests/actors/common/pusher/`.
- See [perception and AI](../game/perception-and-ai.md).
