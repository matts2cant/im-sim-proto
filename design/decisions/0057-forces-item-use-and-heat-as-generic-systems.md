# 57. Forces, item use and heat as generic systems

Status: Accepted

Date: 2026-11-06

## Context

A code audit against the systemic design principle (AGENTS.md) found three places where one system reached into specific others instead of going through stimuli or a shared interface:

- **Forces.** `Explosive` queried rigid bodies on the objects layer and called `apply_central_impulse` on each; `WeaponHolder` called `apply_impulse` on the body a shot hit. Nothing else could react to a blast or a bullet's push (a character's knockback, an object that resists, a future grenade), and a new pushing source had to copy the query.
- **Item use.** `ItemData.UseAction` was a closed enum; `HEAL` made `PlayerInventory` call `player.body.heal()`. A new consumable meant a new enum value and inventory code, and only the player could be healed.
- **Heat.** `HeatEffect` knew `Flammable` and `Explosive` by class; a new heat-reactive component meant editing it.

Some tuning was also in code: debris mass (0.3 kg), debris scatter (0.3) and lift (0.5) in `Breakable`, and the blast's upward tilt (0.3) in `Explosive`.

## Decision

### Forces are stimuli

| Type | Shape | Intensity | Direction |
|---|---|---|---|
| `force.blast` | RADIUS, LINE_OF_SIGHT (the propagation of the blast's damage and fire) | impulse in N s at the centre, linear falloff to 0 at the radius (the usual perceived intensity) | from the stimulus origin to the receiving entity |
| `force.impact` | RAY | impulse in N s (`WeaponData.impact_impulse`, pistol 3) | `stimulus.direction`; the hit point is the delivery data `position` |

- `Explosive` emits `force.blast` (`ExplosiveConfig.impulse` 120 / `impulse_radius` 4) first among its blast stimuli; ranged weapons emit `force.impact` next to their damage rays when `impact_impulse > 0`. Neither touches a body any more.
- **`ApplyImpulseEffect`** (`core/stimulus/effects/`): pushes a `RigidBody3D` entity by the perceived intensity; RADIUS pushes are tilted up by its `radial_lift`, RAY / CONTACT pushes go along the stimulus direction, at the hit `position` when there is one. `ApplyImpulseEffect.push_direction(stimulus, target)` is the shared direction rule (character knockback can use it). Non-body entities are ignored.
- **`receptrons/pushed_by_force.tres`** (`force`, `ApplyImpulseEffect` with `radial_lift` 0.3): the blast lift is tuning on the receiver's effect, not on the source, because a stimulus carries no extra parameters and the lift is about how a prop tumbles. `ExplosiveConfig` keeps the impulse and radius.
- **`PhysicsObject._ready` appends its exported `force_receptron`** (default `pushed_by_force.tres`; null opts out) to the prop's `StimulusReceiver`, creating one at the body origin when the scene has none (item pickups had none). Every prop is pushed as before (crates, barrels, bottles, cardboard, item pickups) without repeating the receptron in each scene. Debris was never pushed (no collision layer) and is not now.

### Consumables are data

- `ItemData.UseAction.HEAL` became **`CONSUME`** (same index, so `.tres` files did not change meaning). A consumable lists **`use_stimuli`** (type -> intensity; medkit `{heal: 30}`) and a **`refused_message`** ("You are not hurt").
- Using one sends each as a CONTACT stimulus on the player (source: the player) and consumes one. The user's receptrons decide what happens: `actors/common/body/receptrons/heal.tres` (`heal`, `include_self`, **`HealEffect`** -> `BodyParts.heal`), appended to the player's and the training dummy's receivers. Any character with that receptron can be healed by a `heal` stimulus from anything.
- **Refusal without special cases**: `Effect.can_apply(ctx)` (default true) says whether an effect would change anything; `HealEffect` says no for the dead and the unhurt. `StimulusSystem.would_affect(stimulus)` is a dry run of a CONTACT stimulus (same type, intensity, tag and self rules as delivery; nothing run or logged). A consumable none of whose stimuli would affect the user is refused and kept.
- **`StimulusSystem.emit_now(stimulus)`** delivers at once when called outside stimulus processing; from an effect it queues like `emit()`, so there is still no recursion. Item use needs it: the inventory screen pauses the game (ADR 0052), so a queued heal would wait until the screen closed.
- Kept as inventory / UI verbs: `EQUIP_WEAPON`, `EQUIP_TOOL` (change what is in hand) and `READ` (opens the reading overlay). Nothing in the world could react to them, so stimuli would only add indirection. `NONE` (biocell until M6, ammo, keycard) still shows its message.

### Heat goes to every heat-reactive component

- A component that reacts to heat joins group **`HeatEffect.GROUP`** (`heat_reactive`) and implements `add_heat(amount: float, cause: Stimulus) -> void`. `HeatEffect` calls it on every such direct child of the entity (direct children, like the components' `of()` lookups). `Flammable` and `Explosive` join the group; `HeatEffect` names neither.

### Tuning out of code

- `BreakSettings`: `debris_mass` 0.3, `debris_scatter` 0.3, `debris_lift` 0.5 (`break_settings.tres`). Blast lift: `pushed_by_force.tres` `radial_lift` 0.3.

## Consequences

- **Timing**: a blast's push now lands on the same tick as its damage and fire (it used to be applied directly, a tick earlier, so the fire burst met props already nudged). In the gallery's barrel alley the top stack crate (2.08 m, fire 6.1 against a threshold of 6) used to be nudged out of reach and catch later; now it lights with the others. A bullet's push lands a tick later than before (with its damage ray). `force.blast` is emitted before the damage, so a crate's contents spawned by the damage are not flung (as before).
- Stimulus ids of a blast shift by one (`force.blast` comes first); `item.used` for a medkit logs `action: consume, stimuli: [heal]` instead of `action: heal, amount`; `actor.healed` names the player as its source instead of "Medkit".
- Character knockback can react to `force.*` on characters with its own receptron and effect; `ApplyImpulseEffect` ignores non-rigid entities.
- Tests: `apply_impulse_effect_test` (minimal floating body), `scenarios/forces_test` (barrel blast pushes a metal crate and a medkit; a `force.impact` ray pushes and tips a crate), `heat_effect_test` (a heat-reactive component defined in the test), `would_affect_test`, `emit_now_test`, `heal_effect_test` (the dummy), `composed_entities_test` (Flammable, Explosive with and without Breakable, ImpactNoise and a burning carried object on entities built in code), and a consumable made in a test with its own stimulus.

## Alternatives considered

- **Keep the blast query and emit a stimulus per body**: still a closed rule in `Explosive` about which bodies exist.
- **Put the blast lift in `ExplosiveConfig`**: the stimulus has no field for it; adding generic parameters to `Stimulus` was more than this needed.
- **Give every prop scene the force receptron**: copy-paste across ten scenes and every new one; easy to forget on item pickups.
- **Queue the heal and consume optimistically**: no way to refuse an unhurt use, and paused delivery.
- **Interface by class (`if child is HeatReactive`)**: GDScript has no interfaces; a base class would force Flammable and Explosive into one hierarchy. A group plus a method is the lightest contract.
