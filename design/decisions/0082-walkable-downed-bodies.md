# 82. Downed bodies do not block characters

Status: Accepted (amends [ADR 0071](0071-bodies-discovery-waking-carrying.md) and [ADR 0045](0045-collision-layers.md))

Date: 2026-11-08

## Context

Playtest feedback: "I should be able to walk over dead bodies". DownedPose (ADR 0071) lays a downed character's capsule flat, a 0.71 m high obstacle (0.35 m radius): above the 0.35 m step height, so the player and guards stopped against every body and had to jump over it. A body must still be seen by guards at its real height, be carried, lie on the floor, and take blasts, fire, damage and shots.

## Decision

- While a character cannot act (`state.dead` or `state.unconscious`, ActorState), **DownedPose** moves its body off the character layers (`PhysicsLayers.CHARACTER_LAYERS`: player, actors) onto a new layer 8 `downed` (`PhysicsLayers.DOWNED`), and drops the character layers (and `downed`) from its mask. It keeps the world and objects in its mask, so it still lands on the floor and on props. Standing up again (woken) restores the layer and mask it had when it went down.
- No character scans `downed`, so the player and guards walk **through** a body as if it were not there (the figure clips through the legs; there is no first-person body to show it).
- What still meets a body is unchanged, because it never used the body's capsule layer: guards' sight (rays on world and props to points on the shape's real height, ADR 0071), stimuli (RADIUS delivery to the StimulusReceiver, line of sight on the world layer), weapon rays and the Interactor (the Hitboxes, layer 5). Queries that did hit the capsule through `actors` include `downed`: `LOOK_MASK` (pick-up ray, debug aim), the carry release check (`PlayerCarry.RELEASE_MASK`: nothing is put down inside a body) and the doors' `blocking_mask` (a door does not close on a body in the doorway).
- While the body is carried, the carry owns its layers (ghosted, ADR 0053); DownedPose puts the right ones back on its first tick after release, so a body that wakes while held gets its standing layers when let go.
- Rule on the tags, any character with a DownedPose (the guard; a minimal test character); nothing guard-specific.

## Alternatives considered

- **A lower lying shape** (a 0.3 m slab the step climber walks onto): the sight rays and `center_of()` read the shape's height, so a body would hide behind a 0.3 m kerb and the carry hold point would move; guards' navigation has no step-up onto moving bodies; walking onto a body also bobs the camera. Two shapes (one for sight, one for walking) would need every reader of "the first collision shape" to pick the right one.
- **Layer 0 while down** (like the carry's ghost): looking, the carry release check and doors could no longer find the body without scanning hitboxes; a named layer lets queries opt in.
- **Collision exceptions** between the body and every character: per pair, and new characters (spawned guards) would need adding.

## Consequences

- Bodies pile up without colliding with each other (each scans neither characters nor `downed`).
- A body no longer stops a guard's path or the player; nothing pushes it while walking through it.
- Props (mask world, objects, static actors) still pass through bodies, as through any character.
- Tests: `tests/actors/common/body/downed_pose_test.gd` (minimal characters: layers while dead/unconscious and after standing, a walker crosses, a stood-up one blocks, a blast still reaches it), `tests/actors/player/player_walk_over_body_test.gd` (the player walks across dead and unconscious guards; a woken guard blocks; weapon and interaction rays hit its hitboxes where it lies), `tests/actors/guard/guard_walks_over_body_test.gd` (a guard's path crosses a body), `tests/actors/player/player_carry_body_test.gd` (dropped and loaded bodies on `downed`).
