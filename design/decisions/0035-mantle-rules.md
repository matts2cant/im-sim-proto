# 35. Mantle rules

Status: Accepted

Date: 2026-11-06

Amended: M1 playtest feedback, minimum raised to 1.0 m (same playtest as [ADR 0036](0036-player-gravity-scale.md)).

## Context

Mantling is how the player climbs ledges and crates and enters raised vents ([ADR 0014](0014-movement-scope.md)). It must be predictable for level design, testable, and leave room for the Speed augmentation.

## Decision

- Trigger: pressing jump on the ground, or holding jump in the air, while facing a ledge.
- Height: the ledge top is at least 1.0 m above the ground the player last stood on (grounded or in the air) and above the feet, and at most 1.9 m above both the feet and that ground, so jumping first neither extends the maximum nor lowers the minimum. (Originally the minimum was 0.3 m above the feet; playtest showed low steps and gap edges triggered mantles when a normal jump was wanted. Ledges below 1.0 m are now jumped onto.)
- Reach: the ledge face is at most 0.8 m from the capsule axis, measured horizontally.
- Clearance: a standing capsule must be able to rise, move over the edge and fit on top; if only a crouched capsule fits (a vent entrance) the mantle ends crouched; otherwise it is refused.
- Duration 0.25 s + 0.15 s per metre of height, as a scripted move (vertical rise, then horizontal move) without physics.
- Not allowed while carrying.
- Eligibility is pure logic (`MantleRules`) fed by physics probe results (`PlayerProbe`).

## Alternatives considered

- Physics-driven climb (impulses): less predictable, hard to test.
- Ledge grab and hang: more states and animation work than v0 needs.
- Measuring height only from the feet: a jump would let the player mantle 2.9 m walls, removing the Speed augmentation's purpose.

## Consequences

- Level metrics: mantleable ledges are 1.0 to 1.9 m; 2.3 m is the "needs Speed aug" height; vents are 1.0 m high and can be entered from a ledge.
- Holding jump in the air catches ledges 1.0 m or more above the last ground after falling short of a gap; a same-level ledge cannot be caught. Playtest decides whether that stays.
- See [movement](../game/movement.md).
