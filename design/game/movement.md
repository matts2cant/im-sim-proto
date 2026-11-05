# Movement

Milestone: M1 (Movement course).

## Purpose

First-person player controller whose movement modes feed the noise system.

## Player-facing behaviour

Walk, crouch, sprint, jump, mantle (ledges, crates), and vents (crouch-only paths). Lean and ladders are v1 (see [../backlog.md](../backlog.md)).

## Rules

- Footstep noise = movement mode x surface multiplier. The surface comes from the floor material tag.
- Speed Enhancement augmentation: faster, higher jump/mantle, louder landings. Run Silent: footstep noise x0. See [abilities.md](abilities.md).
- Leg damage: one leg at 0 = slow, both = crawl. See [damage.md](damage.md).
- Vents are paths only passable while crouched.
- Footsteps are emitted as `noise` stimuli ([stimulus-response.md](stimulus-response.md)); guards hear them via path distance ([perception-and-ai.md](perception-and-ai.md)).

## Interactions

- Controls: [controls.md](controls.md)
- Roof route of the mission (stacked crates + mantle or Speed aug, then vent): [../levels/mission-warehouse.md](../levels/mission-warehouse.md)

## Open questions

- Speeds, jump height, mantle reach, noise values per mode, surface multipliers: TBD in M1.
- Controller choice and step handling: TBD in M1.
