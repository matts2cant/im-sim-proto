# 122. Network readability: status lights, gear plates, the deck's AR cable view, the drop line

Status: Accepted (builds the readability half of [ADR 0115](0115-m12b-intrusion-and-m12c-consequences.md)'s M12c)

Date: 2026-11-12

## Context

ADR 0115 settled that the network must read in the world, not only on the deck's Map: one LED colour language on every device, plates on network gear naming what it feeds, closets with one look, an AR view of the cables generated from the link data (no cables modelled in levels), and a HUD line after an action that takes devices off the network. This ADR records how they are built and the rules they follow.

## Decision

- **Status lights** (`StatusLight`, `objects/devices/status_light.gd`): every `Device` attaches one to its entity (deferred from `Device._ready`, after the level's cables are in) when it is on a network: a cable either way, a holding wireless link or wireless clients, or an access point named. A standalone device (no cables: a maintenance port) shows none; `Device.status_light` off opts out. Colours: green steady up and on its network; amber blinking powered but cut off (none of the network gear it links to is up; linked to no gear: none of its links); red broken but powered, or switched off by a command (`DeviceStatus.is_disabled()`); dark unpowered. Network gear (`DeviceNetwork.is_network_gear()`) also shows one port light per cabled link (8, then "+"), green while the gear and the far end are up. Placement: optional `StatusLedMarker` / `PortLightsMarker` children (the laser array and access point have them), else the top-front of the entity's visible bounds (+Z is the front). Refreshed only on signals (the device's and its links' state, power, breakage and commands); the blink is a shader with per-instance parameters (one shared material). The gear scenes lost their decorative indicator strips.
- **Gear plates** (`GearPlate`, `objects/network/gear_plate.gd`): a Label3D on network gear generated from the links, "SW-VAULT · feeds DOOR-VAULT, TUR-VAULT, CAM-OFFICE" (4 names, then "+N"), shown on two lines under the gear on the wall plane (lower under deep gear). A router feeds all its links; other gear all but the routers (its uplink). Names are the screens' names (`NetworkSource.display_name()`).
- **Closets** share one kit part, `levels/kit/network_panel.tscn` (`NetworkPanel`): a painted wall panel with a stripe in its subnet's Map colour and "NETWORK" on it, visual only, 2 mm off the wall. Placed behind the warehouse's basement network closet and the security wing's network wall.
- **The deck's AR cable view** (`DeckArView`, `items/deck/deck_ar_view.gd`, a Player component): with the deck in hand, RMB (`alt_fire`) toggles it; putting the deck away, being unable to act or opening any screen (the player's input off) turns it off; the world keeps running and the HUD shows "AR: cables (RMB)". It draws the links between devices the held deck has seen (its stack's `seen` list, both ends seen) within 30 m (either end), at most 200: cables as ceiling runs (up, across under the ceiling over the end nearer the player, a ray up else 3 m, down) in the subnet's colour, wireless links as dashed light-blue lines, down links dim, no depth test. Rebuilt on toggle, on the deck's map changes, on a drawn device's state change and every 4 m the player moves.
- **The drop line** (`NetworkFeedback` on the HUD, `NetworkDrops` for the logic): when a device goes down and takes others off the network, the HUD message line shows "SW-VAULT down: 5 devices offline (CAM-OFFICE, DOOR-VAULT, +3)" for 4 s. Offline: the up devices joined through it split into pieces once it is down (cables and wireless links, routers' rules ignored); the one largest piece of two or more stays the network, the others are offline. Only for drops within 30 m of the player or caused by the player (MissionTally's attribution of breakage, or a breaker the player switched off in the same tick). The level's starting state (first frames) never shows a line.

## Consequences

- No per-level work: a new networked device or a new level gets lights, plates and AR runs from its link data. Placement markers are optional.
- The LED's amber rule is local (its own links) while the drop line counts whole pieces: a router going down blinks only the switches behind it but the line names every device behind them.
- The AR runs cross floors and walls (no depth test, the brief's "drawn on top"); runs between floors rise on the player's side.
- Physics cost: none per frame (signal-driven); measured in the warehouse within noise (see the M12c report).
