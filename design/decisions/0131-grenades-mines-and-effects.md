# 131. Grenades, mines and their effects (M14)

Status: Accepted (starts after M13c is merged and playtested)

Date: 2026-11-13

## Context

The roadmap's M14 asks for explosives on the existing explosion and damage systems, and the jamming grenade promised by [ADR 0112](0112-hacking-reconciled-with-the-built-game.md#amendment-switches-routers-and-access-points-2026-11-11). Today the `Explosive` component makes barrels blow up (explosive damage, fire, a blast push, noise, chains); the player can throw carried props; a stun damage type exists (the baton); guards do not react to danger (the AI overhaul is M16). The user and the chief engineer settled M14 in a design review (grilling, three rounds).

## Decision

The full specification is [explosives.md](../game/explosives.md). In short:

- **Four grenades**: frag, gas, EMP, jamming; 1x1 items stacking to 5, on the belt, equipped like weapons. Models: Kenney `grenade-a` (frag) and `grenade-b` with its yellow part recoloured green / blue / cyan (gas / EMP / jamming), copied from the user's local Blaster Kit download.
- **One control**: LMB sticks the grenade where a ghost shows it when a surface (wall, floor, ceiling, door, prop) is within 1.2 m, else throws it in a fixed arc (no preview); a stuck grenade follows what it is stuck to; a thrown one bounces (off characters too) and goes off 2.5 s after the throw.
- **Every stuck grenade is a proximity mine**: arms after 2 s, blinks red, triggers on any character in line of sight within 2.5 m (1 m crouched), the player included; crouched at 1 to 2 m, E disarms it with Demolition Trained or better, else it goes off after a 0.5 s beep.
- **Effects** (first guesses, measured by tests): frag kills within 3 m, hurts to 6 m, pushes, chains, no fire; gas, a 5 m cloud for 12 s knocking out anyone inside in about 3 s; EMP, electronics off for 20 s within 6 m (cameras, turrets, lasers, door controllers, lights, the deck) and half the bioenergy drained; jamming, every wireless link within 10 m dropped for 20 s (the deck's Wi-Fi included, guards' radios silent), silent, with a "Jammed" status (blinking amber) on the frame, the Map and the lights.
- **Grenades are Explosive and Breakable**: shot or caught in a blast, they go off, so they chain.
- **Demolition skill** (new, four tiers): throw distance 12 / 14 / 16 / 18 m, disarming from Trained, mines highlighted within 8 m from Advanced, the fuse time on the HUD at Master; blast strength does not scale.
- **Guards** do not react to grenades until M16; they only hear the noises (bounce, blast, hiss, pop; the jammer is silent).
- **Testing**: the shooting range gets a grenade lane, a mine corridor and an EMP/jamming corner; the warehouse gets 2 frag, 1 gas, 1 EMP, 1 jamming as loot.
- **Build**: grenades, throwing, mines and the skill, in parallel with the four effects and the "Jammed" status; then the range and the warehouse.

## Alternatives considered

- **Remote charges**: later.
- **A separate mine item**: one item with two uses gives gas, EMP and jamming mines for free.
- **Hold to charge a throw, or an arc preview**: Deus Ex simplicity first; a preview can follow the playtest.
- **Impact fuses**: a fuse lets grenades bounce round corners and gives time to react.
- **Mines that spare their owner or allies**: needs factions (M15).
- **Mines that cannot be picked up, or that anyone can pick up**: disarming is what the Demolition skill is for.
- **Guards fleeing grenades now**: deferred to the AI overhaul with grenade throwing.
- **Fire from frag grenades**: barrels burn because they hold fuel; a frag does not.
- **Grenades sticking to people**: reads as a joke in a stealth sim.
- **A new gallery room**: the shooting range sits next to the weapons and needs no new hub space.

## Consequences

- New: grenade items, a sticking/ghost and fuse component, a proximity trigger component usable by any explosive, gas cloud, EMP and jammer effect components, the "Jammed" network state, the Demolition skill ([abilities.md](../game/abilities.md)).
- `NetworkState` and the frame, the Map and StatusLight learn the jammed state; ADR 0112's jamming numbers are kept.
- The shooting range and the warehouse are extended; their layouts are measured before placing.

## As built (M14b: the four effects)

