# 98. Door lock hardware where it belongs, keycards needed every time

Status: Accepted (amends [ADR 0078](0078-doors-locks-and-door-navigation.md), [ADR 0090](0090-door-size-free-side-locks-warehouse-security.md) and [ADR 0092](0092-warehouse-polish.md))

Date: 2026-11-09

## Context

M9h playtest feedback on doors, with the user's decisions:

1. A door's locks sat on a small yellow control panel beside the door, one per face, whatever the lock: a keyhole on a wall panel makes no sense. Pin locks go on the door leaf (a keyhole and a handle at handle height, on both faces, moving with the leaf); keypads and keycard readers become their own small boxes on the wall beside the frame, one on each side of the wall; the yellow panel goes away. The player works what they look at: E on the leaf opens or closes it and the pin lock is picked there; E on a keypad box enters the code; E on a reader box uses the card. The hardware comes from the door scene and its settings, never placed per level, and doors of every size place it sensibly.
2. A keycard door unlocked once stayed unlocked for good. It must lock again when it closes (it does not close by itself; the player or a guard closes it), so opening it again needs the card, except from its free side; guards with the access still open it. Keypads stay as they are: the right code unlocks for good.

The leaf of a pocket door slides wholly into the wall (its 5 cm overlap included): with the panels gone, an open door had nothing left to look at to close it.

## Decision

- **Where a lock's hardware goes is a property of the lock** (`Lock.mount()`, `Lock.hardware()`): `Mount.LEAF` (a fitting on the leaf: `MechanicalLock`, `objects/locks/hardware/keyhole.tscn`), `Mount.WALL` (its own wall box: `KeypadLock` `keypad_box.tscn`, `KeycardLock` `card_reader_box.tscn`), `Mount.INDICATOR` (only the lock light on the wall boxes, its own box when the door has none: `ElectronicLock` `status_box.tscn`). Wall box scenes are StaticBody3D with a `Shape` box (origin on the back face, +Z out) and a `Light` mesh; a new lock type brings its own scene, the door needs no change.
- **The door builds its hardware** (`DoorHardware`, the `Hardware` node of `door.tscn`, at `_ready` and again when a lock is added later) and **`DoorLayout`** (pure) places it from `DoorSettings` and the door's wall:
  - A **handle** on the leaf's leading edge (the edge facing away from `travel`), 1.0 m up, 0.36 m tall, 2.5 cm proud of both faces, on every door. A leaf that slides into its wall (`DoorLayout.in_wall()`: the leaf and handle fit inside `wall_thickness`) carries the handle 0.12 m past its edge: closed, that part hides in the jamb; open, it stands 7 cm out of the jamb, so E on it closes the door. A gate outside its wall line keeps it on the leaf (the open leaf is in view). A rising leaf (roller door) has a bar 0.3 m up instead.
  - **Leaf fittings** (keyholes) on both faces of the handle; the pin lock is picked by looking at the leaf, from either face.
  - **Wall boxes** on both wall faces, on the side away from the pocket, centred 0.17 m from the doorway edge (a box up to 0.12 m wide clears the leaf's 5 cm overlap and fits a 0.3 m gate post), top box at 1.35 m, stacked downward 6 cm apart. One per WALL lock, else the first INDICATOR lock's, else a plain control box (`door_control_box.tscn`) when `DoorSettings.wall_control` (on for the roller door, whose leaf rises out of reach). `Door.front_side_wall` / `back_side_wall` hang a face's boxes on a short corridor's side wall facing across it, 0.4 m from the door's wall face (ADR 0092's rule, now for boxes).
  - Each lock is placed on its hardware (front box face or keyhole): its noises come from there.
- **The light**: every wall box shows red while the door is closed and locked, green while it is unlocked or open, dark while broken or unpowered.
- **Interaction**: each wall box has a `DoorControl` (a Usable) working the door through its own lock: `Door.prompt_via()` / `use_via()` with that lock. E on the leaf uses the leaf locks. "E: close" while open, "E: open" while unlocked or from a free side, else the lock's offer ("E: enter code", "E: open (keycard)", "Picking 40%" on the leaf), else "Locked: <every lock's reason>" (so the leaf of a keypad door says "Locked: keypad").
- **A keycard grants an opening, it does not unlock**: `Lock.grant_for()` / `Lockable.grant()` (EventLog `lock.granted {entity, how}`, signal `access_granted`): the door opens and stays locked, like a free-side or remote open, so it is locked again once closed. Nothing has to remember a pending relock: open and locked are the saved `Door.open` and `Lockable.locked`. Guards with the access open it the same way (`Door.open_for`). A remote `command.unlock` and keypad codes still unlock for good.
- **Levels place no lock hardware**: lock nodes carry no transform (the gallery's security wing, the door showcase, `warehouse_security.py`, which also drops the "side the key is used from").

## Consequences

- The yellow panel's `ControlFront` / `ControlBack` nodes and `Door.SIDE_PANEL_DEPTH` are gone; tests and helpers use `door.hardware.controls(front)` and `door.hardware.handle_point(front)` (`warehouse_route_hands.use_door()` takes the box on the player's side, else the handle).
- Tests: `door_layout_test` (unit), `door_hardware_placement_test` (every preset in its wall: flush on a wall surface, uncovered, clear of the sweep; the checks catch a floating and a buried box), `door_hardware_player_test` (E on each box and the leaf, picking from both faces, keypad stays unlocked), `keycard_relock_test` (relock, save/load, free side), a guard relock test in `door_navigation_test`, and level-wide checks of every door in the warehouse and the security wing (`door_hardware_checks.gd`).
- An open pocket door narrows its doorway by 7 cm at handle height (0.82 to 1.18 m): a 0.35 m capsule on the centre line clears it by 0.18 m.

## Alternatives considered

- **A plain open/close box on every door**: the user wants the leaf to be the door's handle; only a leaf that rises out of reach gets one (`wall_control`).
- **An invisible interaction volume at the jamb of an open door**: works, but nothing shows the player where to look; the handle standing out of the jamb is visible.
- **Relocking on close** (unlock on swipe, lock again when it closes): needs a saved "relock pending" state and lets the door read "unlocked" while it stands open; a granted opening is the free side's and the remote open's existing rule.
- **Wall boxes for electronic locks next to a reader**: two boxes per face for one door; the reader carries the light instead.
- **Picking from the wall box**: the user's decision puts the keyhole on the leaf.
