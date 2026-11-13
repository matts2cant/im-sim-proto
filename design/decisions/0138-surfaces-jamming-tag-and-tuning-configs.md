# 138. Surfaces, the jammed tag and shared tuning configs

Status: Accepted

Date: 2026-11-13

## Context

The code audit ([audit-2026-11-13.md](../tech/audit-2026-11-13.md), S8, S9, S11-S13) found:

- Guard awareness, the network and the deck asked the jamming field's static registry whether a point was covered (one system calling another), and the field was indexed twice (a static list and a group).
- Materials were read three ways: `surface` metadata (its name defined three times), `material.*` tags (only bullet impacts fell back to them) and `MaterialProfile`. A metal crate stood on sounded like concrete.
- Gameplay tuning sat in per-node exports (mine radius and arm time, the 2.5 s fuse, the breaker's clunk, the access point's Wi-Fi range, alarm hearing, the door opener's lookahead, fall impact) or in constants (the guards' look-around period, their "standing still" speed, the break sound's unit size).
- The proximity mine picked its victims by physics layer only.

## Decision

- **Jamming is a tag.** A `JammingField` adds `state.jammed` (`ActorState.JAMMED`) to every entity with Tags within its radius (its origin, straight line): on start, every physics tick and after loading; it removes the tag as they leave and when it ends, unless another running field (the `jamming_field` group, its only index) still covers them. Readers only read the tag (`ActorState.is_jammed()`): a radio message (`AwarenessEffect.radio`) is lost when the receiving entity or the sender (the stimulus source) is jammed; `DeviceNetwork.is_jammed()` when the device or its access point is; the deck's Wi-Fi (`DeckSession.jammed()`) when the user or the access point is. Any other source of the tag (a jammer augmentation, a device) works the same.
- **One reading of surfaces.** `Surface.of(collider, normal)` (`objects/materials/surface.gd`): the collider's `wall_surface` metadata on a face that is not a floor, else its `surface` metadata (static geometry: kit parts), else the first level of the `material.*` tag of the nearest entity at or above the collider with Tags (`material.metal` -> `metal`), else empty. Footsteps (`SurfaceTable.surface_of()`) and bullet impacts (`ShotFxConfig.group_for()`, whose `surfaces` table now also maps `cardboard`, `electronics` and `glass`) use it; the metadata names are `Surface.META` / `Surface.WALL_META`. The footstep probe (`MovementNoiseConfig.surface_probe_mask`) sees the objects layer too, so a prop stood on gives its material. `MaterialProfile` stays what an object does when it is hit or breaks (its own impacts), not what surface it offers.
- **Shared tuning configs.** Gameplay tuning a designer would change for every instance lives in a `*Config` resource the scenes reference, with a `DEFAULT_CONFIG` fallback for components built in code: `ProximityTriggerConfig` (`items/grenades/proximity_trigger.tres`), `FuseConfig` (`fuse.tres`), `CircuitBreakerConfig`, `AccessPointConfig` (a level gives one access point a longer reach with its own `.tres`: the warehouse's AP-YARD, 27 m), `AlarmHearingConfig`, `DoorOpenerConfig` (with the door search margin), `FallImpactConfig`. Former constants join existing configs: `AwarenessConfig.look_around_period`, `CombatConfig.still_speed`, `BreakSettings.sound_unit_size`. Per-instance placement (a mine's light offset, a breaker's circuit and label, an access point's key) stays on the node.
- **The mine's tag filter.** `ProximityTriggerConfig.required_tags` / `ignored_tags` (like `LaserArrayConfig`): when `required_tags` is not empty only characters with one of them set it off; characters with one of `ignored_tags` never do. Both are empty in the shipped config: every character, as before.

## Consequences

- Every tuned value is unchanged; footsteps on a prop (a metal crate, a wooden desk) now sound like its material.
- A jammed entity's tag is saved with its Tags and restored with the field; a field removed without ending (freed with its level) clears its tags on leaving the tree.
- The field walks the `tags` group every physics tick while it lasts (a distance check per tagged entity).
- Tests: `tests/objects/materials/surface_test.gd`, the metal crate footstep test in `movement_noise_test.gd`, the field's tagging in `jamming_field_test.gd`, `proximity_trigger_config_test.gd`, the tag filter in `proximity_trigger_test.gd`, `tests/scenarios/shipped_tuning_test.gd`.
