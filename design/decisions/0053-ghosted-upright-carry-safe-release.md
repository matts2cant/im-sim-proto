# 53. Ghosted, upright carry with safe release

Status: Accepted

Date: 2026-11-06

## Context

Since M3 the carried object stayed a physical body 1.2 m ahead: its velocity chased the hold point, it kept its collisions (except with the player) and its orientation, and it was dropped (`how: stuck`) when it lagged 1.5 m behind. In playtests it sat too far away, bumped and jittered against walls and doorways, blocked the view, kept whatever tilt it had on the floor and fell out of the player's hands in tight spaces. Stacking crates by putting one on another was hit and miss.

## Decision

- **Closer, sized hold.** The object's centre sits `hold_base_distance` (0.45 m) + its largest half-extent (from its collision shapes' AABB) along the view from the eyes, and `hold_drop` (0.1 m) + half-extent lower on the screen (camera down, so it stays in the lower part of the view at any pitch; its top edge sits about 12 degrees below the crosshair whatever its size). Small crate: 0.75 m ahead, 0.4 m down; cardboard box: 0.7 m, 0.35 m.
- **Ghost while held.** Collision layer and mask are set to 0 and the body is frozen kinematic; every physics tick `PlayerCarry` places it exactly at the hold point (no lag, no stuck drop). Nothing collides with it or hits it: world, player, objects, actors, weapon and interaction rays. Its exact layer, mask and freeze state are restored on release. Stimuli still reach it (the StimulusSystem delivers radius stimuli by distance), so it still heats up, burns, hurts its carrier when burning and is hurt by explosions.
- **See-through.** Every `GeometryInstance3D` under the body (meshes, CSG) gets `transparency` 0.5 (`held_transparency`) while held, except the fire FX; the previous values are restored on release.
- **Upright.** On pick-up the object turns upright (local up = world up) at the nearest quarter turn of yaw relative to the view, and moves to the hold point, both blended over 0.15 s (`hold_turn_time`); then it keeps that yaw relative to the view.
- **Safe release.** Put down (E), drop (Q) and throw (LMB) first look for a free spot: the object's shapes are tested free at the chest (on the player's axis, 0.35 m below the eyes), then cast in two legs to the release target (the hold point, pushed forward until it is capsule radius + half-extent + 0.1 m from the axis): out at chest height then down when the target is lower (lowering it onto what is below, e.g. a crate to stack on), up then out when it is higher. Each leg stops 1 cm short of the first contact against world, objects and actors. The final spot must overlap nothing, the player included; otherwise the release is refused: the object stays held, `player.release_refused {object, how, reason: no_room}` is logged and the Interactor prompt reads "No room to put down ...". Throws start from the free spot at the usual speed. Forced releases never refuse: `load` lets go where the object is, `died` and `respawn` use the free spot or else the chest.

## Alternatives considered

- **Keep the physical, colliding hold and tune it** (closer, stiffer): still jitters against walls and doorways and still needs a stuck drop; objects knock other props over while carried.
- **Ghost without a release check**: a ghost can be inside a wall or another object at the moment of release, and Jolt would then push it out violently or through the wall.
- **Single straight cast from the chest to the hold point**: lowers diagonally, so a crate put down on another catches the lower one's edge and topples off; the two-leg path lands it on top.
- **Viewmodel-style rendering (separate camera layer)**: hides clipping into walls but needs a second viewport and breaks fire FX and lighting on the object.

## Consequences

- Carried objects pass into walls and other props visually (they are see-through, so this reads as "held", not as a bug). The player cannot use a carried object as a shield against bullets or as a step.
- A held burning object no longer lights things by touching them; it still lights them by its fire radius.
- Facing a wall at point-blank you cannot put down or throw: step back. With a 0.6 m crate the gap between capsule and wall must be over 0.6 m.
- `hold_distance`, `hold_follow_rate`, `hold_max_speed` and `hold_break_distance` are gone from `PlayerConfig`; `player.dropped` no longer has `how: stuck`.
