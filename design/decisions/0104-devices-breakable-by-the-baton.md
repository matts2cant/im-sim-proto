# 104. Security devices are electronics: the baton breaks them; the turret is armoured

Status: Accepted (amends the device materials of [ADR 0075](0075-alarms-as-network-devices.md) and [ADR 0079](0079-security-cameras-and-turret.md))

Date: 2026-11-09

## Context

User request: "We should make sure the devices are breakable by the baton." The baton's hit is `damage.stun` 20 + `damage.blunt` 5 CONTACT on what its sweep touches; objects take no stun, so only the blunt 5 times the material's multiplier counts. Cameras, laser arrays and terminals were already `electronics` (blunt x4: 20 a hit, one hit), but sirens, alarm controllers, panic buttons, radio base stations, network switches and the turret were `metal` (blunt x0.5: 2.5 a hit). Measured with the player's baton through the real melee path (`tests/objects/devices/baton_devices_test.gd`), before:

| Device | Material | Health | Per hit | Hits |
|---|---|---|---|---|
| Camera, laser array, terminal | electronics | 20 | 20 | 1 |
| Siren | metal | 20 | 2.5 | 8 |
| Panic button | metal | 10 | 2.5 | 4 |
| Alarm controller, radio base station | metal | 30 | 2.5 | 12 |
| Network switch | metal | 40 | 2.5 | 16 |
| Turret | metal | 60 | 2.5 | 24 |
| Lamps (wall, ceiling, flood) | glass | 1 | 5 | 1 |

The sweep already hit every device: devices are static bodies on the world layer, which `WEAPON_MASK` includes, and the CONTACT reaches the entity's `take_damage` receptron through `StimulusSystem`'s ancestor lookup (the laser array's heads, receivers and mast are shapes of its one body). Nothing about the swing needed to change.

## Decision

- **Every wall device is `material.electronics`** (`objects/materials/electronics.tres`): sirens, alarm controllers, panic buttons, radio base stations and network switches join cameras, laser arrays and terminals. Health is unchanged, so baton hits are health / 20: siren and panic button 1, alarm controller, radio base station and network switch 2. Electronics and metal differ only in blunt (x4 against x0.5), so bullets, fire and blasts do exactly what they did (a pistol round still breaks a 20-health device, two a switch).
- **The turret is armoured**: a new material `objects/materials/armoured.tres` (blunt x2, half of electronics; fire and stun x0; ballistic and explosive x1; metal sounds, tag `material.metal`). 10 a baton hit against its 60 health: 6 hits, 3.6 s of swinging. It is meant to be clubbed from behind (it sees ±60 degrees ahead) or while disabled, not from the front. Pistol rounds are unchanged (three).
- **Lamps stay glass** (health 1, one hit of anything).
- **Door wall boxes stay part of the door**: they have no health of their own; a hit on one reaches the door's receivers, which have no damage receptron (a plain door) or take no ballistic or blunt damage (the breakable door's `reinforced`). Bullets and the baton cannot open, unlock or break a door through its boxes. Unchanged.
- **The swing** is unchanged: a 0.2 m sphere swept along the view until its front is 1.8 m from the eye (1.65 m up standing), world, objects and hitboxes, the user's body and hitboxes excluded, no areas.

## Consequences

- The baton is a quiet way to kill a device: a swing is a 3 m noise, a hit 6 m at the device, and a device keeps its husk without a break noise; a pistol round is 25 m. Breaking works through the same Breakable, `state.broken`, `device.state` and "offline" on terminals as a shot.
- Thrown props hurt wall devices more: `ImpactNoise`'s `damage.blunt` (kinetic energy / 40) is now x4 on them (a small crate thrown at 10 m/s, about 12 blunt, breaks a siren or a switch) and x2 on the turret (about five such throws).
- Reach, measured: standing about 0.6 m from a wall, a wall device whose underside is up to about 3.4 m high (1.0 m away: about 3.2 m); straight up about 3.45 m; a jumping swing at the apex reaches about 4.3 m. Pressed flat against the wall, the sphere scrapes the wall above about 3.0 m: step back. Which level devices need a climb is listed in [security.md](../game/security.md#breaking-devices); no device was moved (the user decides).
