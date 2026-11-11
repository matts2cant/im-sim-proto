# 78. Doors, locks as components, and doors on the navmesh

Status: Accepted, amended by [ADR 0110](0110-tab-interface.md) (the keypad screen no longer pauses: the player's input is off instead)

Date: 2026-11-08

## Context

M8 adds doors and their locks ([security.md](../game/security.md)): keypads, mechanical locks (a placeholder until the M10 minigame, [ADR 0073](0073-realistic-lockpicking.md)), keycards, electronic locks that react to power loss, and breakable doors. The device network (built in parallel) sends doors remote commands. Guards must path through doors they may open and not through the others, while noise still passes closed and locked doors with the attenuation of [ADR 0039](0039-path-propagation-sound-attenuators.md). Nothing may branch on a door's or lock's identity.

## Decision

- **The door** is a scene, not a class hierarchy: a `StaticBody3D` on the world layer whose `Panel` shape fills a 1.2 x 2.2 m doorway and slides 1.3 m along +X into the wall in 0.6 s (a pocket door: the open panel hides 5 cm inside the wall), a `Door` component (a `Usable`), `Lockable`, `Tags`, a `StimulusReceiver`, a `SoundAttenuator` over the doorway (enabled while less than half open) and a control panel on each wall face (prompt target while the door is open, red / green light, names of the locks). It blocks bodies and sight while closed because the panel is world geometry. It does not close on a body in the doorway. Saveable (`open`, `broken`).
- **Locks are components.** `Lockable` holds the locked state (saveable) on any entity; each `Lock` component (`KeypadLock`, `MechanicalLock`, `KeycardLock`, `ElectronicLock`) is one way to unlock it, with its data in a Resource (`KeypadLockData`, `MechanicalLockData`, `KeycardLockData`). A door can have several or none; a drawer or locker gets the same components. The door only asks its locks through the `Lock` hooks (prompt, use, reason, passage, tool), never their types. A user who unlocks on purpose (code, card, pick) also opens the door (`Lockable.unlocked_by_user`); power loss and commands unlock without opening.
- **Keypad**: a pause screen on the user (`KeypadScreen`, like the reading overlay, [ADR 0052](0052-inventory-pauses-the-game.md)); digits by keys or clicks, Enter submits, Esc always leaves. It shows the reminder from the user's `PersonalLog` ([ADR 0060](0060-datapads-read-in-place-personal-log.md)). A wrong code beeps (noise 4). Only the code opens it until M12 ([ADR 0076](0076-computer-skill-multitool-removed.md)).
- **Tools**: an `EQUIP_TOOL` item has a `tool_kind` (`lockpick`). A generic `ToolUse` component on the user works the held tool on the target's `Lock` that accepts that kind while the user holds on (the player: LMB held). The M8 placeholder picks in pins x 1 s x `lockpick_time_mult`; letting go loses the progress; success consumes nothing. M10 replaces `MechanicalLock.tool_hold()` without touching doors.
- **Keycards** match the carried card's `key_id` to the reader's `access_id`. A character tagged `access.<id>` has the same access (guards in levels).
- **Electronic locks** unlock on power loss when the entity is tagged `door.fail_safe`; `door.fail_secure` (or neither tag) stays as it is. Power loss is the entity's `Powered` switching off or the entity gaining `state.unpowered`.
- **Remote commands**: every door is a network device (a `Device` in `door.tscn`, [ADR 0077](0077-devices-cables-and-remote-commands.md)); standalone until something is cabled to it. `command.open`, `command.close`, `command.lock`, `command.unlock` (CONTACT stimuli, sent with `Device.send_command()`) reach the shared receptrons `objects/devices/receptrons/command_*.tres` (`blocked_tags` `state.unpowered`, `state.broken`), whose `DeviceActionEffect` emits the Device's `action_received`: the `Door` runs open / close, the `Lockable` lock / unlock (so a locker with a Device and a Lockable takes lock commands too). A remote open is an authorised open: it opens a locked door and leaves it locked (it locks again when closed).
- **Breakable door**: the same scene plus `Breakable` with the `reinforced` material (explosive x1, everything else x0) and health 50, so a blast within about 2 m of the door's centre breaks it and pistols and batons never do. `Breakable.free_entity` off keeps the entity: the door loses its panel for good (`state.broken`).
- **Navigation**: each door carves its doorway out of the navmesh (a `NavigationObstacle3D` with `carve_navigation_mesh`, parsed by `LevelNavigation` through the `navigation_source` group) and bridges it with a `NavigationLink3D` 0.8 m either side. The link is on navigation layer 1 (everyone, `AccessLayers.WALK`) while the door is passable (unlocked, open or broken), else on layer 2 (`LOCKED`) plus one layer per access id its locks let through (`AccessLayers.access_layer()`, a stable hash of the id onto layers 3-32). A `DoorOpener` component puts its character's agent on layer 1 plus the layers of its `access.<id>` tags, and opens a closed door when the next 3.5 m of its path cross the doorway and the door lets it pass. Doors guards open stay open. Noise (PATH stimuli) queries every layer, so it crosses locked doors and the closed door's attenuator adds its 6 m.

## Alternatives considered

- **One door script with lock enums**: every new lock type would edit the door; a locker could not reuse locks.
- **Re-baking the navmesh when a door locks**: a full synchronous bake per change, and noise would lose its path through the doorway.
- **NavigationObstacle3D avoidance or `excluded_regions` per guard**: avoidance does not change paths; region filters would need a region per doorway and per-query lists. Layers on a link are built in and the agent already filters by them.
- **Doors that open themselves for anyone nearby**: guards walking past would open them; the path decides instead.
- **Remote open refused on a locked door**: the network would always have to send unlock then open, and the door would stay unlocked afterwards.

## Consequences

- A door needs about 1.35 m of wall beside the doorway on its +X side for the pocket and 1 m on the -X side for the control panel; rotate the door 180° to swap sides. `Door.wall_thickness` places the control panels on the wall faces (default 0.25 m).
- `Usable` gains `available(user)` and `prompt(user)`; the Interactor uses them (a broken door offers nothing, a locked door says "Locked: keycard"). `Interactor.looked_at` is the entity under the crosshair (ToolUse's target).
- Terminals (wave 2) send the same commands through `Device.send_command()`; a door with a `Powered` is unpowered (`state.unpowered`, mirrored by its Device) when its circuit is off, which also unlocks a fail-safe electronic lock. Levels give guards `access.<id>` tags for the doors they may use.
- Two access ids may share a navigation layer (hash collision): a guard may then plan a path through a door it cannot open, stop there and re-plan. Rare with few ids; a registry can replace the hash if it matters.
