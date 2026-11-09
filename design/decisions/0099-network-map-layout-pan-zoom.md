# 99. Network map: devices grouped by hub, pan and zoom

Status: Accepted (amends [ADR 0083](0083-security-terminal-redesign.md) and the network graph part of [ADR 0092](0092-warehouse-polish.md))

Date: 2026-11-09

## Context

After the M9 playtest the user found the terminal's Network tab unreadable once many devices are shown: the floor-plan projection of ADR 0083 squeezed the warehouse console's 29 devices (two switches) into the panel, and pushing label boxes apart (ADR 0092) kept them from overlapping but scattered them and tangled the cables. They asked for a readable graph and allowed a map that pans and zooms, so it can take all the space it needs.

The terminal must still not know device types (ADR 0080, AGENTS.md "Systemic design"): a later device (a laser array, an access point) must place itself without layout code.

## Decision

- **Groups by cables, not by type** (`ui/terminal/network_layout.gd`, `NetworkLayout`, pure). A device with 3 or more cables is a hub (a switch today, but only its cables say so). Every other device joins the hub fewest cables away (breadth-first from all hubs at once; the earlier hub on a tie) and hangs on the device it was reached from. A network without such a device takes the device with the most cables as its hub (the office PCs' wall jack); a part that reaches no hub starts its own group the same way.
- **A group is a comb**: the hub on top, a bus down from it, its devices in two columns either side (the west half on the left, the east half on the right, each column north first, so the map keeps a little of the floor plan). Boxes are aligned on the bus side (text right-aligned on the left column, left-aligned on the right), 8 px apart, 28 px from the bus. A device hanging on another device sits one column further out, from its parent's row (an indented tree). Column widths are rounded up to 24 px and the group's extent comes from those columns, so a status change within a step moves nothing.
- **Groups stand in rows** 96 px apart, top-aligned; the row count is the one whose fitted zoom is largest for the panel's aspect (fewest rows on a tie). Groups go north to south into rows and west to east within a row.
- **Cable routes**: a cable to a hanging device runs down its bus and across to the box (no two cross); neighbouring hubs in a row are joined by a straight line; any other cable between groups runs up to a lane above its row (from a hub's top, or through the gap beside its group when it starts in another row or on a device that is not a hub), along the lane and down, each cable on its own lane 8 px apart. Cables inside a group that are not on its tree are straight. Solid between two online devices, dashed otherwise (dashed ones drawn first, so a live bus stays solid).
- **Pan and zoom** (`ui/terminal/network_view.gd`, `NetworkView`, pure): content point × zoom + offset. Drag (left or middle button, past 4 px) pans; the wheel zooms by 1.15 per notch around the cursor (trackpad pan and pinch gestures too); zoom stays within 0.35 (or the fitted zoom, when the network needs less) and 2.5; panning and zooming keep at least 80 px of the network in the panel. Fit (the Fit button in the map's corner, or F by physical key on the Network tab) shows the whole network centred, never zoomed in past 1.0. The map opens fitted every time the screen opens; refreshes keep the view. Text stays sharp when zoomed (Godot scales the font with the Control).
- **Graph** (`ui/terminal/network_graph.gd`): the nodes and cables live in a `Content` child moved and scaled by the view; its size covers everything it draws (a Control is culled by its own rect). Node buttons pass mouse events on, so a drag that starts on a node pans and the wheel over a node zooms; a click is a press and release without a drag. The menu and the Fit button stay in the panel, unscaled. The menu sits beside its node, slid inside the panel: on the node's outer side (away from its bus, where the column has no neighbours), else below, above, the bus side (a hub: below, right, left, above), the first that does not cover the node; it follows the node when the view moves. Esc still only leaves; the screen keeps the game running.
- **Hint**: on the Network tab the screen's hint reads "Esc: leave · Drag: move the map · Wheel: zoom · F: fit".
- **Debug network overlay** (ADR 0083) is unchanged: it draws over the 3D world and shares none of this.

## Alternatives considered

- **Keep the floor plan and push boxes apart** (ADR 0083, 0092): unreadable past about 20 devices: boxes leave their spot, cables cross everywhere.
- **A ring of devices around each hub**: wide labels need a huge ring (a 16-device switch about 1100 px across), the centre stays empty and fitted labels become tiny.
- **A force-directed layout**: not deterministic without care, slow to settle for 60 nodes in GDScript, and still crosses cables; the comb has no crossings by construction.
- **Scaling fonts instead of the Control** (re-laying out per zoom): font metrics do not scale linearly, so boxes could overlap at some zooms; Godot 4.7 oversamples fonts under a Control scale, so scaled text stays sharp.
- **Several buses per group** to make tall groups wider: no better fitted zoom for the test networks, and more cable corners.

## Consequences

- The warehouse console fits at about 0.85 zoom (two combs side by side), the gallery's security wing at about 1.0; the 60-device test network fits at about 0.45, where labels are small: the player zooms in. Labels are readable at the warehouse's fitted zoom.
- A new device places itself from its cables: nothing in the layout knows what it is. A device hanging on another (a radio base station behind an alarm controller) shows as a deeper column.
- The node box is a little tighter (6 / 3 px margins, cable end 12 px below the box's top).
- Tests: `tests/ui/terminal/network_layout_test.gd` (grouping, columns, deeper columns, hubless and split networks, lanes, rows, determinism, stable columns, crossing counts), `tests/ui/terminal/network_view_test.gd` (fit, zoom around the cursor, limits, pan clamp, resize), `tests/ui/terminal/network_graph_test.gd` (the synthetic 60-device network `tests/ui/terminal/fixtures/synthetic_network.gd`; real mouse events: click after pan and zoom, drag, wheel; menu inside the panel; Fit), `tests/ui/terminal/network_map_checks.gd` (shared readability checks: no box overlaps, no crossings, no cable under a box, content rect, fitted view shows every node, deterministic) run on the warehouse console (`tests/levels/mission/warehouse_security_network_test.gd`), the gallery's security wing (`tests/levels/gallery/security_wing/security_wing_devices_test.gd`) and the synthetic network; `tests/ui/terminal/terminal_screen_test.gd` (opens fitted, F fits again, Esc leaves from the map).
- Review shots: `warehouse_shots.tscn -- shots=terminal_network,terminal_network_zoom,terminal_network_menu`, `wing_shots.tscn -- shot=laser_terminal`, `tests/ui/terminal/fixtures/network_map_shots.tscn -- out=<png> [zoom=<factor>] [select=<name>]`.
- See [security](../game/security.md#terminal-m8-placeholder), [controls](../game/controls.md).

## Amendment: node colours (M9h)

Date: 2026-11-09

The user asked for disabled devices to show red and unpowered or unreachable ones grey on the network graph.

- **A disabled flag on the status contract** (`DeviceStatus`, ADR 0083): a component that a command can switch off implements `device_disabled() -> bool` (`SecurityCamera`, `Turret` and `LaserArray` while `disabled`, `AlarmController` while disarmed by `command.disarm` or `command.disable`). `DeviceStatus.is_disabled(entity)` is true when any direct child says so; a device without such a component (switch, siren, door, panic button) is never disabled. `Terminal.devices()` sets `Row.disabled` only for devices it reaches. Nothing reads status words or device types for this.
- **Colours** (`TerminalStyle.row_color()`, also used by the Camera tab): grey `#575C5C` (`OFFLINE_COLOR`) when the terminal cannot reach the device: unpowered, broken or behind a dead switch, all "offline" (ADR 0083); red `#FF6157` (`DISABLED_COLOR`) when reachable and disabled; amber `#FFB840` (`ALERT_COLOR`, was red) while an alert word shows; else green `#73F299` (`ONLINE_COLOR`). Grey beats red: the terminal cannot see the state of a device it cannot reach. Relative luminance is about 0.10, 0.31 and 0.70, so grey, red and green also read apart without hue (under protanopia and deuteranopia simulations they stay at about 0.10 / 0.21-0.36 / 0.66-0.77).
- **Node boxes**: the outline and the status line take the colour; a disabled node's box is also tinted red (`DISABLED_FILL`), a second cue beside the outline. The selected node keeps its white outline on a lighter box (`SELECTED_FILL`), readable on every colour.
- **Cables**: dashed grey when an end is offline (unchanged; the grey is the new, darker one). A cable between two reachable devices stays solid green even when one end is disabled: the cable shows whether the link works, and it does: commands still reach the device (the player re-enables it through it). A red cable would read as a cut link.
- **Alert words are amber**: red now means disabled, and an alerting device is always enabled.

Alternatives: a reserved status word "disabled" (the alarm controller says "disarmed", and colours would hang on wording); per-device checks in the UI (breaks the systemic rule); red cables to disabled devices (suggests the link is down).

Tests: `tests/ui/terminal/network_graph_colours_test.gd` (stand-in devices behind a powered and an unpowered switch: enabled green, disabled red, broken grey, behind the unpowered switch grey even when disabled; menu and selection colours; cable colours; brightness contrast between the three), `tests/objects/devices/device_status_test.gd` (`is_disabled`), `tests/ui/terminal/terminal_screen_test.gd` (the showcase's disabled camera and turret red, grey once the switch is cut, red again after), `tests/objects/laser/laser_array_test.gd` and `tests/objects/alarm/alarm_devices_test.gd` (the flag follows disable / disarm). Review shots: `warehouse_shots.tscn -- shots=terminal_network_states,terminal_network_states_menu` (breaker A off, Camera Hall disabled), `wing_shots.tscn -- shot=terminal_states`.
