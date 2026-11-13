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

## As built (M14a)

Grenades, throwing, sticking, mines, disarming, the Demolition skill and the HUD parts. The effects (payloads, gas cloud, EMP, jamming field, "Jammed") are M14b's.

- **A grenade is a thrown weapon.** `WeaponData.Kind.THROWN` (new): the item is an EQUIP_WEAPON stack of 5 drawn through the WeaponHolder like any weapon (its model is the view model, it swings like the baton); the trigger hands it to the user's **`Thrower`** component (`items/grenades/thrower.gd`), and `PlayerInventory` takes one from the stack on the holder's `fired` signal, keeping the next in hand. `WeaponData.thrown_scene` (a path: the entity references the item) is the entity spawned. A character without a Thrower cannot use a thrown weapon (guards until M16). HUD: the weapon corner shows the stack's count ("x3"); `is_ranged()` now decides the reticle and its target colour, so melee and thrown weapons both show the plain dot.
- **Thrower** (any character with a WeaponHolder; the player's in `player.tscn`): one ray from the eye up to `stick_reach` 1.2 m on world, objects and the character layers; a surface that is not a character (layer or BodyParts) gives a stick pose (`ThrowRules.stick_transform()`: +Y along the normal, the centre `Sticky.surface_offset` out) and the entity is stuck on the **collision shape hit** (a sliding door moves its Panel shape, not its body). Otherwise it is thrown: `ThrowRules.launch_velocity()` raises the view by `lift_deg` 20 and solves the launch speed that lands the user's `throw_distance` attribute (base 12 m in `throw_config.tres`) on flat ground from the eye height when looking level; the same speed for every pitch (a fixed arc). It starts 0.35 m ahead of the eye with some spin and ignores its thrower's body for 0.3 s. With `show_ghost` (the player) the drawn weapon's view scene is shown 60 % opaque at the stick pose.
- **Entity** (`items/grenades/grenade.tscn`, inherited by `frag/`, `gas/`, `emp/`, `jamming/<type>_grenade.tscn`): a PhysicsObject (0.4 kg, no linear damping, a bouncy metal material) with Tags, health 10, `take_damage` and `heat_from_fire` receptrons, `Explosive`, `Breakable` (break_on_depleted off), `ImpactNoise` and four new components, each usable on any entity: **`Fuse`** (lit: `Explosive.explode()` after `time` 2.5 s; while lit the body also collides with the character layers, so a thrown grenade bounces off people; saved), **`Sticky`** (freezes the body kinematic and follows the node it was stuck to at the same relative pose every tick, never colliding with its body; lets go and falls when it is freed; saved by path from the entity's parent), **`ProximityTrigger`** (arms `arm_time` 2 s after Sticky's `stuck`; then blinks and every 4 ticks queries a 2.5 m sphere on the character layers, a 1 m one for crouched (`stance.crouch`) candidates, and casts one ray per candidate to its shape's centre on world and objects; the first seen sets `Explosive.explode()` off; saved) and **`MineDisarm`** (a Usable available while armed: see below). Each type scene adds its model, its `display_name` and an empty **`Payload`** Node3D where M14b's payload scene goes. The shipped scenes carry a placeholder frag-like ExplosiveConfig (`grenade_placeholder_explosive.tres`: 100 damage in 6 m, no fire) until the payloads hold the real ones; the tests' minimal grenade (`tests/items/grenades/fixtures/test_grenade.tscn`, a plain RigidBody3D box without PhysicsObject) has its own small one.
- **Distances** are gaps from the mine's centre to the character's collision shape (the sphere query measures them), not centre to centre: a standing player 2.0 m away (centre, level) is 1.65 m from the mine. "Walking or running" is read as "not crouched": a character standing still in range triggers it too.
- **Disarming** (`MineDisarm`, E through the Interactor's Usable path): crouched, 1 to 2 m (gap, as above), `mine_disarm` attribute at least 1 (Demolition Trained+): the entity's item goes into the user's PlayerInventory and the entity is removed (no room: nothing happens, "No room in inventory"). Anything else beeps (a generated tone) and lights the entity's Fuse for 0.5 s. EventLog `mine.disarmed`, `mine.disarm_failed {reason: standing, too_close, too_far, untrained}`.
- **Frame**: a component hook, not a class check. `TargetStatus.STATUS_GROUP` (`frame_status`): any component in it answers `frame_word()`; its word comes before the others. ProximityTrigger says the new `Word.ARMED` ("Armed", blinking red) while armed. The name comes from the entity's `display_name` ("Frag grenade").
- **Demolition** (`skill_table.tres`, ADD effects): `throw_distance` +0 / 2 / 4 / 6 m, `mine_disarm` 0 / 1 / 1 / 1, `mine_sense_range` 0 / 0 / 8 / 8 m, `fuse_readout` 0 / 0 / 0 / 1. **`MineSense`** (the player) highlights armed mines within `mine_sense_range` every 10 ticks: a red translucent sphere, unlit, unfogged, drawn after every other transparent thing (over smoke), but depth tested (walls hide it: no seeing mines through walls). The HUD's `Fuse` label shows "Fuse 1.8 s" under the crosshair for the Thrower's last throw while `fuse_readout` is on.
- **Models** (deviation): the brief had the files swapped. The only Kenney grenade with a yellow part is `grenade-a`, the canister, so the frag is the round `grenade-b` and gas, EMP and jamming are `grenade-a` with its yellow caps recoloured green, blue and cyan by `grenade_tint.gdshader` (a material override sampling the colormap: texels inside the yellow swatch take the tint). The GLBs are not edited.
- **Measured**: the throw lands (first touch-down) 11.8 / 13.8 / 15.7 / 17.7 m away per tier (`thrower_test.gd`).
- **Not done here**: the payloads and effects (M14b), the shooting range lanes and the warehouse loot (M14 step 3).
