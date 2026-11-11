# 77. Devices, cables and remote commands

Status: Accepted

Date: 2026-11-08

## Context

[ADR 0075](0075-alarms-as-network-devices.md) made the alarm a set of network devices reached through powered, unbroken links, with remote commands delivered as stimuli. M8 has to build that contract so the other security devices (doors, keypads in M8; cameras, turrets, terminals later) and M12's logical network can use it, and replace `LevelAlarm`, `RaiseAlarmEffect` and `alarm.raise`.

## Decision

- **Device component** (`objects/devices/device.gd`, `Device`): any entity that carries it is a device; a network switch is just a device with links (`objects/devices/network_switch.tscn`). It mirrors its entity's state into tags: `state.unpowered` while its `Powered` is off, `state.broken` once its `Breakable` is depleted. Device scenes keep the broken husk (`break_on_depleted` off) and hide a few nodes (`broken_hide`). No `Powered`: always powered; no `Breakable`: never broken.
- **Cables** (M8): each device lists the devices it is cabled to (`Device.links`, node paths); links are undirected. **Reach** is pure logic in `DeviceGraph` (a RefCounted, unit-tested): X reaches Y when a path of links joins them whose every node, X, Y and every switch between, is powered and unbroken. The graph is rebuilt from the level for each query (levels have tens of devices). M12 adds addresses, subnets and firewalls on top without changing devices.
- **Remote commands**: a command is a CONTACT stimulus of its type at the target device's entity (`Stimulus.make_contact(type, 1.0, target, source)`), emitted through `StimulusSystem.emit()` only when the sender reaches the target: `Device.send_command(command, target, at)`. Types: `command.open`, `close`, `lock`, `unlock`, `ring`, `silence`, `test`, `disarm`, `reset`, `trigger`, `disable`, `enable`, plus `command.broadcast` (controller to radio base station, origin = the incident). The target's receptrons (`objects/devices/receptrons/`, one per type) run `DeviceActionEffect`, blocked on `state.unpowered` and `state.broken`; it calls `Device.receive_action()`, whose `action_received` signal tells the entity's behaviour components. A device **accepts** a command when one of its receivers has a receptron for that type: `Device.reached(type)` lists the reached devices that accept it, and `send_to_all(type)` sends to them. Nothing branches on what a device is.
- **Incidents**: a sensor reports with `Device.report_incident(at)`: `device.incident` (origin = the incident location) to every device it reaches that accepts it (alarm controllers).
- **Alarm controller** (`AlarmController`): an incident or `command.trigger` rings it for 90 s (another one restarts the time; `AlarmTimer`, saved). While ringing it sends `command.ring` to every device it reaches that accepts it, **again every second**; when it stops it sends `command.silence`. On an incident it sends `command.broadcast` at the incident location to the radio base stations it reaches. `command.reset` stops it. **Disarm**: `command.disarm` (or `command.disable`) stops it and makes it ignore incidents and triggers until `command.enable` re-arms it; a power cycle does not re-arm it. Losing power or breaking stops it.
- **Siren** (`Siren`): `command.ring` makes it sound for 2.5 s (`ring_hold`), `command.test` for 3 s, `command.silence` stops it. Because the controller rings again every second, a siren cut off from its controller (a switch unpowered or broken, the controller dead) falls silent within 2.5 s and one reconnected rings again on the next refresh. While sounding it emits `alarm.siren` every second: loudness 35 along the navmesh like noise, its own type so guards do not ignore it as an ally's noise. Unpowered or broken: silent at once.
- **Hearing a siren**: the `heard_siren` receptron (margin >= 1: up to 34 m of path) runs `HeardAlarmEffect`, which tells the entity's `AlarmHearing` component; it counts as hearing for 1.5 s after the last pulse. A guard's `AlertComms` answers each pulse as it answered the old level alarm (wary 60 s, a search around where it stands when Unaware or Suspicious, reason `alarm`; Searching and Alerted carry on). The player carries the same receptron and component: the HUD shows "ALARM" while the player hears a siren.
- **Radio base station** (`RadioBaseStation`): on `command.broadcast` it emits `alert.dispatch`, a STRAIGHT radius of 40 m from the station whose new `Stimulus.about_point` is the incident. Guards' `heard_dispatch` receptron (requires `equipment.radio`) runs the existing `AwarenessEffect` SEARCH (reason `radio`) at `Stimulus.about()`: they search at the incident. The ally-only `alert.radio` path is not reused: a station is not an ally, and tagging it as one would make guards treat it as a character.
- **Panic button** (`PanicButton`, a `Usable`, "E: press panic button"): reports an incident at the button. Silent.
- **Debug panel**: "Raise alarm" / "Clear alarm" emit `command.trigger` / `command.reset` straight at every alarm controller (group `alarm_controller`), without network reach.

## Alternatives considered

- **Ring once, sound until silenced**: a siren behind a switch cut while ringing would sound for the rest of the alarm, and the controller could never silence it. The refresh costs a few log entries per second.
- **One receptron for all `command.*`**: simpler scenes, but then every device would "accept" every command and the controller could not find its sirens without tags naming device kinds.
- **Guards react to the controller**: bypasses hearing ([ADR 0075](0075-alarms-as-network-devices.md)).
- **A payload dictionary on Stimulus** instead of `about_point`: more general, but nothing else needs it yet.

## Consequences

- `LevelAlarm`, `RaiseAlarmEffect`, `alarm.raise` and `alarm_raise.tres` are gone; `AlarmTimer` moved to `objects/alarm/`.
- Other devices (doors, keypads, cameras, turrets) add a `Device`, receptrons from `objects/devices/receptrons/` (or new ones running `DeviceActionEffect`) and a behaviour component listening to `action_received`.
- The AI arena has a controller, a switch, two sirens, a panic button and a radio base station; shooting the switch cuts the sirens off.
- A device's links are invisible in M8 (no cable meshes).
- Docs: [security](../game/security.md), [perception-and-ai](../game/perception-and-ai.md), [stimulus-response](../game/stimulus-response.md), [debug-panel](../game/debug-panel.md).
