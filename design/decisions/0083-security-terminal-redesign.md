# 83. Security terminal redesign: Camera and Network tabs, device status, Esc only

Status: Superseded by [ADR 0114](0114-computers-halcyon-os.md) (the Camera tab became the Security app; the map moves to the deck). Was: Accepted (amends [ADR 0080](0080-credentials-terminal.md)); the Network tab's floor-plan layout is superseded by [ADR 0099](0099-network-map-layout-pan-zoom.md)

Date: 2026-11-08

## Context

After the M8 playtest the user found the terminal's flat device list too rough. They asked for a Camera tab (a list of cameras and turrets, the selected device's point of view, its actions below), a Network tab (a graph of the security network with selectable nodes and a small action menu), each device's status on both (online, offline, enabled, disabled, active, ringing, ...), no "broken" status (from a terminal a broken device is just not connected: offline), Esc as the only way out of computer-like screens (the "E: leave (when not typing)" rule made no sense), and the two wall devices in the D3 booth made identifiable.

The terminal must still not know device types ([ADR 0080](0080-credentials-terminal.md), AGENTS.md "Systemic design"): cameras, turrets, doors and anything later must show their status and view through properties.

## Decision

- **Status is a component query** (`objects/devices/device_status.gd`, `DeviceStatus`). Any behaviour component on a device's entity (a direct child) may implement `device_status() -> PackedStringArray`, its state in words. `DeviceStatus.of(entity, online)` gives `["offline"]` when the terminal does not reach the device, else `["online"]` followed by every component's words in tree order (duplicates dropped). Offline covers unpowered, broken and a dead switch on the way alike; no component ever says "broken". Words today: camera enabled / disabled, sweeping / holding, suspicious / alert; turret enabled / disabled, "targets <preset>", idle / tracking (winding up) / firing; alarm controller armed / disarmed, ringing / silent; siren ringing / silent; door open / closed; `Lockable` locked / unlocked; radio base station broadcasting (for `broadcast_shown`, 3 s, after a dispatch) / idle; terminal logged in / logged out; a switch or panic button is just online.
- **A view is a property too**: a component implementing `device_view() -> Node3D` gives the device a view (`DeviceStatus.has_view()`); it returns the node it sees from (its -Z is the view direction), or null while it sees nothing. The security camera and the turret return their PerceptionSensor's eye node while watching / active.
- **`Terminal.devices()`** replaces `listing()`: every device on the terminal's physical network (new `DeviceGraph.component()`: joined by cables, up or down), its own row first, then breadth-first. Each `Terminal.Row` has the device, its name, `online` (the terminal reaches it), `status` (DeviceStatus words), `has_view`, `is_self`, and, only while online, the table's commands it accepts. `Terminal.cables(rows)` gives the links between them. `Terminal.state_name()` and the online / unpowered / broken constants are gone.
- **Screen** (`ui/terminal/terminal_screen.gd`): the login view is unchanged; logged in, two tabs.
  - **Camera** (default): left, every device with a view and its status words; right, the selected device's live point of view: a 480 x 270 `SubViewport` sharing the level's world, its `Camera3D` (fov 70) moved onto the device's view node every frame, shown at 576 x 324. It renders (`UPDATE_ALWAYS`) only while the Camera tab shows a device whose view is not null; otherwise it is disabled and the frame reads "No signal". Below: the device's status and one button per command.
  - **Network** (`ui/terminal/network_graph.gd`, `NetworkGraph`): one node per device, placed by `NetworkLayout` (`ui/terminal/network_layout.gd`, pure): the devices' world x / z seen from above (north up), fitted to the panel, each axis stretched at most twice the other, nodes closer than 84 px pushed apart. Cables are arcs (solid between two online devices, dashed otherwise) bowing toward the panel's centre, longer ones further, so cables along one wall stay apart. The terminal's node has a thick blue outline. Each node shows its name and its status words (offline grey, words such as ringing, alert, firing in red). Clicking a node opens a small menu under it with its status and command buttons (none while offline: "No connection."); clicking the background closes it.
  - Offline devices stay on both tabs, greyed with no commands, so the player sees what was cut.
  - Refreshed on open, after each command and every `refresh_interval` (now 0.25 s); widgets are rebuilt only when a row's status, state or commands changed.
- **Esc only**: Esc leaves the terminal screen, the keypad screen and any later computer-like screen, every time, also while typing. E never leaves them (it does nothing there). The hint reads "Esc: leave".
- **Network debug overlay** (developer view, asked for with the redesign): the debug panel's Overlays tab has a "Network" checkbox driving `NetworkOverlay` (`ui/debug_panel/network_overlay.gd`, `DebugPanel.network_overlay`). On, every `Device` in the level gets a label (name and `DeviceStatus` words; when down, the reason in brackets: unpowered, broken) and every cable a line, green while both ends are up, red otherwise, drawn through walls. It reuses `DeviceStatus` and `Device.linked()`; off, it holds nothing and does not process.
- **Booth signs**: in the security wing's D3 booth a SMALL kit `Sign` sits above the alarm controller ("Alarm controller") and above the radio base station ("Radio base station"). The device scenes are painted apart: the alarm controller's box dark red, the radio base station's dark blue.

## Alternatives considered

- **A status table in the terminal keyed by device type** ("cameras show sweeping"): identity code; a new device would need terminal changes.
- **Reading status from tags** (`state.*`): only the Device's power and broken tags exist; behaviour state (armed, ringing, preset) lives in components, and adding tags for every display word would make tags a UI channel.
- **Using the PerceptionSensor as the view property**: works for today's devices, but ties "has a picture" to "perceives"; `device_view()` lets a future device show a view without perception (or perceive without a camera).
- **A pure force-directed graph layout**: tidier for large networks but loses the floor-plan reading the user asked for; the floor plan plus push-apart keeps devices where they are in the level.
- **Rendering the feed continuously**: a second 3D render every frame while the terminal is open even on the Network tab; rendering only when shown keeps the cost to one small view.

## Consequences

- A new device shows a status and, with a view node, appears on the Camera tab with no terminal change: implement `device_status()` / `device_view()` on its behaviour component.
- Pause behaviour is unchanged (the terminal keeps the game running; the keypad pauses); the user has not decided yet.
- [ADR 0080](0080-credentials-terminal.md)'s "E leaves only when no text field has focus" and "Device view" bullets are superseded by this ADR, and so is [ADR 0074](0074-network-hacking.md)'s E rule for M12 computers.
- Tests: `tests/objects/devices/device_status_test.gd` (stand-in components), `tests/objects/devices/device_graph_test.gd` (component), `tests/ui/terminal/network_layout_test.gd`, `tests/objects/terminal/terminal_test.gd` (devices, statuses, offline never broken), `tests/ui/terminal/terminal_screen_test.gd` (Camera tab feed and No signal, Network tab nodes, cables and menu commands, cut switch, Esc / E), `tests/objects/door/door_player_test.gd` (E does not leave the keypad), `tests/ui/debug_panel/network_overlay_test.gd` (labels, cables up and down, off draws nothing), `tests/levels/gallery/security_wing/security_wing_test.gd` (booth signs).
- See [security](../game/security.md), [controls](../game/controls.md).
