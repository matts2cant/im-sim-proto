# Inventory

Milestone: M5 (Inventory bay). Systems done in M5; the gallery room ([7 Inventory and abilities bay](../levels/hub-and-gallery.md#7-inventory-and-abilities-bay)) and the hub's loadout table (the player starts empty) are built on top of them.

## Purpose

Deus Ex 1 style grid inventory: what you carry is a spatial puzzle, the belt is your quick bar, and everything you drop is a physics object again.

## Player-facing behaviour

- Look at an item within 2 m: the HUD says "E: pick up Multitool (3)". E puts it into the grid; what does not fit stays on the floor ("No room in inventory").
- New weapons, tools and consumables go to the first free belt slot. Keys 1-0 select a slot: a weapon is drawn (again: holstered), a tool goes in hand, a medkit is used at once, a datapad opens for reading, a biocell says "Nothing happens" (until M6).
- Q with something in hand (and nothing carried) drops it in front of you; it falls, makes an impact noise and can be picked up again with the same magazine, key or text.
- I opens the inventory screen and pauses the game: drag items around the grid, onto belt slots, or out of the panel to drop them; right-click for Use / Drop / Split stack / Assign to belt slot; hover for a tooltip.

## Rules

### Items (`items/`)

- `ItemData` Resource per item (`items/<item>/<item>.tres`; the weapons' in `items/weapons/<weapon>/<weapon>_item.tres`): id, display and short name, description, footprint (w x h cells), max stack, graybox icon colour, world scene (a path, to avoid a load cycle with the scene's ItemPickup), `auto_belt`, `default_state`, use action (`NONE`, `EQUIP_WEAPON`, `HEAL`, `READ`, `EQUIP_TOOL`) and its parameters (weapon, heal amount, message).
- `items/item_catalog.tres` (`ItemCatalog`) lists every item; saves store ids and look them up there; the debug panel's "Give item" lists it.
- Instance state lives on the stack (`state` Dictionary): `magazine` (pistol), `key_id` (keycard), `title` and `text` (datapad; M8 codes go here). Items with state have max stack 1 and never merge.
- Icons are generated: a rect of the item's colour, its short name, the count of a stackable or a weapon's rounds. No image assets.

| Item | id | Footprint | Stack | Use (belt key or Use) | Auto-belt | Instance state |
|---|---|---|---|---|---|---|
| Silenced pistol | `pistol` | 2 x 1 | 1 | equip / holster | yes | `magazine` (10 when new) |
| Stun baton | `baton` | 1 x 3 | 1 | equip / holster | yes | |
| Pistol ammo | `pistol_ammo` | 1 x 1 | 100 | none ("Nothing happens") | no | |
| Medkit | `medkit` | 1 x 1 | 15 | heal 30, consumes one; refused when unhurt | yes | |
| Multitool | `multitool` | 1 x 1 | 10 | in hand (used in M8) | yes | |
| Lockpick | `lockpick` | 1 x 1 | 10 | in hand (used in M8) | yes | |
| Bioelectric cell | `biocell` | 1 x 1 | 20 | "Nothing happens" until M6 | yes | |
| Keycard | `keycard` | 1 x 1 | 1 | "Use it on a door" (doors read `key_id` in M8) | no | `key_id` |
| Datapad | `datapad` | 1 x 1 | 1 | read (overlay) | no | `title`, `text` |

### World pickups

- Each item has a world scene: a `PhysicsObject` RigidBody3D on layer 4 (objects) with `continuous_cd`, a graybox mesh at roughly real size, `ImpactNoise` (metal, or cardboard for ammo boxes and keycards), Tags `object.item`, `object.<id>`, `material.*`, and an `ItemPickup` component (item, count, state overrides). `ItemPickup` is saveable (count, state). Level designers set `count` and `state` (e.g. `{"key_id": "office"}`) on placed pickups.
- The M4 world medkit (`objects/medkit/`, E healed on the spot) is gone: `items/medkit/medkit.tscn` is a pickup and E picks it up.

### Grid ([ADR 0050](../decisions/0050-inventory-model-and-belt-references.md))

`Inventory` (`items/inventory/inventory.gd`, pure, unit-tested), 6 x 5 cells (`items/inventory/inventory_config.tres`).

- `add(item, count, state)`: first fills existing stacks of the same item that have room (placement order), then places new stacks at the first free position scanning rows top to bottom, each row left to right, never rotated. Returns what did not fit (0 = all in). A full inventory changes nothing.
- `move(stack, cell)`: only inside the grid and not overlapping another stack; the stack's own old cells do not block it.
- `remove(stack, n)`, `split(stack, n)` (the new stack goes to the first free position; refused without room), `take(id, n)` (empties the smallest stacks first), `count_of(id)`.
- `to_dict()` / `from_dict(data, catalog)`: stacks as `{id, count, state, cell: [x, y]}` (JSON-safe).

### Belt

`Belt` (`items/inventory/belt.gd`, pure): 10 slots, index 0 = key 1 ... index 9 = key 0 (`belt_1` ... `belt_0`).

- Slots reference stacks, never copies; a stack is in at most one slot. Assigning a stack moves it from its old slot. A stack that leaves the grid (used up, dropped) clears its slot.
- `auto_belt` items (weapons, tools, consumables) take the first free slot when a new stack is placed (pickup, Give item, split).
- `selected` is the slot whose item is in hand (highlighted on the HUD), -1 when none. Saved as stack indices.

### Use, hand, ammo (`PlayerInventory`, `items/inventory/player_inventory.gd`)

- Belt key or Use: `EQUIP_WEAPON` draws the weapon through the WeaponHolder (`equip_state`), the same stack again holsters; `EQUIP_TOOL` holds the tool (HUD shows its name; LMB does nothing until M8); a weapon replaces a tool and vice versa. `HEAL` heals the body (`BodyParts.heal`) and consumes one, refused when nothing to heal ("You are not hurt", `item.use_refused`). `READ` opens the reading overlay. `NONE` shows the item's message. An empty slot does nothing.
- Each weapon stack gets a `WeaponState`; its magazine is mirrored into the stack's `magazine` state (after every shot, reload, equip, save and drop). Spare rounds are the inventory's stacks of the weapon's `ammo_item` (`InventoryAmmo`): a reload takes what the magazine needs from the smallest stacks first; the HUD shows "magazine / rounds in the inventory".
- Death puts the weapon or tool away.

### Pickup and interaction ([ADR 0051](../decisions/0051-single-interactor-hud-prompts.md))

- One `Interactor` component on the player casts one ray per physics tick from the eyes, 2.0 m (`interact_reach` in `player_config.tres`), on layers 1, 4 and 5 (world, objects, hitboxes; a hitbox stands for its character), excluding the player and its hitboxes.
- Resolution order: `ItemPickup` ("E: pick up Multitool (3)", count only above 1), `Usable` ("E: reset Training dummy": the usable's verb), `Carryable` within the carry limit ("E: carry Small crate") or above it ("Too heavy"); while carrying: "E: put down Small crate". Names come from the item, else `display_name` metadata, else the node name in words.
- E does what the prompt says. Picking up takes what fits: all of it frees the pickup, part of it leaves the rest with a smaller count ("No room in inventory (30 left behind)"), nothing leaves it untouched ("No room in inventory").

### Drop

- From the inventory screen (Drop in the context menu, or drag out of the panel) or with Q when something is in hand and nothing is carried (Q while carrying keeps its M3 meaning: let go). Drops the whole stack (split first to drop part).
- Spawns the item's world scene 0.8 m ahead (horizontal view direction) at chest height (1.3 m above the feet) with 1.0 m/s forward; if a wall or object is between the eyes and that point, it appears 0.15 m before the hit. It lands with an `object.impact` noise like any physics object.

### Inventory screen ([ADR 0052](../decisions/0052-inventory-pauses-the-game.md))

- `ui/inventory/inventory_screen.tscn` (child of the Player). `inventory` (I) toggles, Esc closes. Opens only when the player can act (alive, conscious, input enabled, debug panel closed). While open the SceneTree is paused (the screen runs with `PROCESS_MODE_ALWAYS`) and the mouse is free; closing restores the previous mouse mode.
- Dark panel, 64 px cells with thin grid lines, items as coloured rects with short name and count; the belt row (56 px slots) under the grid.
- Left-drag: the item follows the mouse; over the grid a green (fits) or red (blocked or out of bounds) footprint shows where it lands; release on the grid moves it, on a belt slot assigns it, outside the panel drops it. Dragging an item out of a belt slot and releasing it anywhere but another slot clears that slot.
- Right-click: Use (Equip / Put away / Read / Use) / Drop / Split stack (half, only for counts above 1) / Assign to belt slot 1-0. Hover: tooltip (name, description, count, magazine, key). Hover + a belt key assigns the item to that slot.
- `PauseScreens` (`ui/inventory/pause_screens.gd`) tracks every open pause screen; the pause ends when the last closes. Closing resyncs the player's held keys so the closing key is not also an in-game press.

### Reading overlay

- `ui/inventory/reading_overlay.tscn` (child of the Player): the datapad's title and text in a panel; pauses like the inventory (it can sit on top of it); E or Esc closes.

### HUD

- Belt: bottom centre, 10 slots (52 px) with the key number, short name and count; the selected slot has a yellow border.
- Prompt under the reticle; messages (2.5 s, fading) above the belt; weapon or tool name and ammo bottom right.

### Saving

- `Player.save_state()` includes `inventory`: `{inventory: Inventory.to_dict(), belt: Belt.to_dict(), in_hand: stack index or -1}`; `load_state` restores it and draws the item that was in hand. M6 wires quicksave.

### EventLog

`item.picked_up {item, count, left}`, `item.pickup_refused {item, count, reason}`, `item.dropped {item, count}`, `item.used {item, action}` (`equip`, `heal` + `amount`, `read`, `nothing`), `item.use_refused {item, reason}`, `debug.gave_item {item, count}`.

```mermaid
flowchart TD
    L["look within 2 m"] --> I{"Interactor: what is it?"}
    I -->|ItemPickup| P["E: pick up"]
    I -->|Usable| U["E: use"]
    I -->|Carryable| C["E: carry / Too heavy"]
    P --> A["Inventory.add: merge into stacks, then first free cell"]
    A -->|nothing fits| R["No room in inventory, item stays"]
    A -->|part fits| S["rest stays on the floor"]
    A -->|placed| B{"auto_belt?"}
    B -->|yes| BS["first free belt slot"]
    B -->|no| G["grid only"]
    BS --> K["belt key 1-0"]
    G --> M["inventory screen: Use / drag to belt"]
    K --> X{"use action"}
    M --> X
    X -->|EQUIP_WEAPON| W["WeaponHolder.equip_state; again: holster"]
    X -->|EQUIP_TOOL| T["tool in hand"]
    X -->|HEAL| H["heal 30, remove 1"]
    X -->|READ| D["reading overlay"]
    X -->|NONE| N["message"]
    W --> Q["Q / Drop"]
    T --> Q
    M --> Q
    Q --> O["world pickup 0.8 m ahead, impact noise"]
    O --> L
```

## Interactions

- Dropped items are physics objects: [objects-and-fire.md](objects-and-fire.md)
- Medkits: [damage.md](damage.md); biocells: [abilities.md](abilities.md); multitools, lockpicks, keycards: [security.md](security.md); weapons and ammo: [weapons-and-aiming.md](weapons-and-aiming.md)
- Controls: [controls.md](controls.md); debug Give item: [debug-panel.md](debug-panel.md); saving: [saving.md](saving.md)

## Open questions

- Rotation stays parked ([../backlog.md](../backlog.md)).
- Dropping part of a stack takes a Split first; DX1 drops one at a time. Revisit after playtests.
- Picking up a second pistol makes a second 2 x 1 stack (no ammo is stripped from it as DX1 does).
- Keycards may move to a keyring (no grid space) once M8 doors use them.
