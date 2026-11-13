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
