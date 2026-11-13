# Explosives

Milestone: M14 ([ADR 0131](../decisions/0131-grenades-mines-and-effects.md)). Builds on the explosion, damage, stun, power and network systems: [objects-and-fire.md](objects-and-fire.md) (the `Explosive` component of barrels), [damage.md](damage.md), [hacking.md](hacking.md) (wireless links), [security.md](security.md) (electronics).

## Purpose

Four grenades give the player loud, quiet, technical and non-lethal answers, and every one doubles as a proximity mine. They are systemic: each effect is a component reacting through stimuli, so a grenade, a mine, a chain of blasts and a shot grenade all work the same way, and the player is hit by them like anyone else.

## Grenades

| Grenade | Model | Effect (centre of the blast) | Noise |
|---|---|---|---|
| Frag | Kenney `grenade-a` | Explosive damage: kills a guard or the player within 3 m, badly hurts from 3 to 6 m, nothing beyond 6 m; a blast push on props and bodies; chains to barrels and other explosives. No fire. | Very loud |
| Gas | `grenade-b`, its yellow part green | A gas cloud about 5 m across for 12 s, drifting a little, blocked by walls: stun damage over time to anyone breathing in it (unconscious after about 3 s inside), the player included. | A short hiss |
| EMP | `grenade-b`, blue | Within 6 m, everything tagged electronic switches off for 20 s, then comes back by itself: cameras blind, turrets stopped, lasers off, door controllers unpowered (fail-secure doors stay locked, fail-safe doors open), lights out, the deck unplugged; the frame shows "No power". Drains half the bioenergy of anyone inside (the player today). No damage. | A short pop |
| Jamming | `grenade-b`, cyan | Within 10 m for 20 s, every wireless link drops: wireless devices lose their access point (a camera still sees, its incidents reach no one), the deck's own Wi-Fi connection drops, guards' radios get no dispatches. Jammed devices show **"Jammed"** (blinking amber) on the frame, the deck's Map and their status light; a deck plugged in by cable keeps working. | Silent |

The numbers are first guesses, measured by tests and tuned on the range. The jamming numbers come from [ADR 0112](../decisions/0112-hacking-reconciled-with-the-built-game.md#amendment-switches-routers-and-access-points-2026-11-11).

### The effects as built (M14b)

Each grenade's effect is a payload scene under the grenade entity (`objects/explosives/payloads/`), beside its `Explosive`: it gives the Explosive its blast and releases its effect when the Explosive goes off, whatever set it off; a gas cloud or a jamming field is spawned in the level and lasts on its own ([ADR 0131 "As built"](../decisions/0131-grenades-mines-and-effects.md#as-built-m14b-the-four-effects)). Measured by `tests/objects/explosives/`:

| Grenade | Tuning | Measured |
|---|---|---|
| Frag | `damage.explosive` 550 over 6.5 m (linear falloff, line of sight), push 90 N s over 6 m, no fire, noise 70 m | 2 m and 3 m: dead (player and guard); 4.5 m: alive, more than half the torso gone (player 100 -> 37, guard 80 -> 20); about 5 m to 6.5 m: light wounds (-13 at 6 m); 7 m: nothing. Barrels and grenades within about 6 m go off |
| Gas | cloud 2.5 m radius, 12 s; `damage.stun.gas` 10 every 0.5 s, the same anywhere inside with line of sight to the centre (1 m above the release); drifts 0.1 m/s, stops 1 m short of walls; hiss 10 m | Unconscious after 3.03 s (player, guard); nobody behind a wall or outside the radius; no flinch from the gas |
| EMP | `emp` 6 m (walls do not stop it), 20 s; anything with a `Powered` or a `Device` is electronic (no tag); half the `energy`; pop 12 m | Off at 10 s, back by 25 s; a crate untouched; camera, turret, laser and lights off; fail-safe door unlocks, fail-secure stays locked; energy 80 -> 40; the deck unplugged |
| Jamming | field 10 m, 20 s, silent, a blinking cyan beacon; a link with either end inside drops | Wireless devices "Jammed" on the light, frame and Map; cabled ones and a deck on a jack stay online; the deck's Wi-Fi drops; a radio inside gets no dispatch; everything back when it ends |

The debug panel's Spawn tab puts a gas cloud, an EMP or a jamming field at the crosshair.

- **Inventory**: each type is a 1x1 item stacking to 5, put on the belt and equipped like a weapon; the HUD shows how many are left.
- **Chains**: a grenade is a small `Explosive` and `Breakable` like a barrel: shooting a thrown or stuck grenade, or catching it in a blast, sets it off (gas and EMP release their effect, a jammer starts jamming), so grenades and mines chain.

## Throwing and sticking

- **LMB** throws or sticks, depending on what the crosshair is on:
  - within **1.2 m** of a surface (wall, floor, ceiling, door, prop), a **ghost grenade** shows where it would stick; LMB sticks it there. A stuck grenade follows what it is stuck to (a door, a crate);
  - further away, LMB **throws** it in a fixed arc (no preview); distance by Demolition skill (12 / 14 / 16 / 18 m on flat ground).
- A thrown grenade bounces, off characters too (it never sticks to a person), and goes off **2.5 s** after the throw.

## Mines

Every stuck grenade is a proximity mine with its own effect.

- **Arms** 2 s after it is stuck; an armed mine **blinks a small red light**, and the frame within reach shows its name and "Armed" (e.g. "Frag grenade · Armed").
- **Triggers** on any character in its line of sight, the player and its owner included: within **2.5 m** walking or running, within **1 m** crouched. Characters only (props and noises do not trigger it; hostility to the owner waits for factions, M15).
- **Disarming**: crouched, 1 to 2 m from it, E picks it back up with Demolition Trained or better; Untrained, E sets it off after a 0.5 s beep.

## Demolition skill

| Tier | Untrained | Trained | Advanced | Master |
|---|---|---|---|---|
| Throw distance (flat ground) | 12 m | 14 m | 16 m | 18 m |
| Disarm a mine | no (it goes off) | yes | yes | yes |
| Armed mines within 8 m highlighted (through smoke and darkness) | no | no | yes | yes |
| HUD shows a thrown grenade's fuse time left | no | no | no | yes |

Blast strength does not depend on skill.

## Guards

Guards do not react to grenades until the AI overhaul (M16): no fleeing, no throwing. They hear the noises like any other: a bounce (impact noise), the frag's blast, the gas hiss and EMP pop; the jammer is silent.

## Where to try them

- **Shooting range** (hub room 4): a grenade lane with dummies at 2, 4 and 6 m; a mine corridor; an EMP and jamming corner with a wireless camera, a turret and a light.
- **Warehouse**: 2 frag, 1 gas, 1 EMP and 1 jamming grenade placed as loot in plausible spots (the security office, the armoury crate). Guards carry none yet.

## Build order

1. Grenade items, throwing and sticking (the ghost), the proximity-mine trigger, arming, disarming and the red blink, the Demolition skill; in parallel with
2. the four effects as components (frag tuning, gas cloud, EMP with the bioenergy drain, the jammer and the "Jammed" status on the frame, the Map and lights) and their noises;
3. then the range and the warehouse loot.

M14 starts after M13c is merged and playtested.

## Open questions

- Gas masks and EMP-proof gear (later).
- An arc preview for throws, if throws feel random in play.
- Remote charges with a detonator (not in M14).
