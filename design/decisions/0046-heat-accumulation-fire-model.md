# 46. Heat accumulation fire model, fresh chain per pulse with cause_id

Status: Accepted

Date: 2026-11-06

## Context

M2's placeholder made a crate burn the moment any `fire` reached it. That spreads instantly and ignores distance, so fire would race through a room in a few ticks. Fire must spread at a readable pace (seconds), depend on distance, stop at walls and never reach non-flammable objects. Burning objects also re-emit fire for many seconds, which the stimulus framework's chain depth (max 16, [ADR 0003](0003-systemic-framework.md)) would cut off if every pulse were a child of the previous one, yet scenario tests must still trace which fire lit which object.

## Decision

- **Heat accumulation** (`HeatModel`, `Flammable`): a `fire` stimulus adds its perceived intensity (linear falloff, [ADR 0038](0038-linear-falloff-noise-metres.md)) to the object's heat through the `heat_from_fire` receptron. Heat cools continuously at `cool_rate` per second. The object ignites when heat reaches `ignition_threshold`.
- **Burning**: tag `state.burning`; every `pulse_interval` (0.5 s) it emits `fire` and `damage.fire` (RADIUS, `LINE_OF_SIGHT`, the object's intensity and radius) and a crackle `noise` (4 m). Fuel runs down for `fuel_seconds`; then `state.burning` is removed, `state.charred` added, and a `Breakable` object breaks. Charred objects do not reignite.
- **LINE_OF_SIGHT propagation**: straight-line distance, delivered only when a ray from the origin to the receiver hits nothing on the world layer ([ADR 0045](0045-collision-layers.md)); the source's and receiver's own bodies are ignored.
- **Fresh chain per pulse**: each pulse is emitted on the component's own tick at depth 0, so long fires never hit the depth cap. It carries `cause_id` = the id of the stimulus that ignited the object. `Stimulus.cause_id` is a general field: `StimulusSystem.emit()` fills it with the parent's id for effect emits, and it is logged on `stimulus.emitted`. `object.ignited` logs `by` = the igniting stimulus id, so a fire is traced `object.ignited.by` -> pulse -> `cause_id` -> the previous object's `object.ignited.by` -> ... -> a stimulus with `cause_id` 0.
- Explosives use the same `HeatModel` with their own threshold and no burning phase.
- All numbers live in `.tres` files ([objects-and-fire.md](../game/objects-and-fire.md)).

## Alternatives considered

- **Instant ignition with a probability**: not deterministic, hard to test, and distance only enters through the probability.
- **Ignition after N seconds in range** (timer per neighbour): needs per-pair state and ignores how hot the fire is.
- **Pulses as children of the igniting stimulus** (depth + 1 each): a 20 s fire is 40 pulses deep; the depth cap would drop them. Raising the cap removes the runaway-loop protection.
- **No LOS (STRAIGHT)**: fire would spread through walls; **PATH**: fire would follow the navmesh round corners, which is right for sound but not for radiant heat.

## Consequences

- Spread times follow from the numbers and are unit-tested: touching small crates (centres 0.6 m) ignite in 3.0 s, a crate touching a brazier in 2.0 s, a small crate with a 0.6 m gap only after 19 s (just before the burner runs out of fuel), metal never.
- Every pulse costs one line-of-sight ray per flammable receiver in range; fine for gallery-scale rooms.
- `cause_id` is available to every system (M4 damage, M7 perception can trace causes the same way).
