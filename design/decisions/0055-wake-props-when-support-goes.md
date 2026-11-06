# 55. Wake props when their support goes

Status: Accepted

Date: 2026-11-06

## Context

Playtest: in a column of 3 small crates, setting fire to the bottom one left the two above floating in the air after it broke. Picking up the bottom crate of a stack did the same.

Confirmed with a headless test (`tests/objects/stack_support_test.gd`): after 2 s at rest every crate of a 3-crate column reports `sleeping`; when the bottom crate burns out (Breakable frees it), the others stay at 0.9 and 1.5 m centre height. Jolt does not wake sleeping bodies when the body under them is removed from the space, nor when it loses its collision (the carry ghost: layer and mask 0, frozen). A crate knocked out from under a stack is fine: the moving body wakes what it touches.

## Decision

- **`SupportWake.wake_touching(body)`** (`objects/components/support_wake.gd`) wakes every rigid body on the objects layer that overlaps the body's collision shapes' bounds grown by 0.05 m on every side (one box query), then repeats from each body it woke, so a whole column above wakes, not only the first crate (at most 64 bodies). It reads only the node's shapes and transform, so it works while the body is leaving the tree.
- Called from the few places a body stops supporting others:
  - `PhysicsObject._exit_tree()`: any prop freed or removed (broken, burnt out, exploded, item pickup consumed into the inventory, `queue_free` from a test or tool).
  - `Carryable.set_carrier()` on pick-up: the held body becomes a ghost.
  - `Breakable.break_apart()` for an entity that is a collision object but not a `PhysicsObject` (the static wooden barricade).
- Waking is harmless: a woken body that is still supported goes back to sleep after Jolt's sleep time.

## Alternatives considered

- **Disable sleeping on props** (`can_sleep = false`): costs solver time on every resting prop and lets stacks creep.
- **Patch each caller** (Breakable, Explosive, ItemPickup, PlayerCarry): several places, and any new way of removing a prop would bring the bug back.
- **Waking only direct contacts and relying on Jolt to wake the rest** when the woken body moves: works for a column in practice, but the transitive search costs one query per woken body and does not depend on contact timing.
- **Querying with the exact shapes and a margin**: the grown bounding box is shape-independent and over-reaching by a few centimetres only wakes extra bodies, which is harmless.
