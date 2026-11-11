# 75. Alarms as network devices

Status: Accepted (supersedes the level alarm part of [ADR 0072](0072-shouts-radio-level-alarm.md); shouts and radio stay). Amended by [ADR 0100](0100-laser-arrays-alarm-time-downed-targets.md): the controller rings for 45 s, not 90 s

Date: 2026-11-08

## Context

ADR 0072 made the alarm one `LevelAlarm` node per level: any `alarm.raise` stimulus reaches it anywhere in the level and every guard reacts. Network hacking ([ADR 0074](0074-network-hacking.md)) needs the alarm to be something the player can find, cut off, silence or break: devices on a network, reached through powered, unbroken links.

## Decision

- **Alarm controller** (a device): receives incidents from sensors (cameras, tracers, panic buttons) and sends "ring" to every siren it can reach. Remote actions: disarm, reset, trigger. Its ringing time keeps ADR 0072's alarm timer (90 s, an incident restarts it; saved).
- **Siren** (a device): while rung it emits a loud siren stimulus (its own type, like `alert.shout`, so guards do not ignore it as an ally's noise). Guards who hear it go into Searching around where they stand (reason `alarm`) and stay wary, as with ADR 0072's alarm. Remote actions: silence, test. If every siren is broken, disabled or disconnected, nothing rings.
- **Radio base station** (a device): if the controller reaches it, it broadcasts the incident location; characters tagged `equipment.radio` within its range search there first.
- **Panic button**: the old alarm panel. Using it sends an incident to the controller it reaches.
- **Remote command interface**: a command (ring, open, disable, ...) is a stimulus delivered to the target device; the device's receptrons run the action, blocked while it is unpowered or broken. Any entity with the right receptrons is a device; no command branches on a device's identity.
- **Milestone split** (confirmed when M8 was planned; M8 build: [ADR 0077](0077-devices-cables-and-remote-commands.md)):
  - **M8** builds the alarm controller, sirens and radio base station as devices with the stimulus-based remote command interface, wired by a simple physical link graph: a device reaches another when every link and node between them is powered and unbroken.
  - **M12** replaces plain reachability with the logical network: addresses, subnets and firewall rules ([ADR 0074](0074-network-hacking.md)).
- The HUD "ALARM" label shows while the player can hear a ringing siren. The debug panel's "Raise alarm" and "Clear alarm" trigger and reset the level's alarm controllers.

## Alternatives considered

- **Keep the global LevelAlarm**: nothing for the player to disable; a camera behind a cut switch would still ring every guard in the level.
- **Guards react to the controller directly**: bypasses hearing; a siren in another building would alert guards who cannot hear it.
- **Build the full network in M8**: M8 is already large; physical reachability gives the systemic hooks (power, breaking, links) now and M12 adds addressing on top without changing the devices.

## Consequences

- `LevelAlarm`, `RaiseAlarmEffect` and the level-wide `alarm.raise` go in M8; their tests move to the controller, sirens and base station. The hub's arena gets a controller and sirens.
- Cameras, tracers and panic buttons send incidents, not `alarm.raise` to the whole level.
- Shouts and radio calls between guards (ADR 0072) are unchanged.
- Docs: [security](../game/security.md), [perception-and-ai](../game/perception-and-ai.md), [debug-panel](../game/debug-panel.md), [hacking](../game/hacking.md).