**The payload contract** (shared with M14a's grenade entities). A grenade is an entity with an `Explosive` and a `Breakable` (`break_on_depleted` off); `Explosive.explode(cause)` is the one detonation entry. Its effect is a **payload scene** instanced as a child of the entity: `objects/explosives/payloads/{frag,gas,emp,jamming}_payload.tscn`, each an `ExplosivePayload` holding the type's `ExplosiveConfig` (`*_explosive.tres`: the blast) and, for gas and jamming, a `lasting` scene. `Explosive` takes its config from the payload in `_ready` when it has none (the payload may come before or after it among the children) and `ExplosivePayload._ready` calls `Explosive.use_config()` when the Explosive was ready first (the heat is kept). On `Explosive.exploded`, emitted before the entity is freed (with `Explosive.trigger`, the stimulus that set it off), the payload emits `released(origin, cause)` for its effect components (the EMP's `EmpPulse` child) and spawns `lasting` under the level root (`ExplosivePayload.level_of()`: the current scene, or the fixture's topmost node), never under the grenade or what it is stuck to. Whatever sets it off (fuse, mine trigger, shot, blast chain), the release is the same. A blast stimulus whose radius is 0 is not sent (the frag has no fire, the jammer no noise at all); `ExplosiveConfig.fireball` off leaves only the flash and the sound.

- **Frag** (`frag_explosive.tres`): `damage.explosive` 550 over 6.5 m (linear falloff, line of sight), `force.blast` 90 N s over 6 m, no fire, noise 70 m, Kenney `explosionCrunch_000`. Measured (grenade 0.1 m above the floor, horizontal distance to the feet; the damage reaches the receiver, 1.2 m up for the player's body, 1.6 m for a guard's): 2 m kills both (torso -143 / -135), 3 m still kills (-112 of 100 / -107 of 80), 4.5 m leaves both alive with more than half the torso gone (player 100 -> 37, guard 80 -> 20), 7 m nothing. With a linear falloff "more than half" stops at about 5 m (5.0 m for the player, 5.3 m for a guard); from there to 6.5 m the wounds are light (about -13 at 6 m). Barrels at 4 m take 211 (25 health: they go off), other grenades chain the same way. Tested on bodies with the player's and the guards' profiles and on the shipped guard.
- **Gas** (`gas_cloud.tres`, `GasCloud`): 2.5 m radius (5 m across), 12 s; every 0.5 s a uniform `damage.stun.gas` 10 (line of sight to the centre, which rises 1 m, less under a low ceiling); the first pulse one interval after the release. Knockout threshold 60: unconscious after **3.03 s** inside (measured: player body, guard body and shipped guard alike). The stimulus has no source (the cloud is no attacker, so no "from behind" x10 on unaware guards); `damage.stun.gas` causes no hit reaction (`HitReactionConfig.ignored_types`). Drifts 0.1 m/s in a random direction and stops for good 1 m short of a wall; swells in 0.8 s and fades over its last 2 s. Looks: ten soft puffs (`gas_cloud.gdshader`: edges and wall contacts fade; inside it tints the view). Hiss: noise 10 m.
- **EMP** (`emp.tres`, `EmpPulse`): an `emp` stimulus, uniform, STRAIGHT (walls do not stop it), 6 m, intensity = 20 s. **Being electronic is a component, not a tag**: `Powered` and `Device` (and `Energy`, `DeckSession`) call `EmpEffect.listen()` in `_ready`, which adds the shared `disrupted_by_emp` receptron to the entity's StimulusReceiver (creating one when it has none), so no scene lists it; a crate has neither and is untouched. Its `EmpEffect` calls `take_emp(seconds, cause)` on the entity's children in group `emp_reactive`: `Powered` starts an **outage** (`is_on()` = circuit `on` and no outage; it ends by itself; a circuit switched off meanwhile stays off), a `Device` without a Powered (the shipped door controller) runs its own outage, so `state.unpowered` and every existing power rule follow (cameras blind, turrets and lasers stopped, lights hidden, fail-safe doors unlock, fail-secure stay locked, the frame says "No power"), and `DeckSession` unplugs (`emp`). Its second effect, `ChangeAttributeEffect` with the new `of_current` -0.5, halves `energy` (80 -> 40 measured). No damage. Pop: noise 12 m, `zapThreeToneDown`, a small flash. Measured: off at 10 s, back by 25 s.
- **Jamming** (`jamming_field.tres`, `JammingField`): 10 m, 20 s, silent, a small blinking cyan beacon. A wireless link with **either end** inside a running field drops (`JammingField.jams_link()`; fields register in a static list): `DeviceNetwork.is_jammed(device)` (its radio link holds by range but is jammed) leaves the link out of the live reach graph (incidents reach no one, the deck cannot reach it) while `wireless_link()` stays the physical link (subnet, the Map's `physical_network()`, port kinds); the deck's Wi-Fi drops (`DeckSession` unplugs `jammed`, cannot join, `WirelessTool` has no signal); radio messages are lost when the receiver or the sender stands in a field (`AwarenessEffect.radio`, set on `heard_dispatch` and `heard_radio`; logged `radio.jammed`). Cables are unaffected (a deck on a jack inside a field keeps working). **"Jammed"** is a network state (`StatusLight.State.JAMMED`, `NetworkState.state_of()` after disabled): amber blinking on the light and lamp, "Jammed" on the frame, a blinking square and the word "jammed" on the deck's Map (the device stays drawn). Starting, ending and loading a field refresh every status light (`StatusLight.refresh_all()`).
- **Framework**: `Stimulus.uniform` (RADIUS without falloff: the gas dose, the EMP); `ChangeAttributeEffect.of_current`.
- **Saves**: a gas cloud (age, drift, place) and a jamming field (age, place) are spawned saveables; `Powered` and `Device` save their `outage`, so EMPed devices come back at the right time after a load.
- **Debug**: the Spawn tab's Gas, EMP and Jam buttons act at the crosshair.
- **Tests** (`tests/objects/explosives/`): `frag_payload_test`, `gas_cloud_test`, `emp_payload_test`, `jamming_field_test`, `explosive_payload_test` (the contract), on stand-ins built from components (`explosive_fixtures.gd`).
