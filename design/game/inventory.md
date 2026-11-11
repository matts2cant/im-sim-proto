# Inventory

Milestone: M5 (Inventory bay). Systems done in M5; the gallery room ([7 Inventory and abilities bay](../levels/hub-and-gallery.md#7-inventory-and-abilities-bay)) and the hub's loadout table (the player starts empty) are built on top of them.

## Purpose

Deus Ex 1 style grid inventory: what you carry is a spatial puzzle, the belt is your quick bar, and everything you drop is a physics object again.

## Player-facing behaviour

- Look at an item within 2 m: the HUD says "E: pick up Lockpick (3)". E puts it into the grid; what does not fit stays on the floor ("No room in inventory").
- New weapons, tools and consumables go to the first free belt slot. Keys 1-0 or the mouse wheel select a slot and put its item in hand, nothing more: a weapon is drawn, anything else is held; the same key again, or H, puts it away ([ADR 0059](../decisions/0059-belt-selects-lmb-uses.md)). The wheel steps to the next / previous non-empty slot (down = right), wrapping; from empty hands down takes the first item, up the last.
- LMB uses the item in hand: a weapon fires, a medkit heals (one per click, it stays in hand until the last is used), a biocell restores 25 energy (refused with "Energy full" at full energy, M6), a tool is worked by holding LMB on what you look at (a lockpick on a mechanical lock: hold until it opens, M8 placeholder; [ADR 0078](../decisions/0078-doors-locks-and-door-navigation.md)).
- Q with something in hand (and nothing carried) drops it in front of you; it falls, makes an impact noise and can be picked up again with the same magazine or key.
- Datapads are not items: they are read in place (E) and what they say goes to the personal log (L), see [Datapads and the personal log](#datapads-and-the-personal-log).
- I opens the Tab interface on its Inventory tab ([ADR 0110](../decisions/0110-tab-interface.md)); the game keeps running: drag items around the grid, onto belt slots, or out of the grid to drop them; click one for its details and actions (Use or Equip, Drop, belt slot); right-click for Use / Drop / Split stack / Assign to belt slot; hover for a tooltip.
- Drag a silencer and every weapon it fits lights up (grid and belt); drop it on one to fit it for good ([Attachments](#attachments), [ADR 0085](../decisions/0085-weapons-and-attachments.md)).

## Rules

### Items (`items/`)

- `ItemData` Resource per item (`items/<item>/<item>.tres`; the weapons' in `items/weapons/<weapon>/<weapon>_item.tres`): id, display and short name, description, footprint (w x h cells), max stack, graybox icon colour, world scene (a path, to avoid a load cycle with the scene's ItemPickup), `auto_belt`, `default_state`, use action (`NONE`, `EQUIP_WEAPON`, `CONSUME`, `EQUIP_TOOL`) and its parameters (weapon; `tool_kind` for tools (M8: `lockpick`; a Lock accepts the kinds that work it); `use_stimuli`, `use_scale_attribute` and `refused_message` for consumables; the `NONE` message). `use_scale_attribute` (M6) names an attribute of the user that scales every use stimulus on emit (`Stimulus.scale_attribute`, [ADR 0061](../decisions/0061-abilities-model.md)): the medkit's `medical_heal_mult` is the Medicine skill.
- `items/item_catalog.tres` (`ItemCatalog`) lists every item; saves store ids and look them up there; the debug panel's "Give item" lists it.
- Instance state lives on the stack (`state` Dictionary): `magazine` (weapons), `key_id` (keycard), `attachments` (weapons, {slot: item id}). Items with state have max stack 1 and never merge.
- Icons are generated: a rect of the item's colour, its short name, the count of a stackable or a weapon's rounds. No image assets.
- Ammo boxes are their weapon's colour, in the world (the box material) and on the icon (`ItemData.colour`, [ADR 0101](../decisions/0101-rifles-and-sniper-skills.md)): pistol ammo red, shotgun shells yellow, rifle rounds green, sniper rounds purple.

| Item | id | Footprint | Stack | Use (LMB in hand, or Use) | Auto-belt | Instance state |
|---|---|---|---|---|---|---|
| Pistol | `pistol` | 2 x 1 | 1 | equip / holster | yes | `magazine` (10 when new), `attachments` |
| Stun baton | `baton` | 1 x 3 | 1 | equip / holster | yes | |
| Pistol ammo | `pistol_ammo` | 1 x 1 | 100 | none ("Nothing happens") | no | |
| Shotgun (ADR 0085) | `shotgun` | 3 x 1 | 1 | equip / holster | yes | `magazine` (6) |
| Sniper rifle | `sniper_rifle` | 4 x 1 | 1 | equip / holster | yes | `magazine` (5), `attachments` |
| Assault rifle | `assault_rifle` | 2 x 2 | 1 | equip / holster | yes | `magazine` (30), `attachments` |
| Shotgun shells | `shotgun_shells` | 1 x 1 | 48 | none | no | |
| Sniper rounds | `sniper_rounds` | 1 x 1 | 30 | none | no | |
| Rifle rounds | `rifle_rounds` | 1 x 1 | 150 | none | no | |
| Silencer | `silencer` | 1 x 1 | 1 | none ("Drag it onto a weapon in the inventory (I) to fit it"); dragged onto a weapon whose slots take it in the Inventory tab: fitted and used up | no | |
| Medkit | `medkit` | 1 x 1 | 15 | heal 30 x the user's `medical_heal_mult` (Medicine), consumes one; refused when unhurt | yes | |
| Lockpick | `lockpick` | 1 x 1 | 10 | in hand, `tool_kind` `lockpick`: LMB on a mechanical lock starts the [lockpicking minigame](lockpicking.md) (M10); a broken pick uses one up (`PlayerInventory.use_up_tool()`: from the stack in hand first, another stays in hand while any is left), success consumes nothing; loadout economy to retune | yes | |
| Bioelectric cell | `biocell` | 1 x 1 | 20 | `energy` 25 to the user, consumes one; refused ("Energy full") at full energy ([abilities.md](abilities.md)) | yes | |
| Keycard | `keycard` | 1 x 1 | 1 | "Use it on a door": carried, it opens keycard readers whose `access_id` is its `key_id` (E on the door, M8) | no | `key_id` |
| Deck (M12) | `deck` | 2 x 1 | 1 | in hand: LMB on a wall jack, maintenance port or computer plugs it in; within an access point's range LMB raises it for wireless ([hacking.md](hacking.md)) | yes | copied files, Icebreaker progress per account |

- The multitool was removed in M8 ([ADR 0076](../decisions/0076-computer-skill-multitool-removed.md)): keypads take their code, network locks are hacked with the deck (M12). It is gone from the catalogue, the hub's loadout table and the inventory bay.
- Footprints of the ADR 0085 weapons were chosen so the hub's starting kit (pistol, silencer, baton, ammo, medkits, lockpicks, biocells: 10 cells) and the whole shooting range rack (shotgun 3, sniper rifle 4, assault rifle 4, three ammo boxes, the second silencer: 15 cells) fit the 6 x 5 grid together in pickup order (`tests/levels/gallery/shooting_range/shooting_range_rack_test.gd`).
- The deck is one model with no upgrades. Its contents live in its stack's `state`, so they travel with it when dropped and are saved with the inventory. Credentials and exploits are knowledge, kept in the PersonalLog, not on the deck.

### World pickups

- Each item has a world scene: a `PhysicsObject` RigidBody3D on layer 4 (objects) with `continuous_cd`, a graybox mesh at roughly real size (weapons: their `WeaponModel` from the Kenney Blaster Kit lying on its side, which shows fitted attachments; the silencer: the kit's small crate), `ImpactNoise` (metal, or cardboard for ammo boxes and keycards), Tags `object.item`, `object.<id>`, `material.*`, and an `ItemPickup` component (item, count, state overrides). `ItemPickup` is saveable (count, state). Level designers set `count` and `state` (e.g. `{"key_id": "office"}`) on placed pickups.
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
- `next_filled(from, step)`: the next non-empty slot from `from` towards `step` (> 0 right, < 0 left), wrapping; from -1 the first (step > 0) or last (step < 0) non-empty slot; `from` itself when it is the only item, -1 when the belt is empty. The mouse wheel uses it.

### Use, hand, ammo (`PlayerInventory`, `items/inventory/player_inventory.gd`)

- In hand ([ADR 0059](../decisions/0059-belt-selects-lmb-uses.md)): `select_slot` (belt key) and `cycle` (wheel) call `hold(stack)`: an `EQUIP_WEAPON` item is drawn through the WeaponHolder (`equip_state`), any other item becomes `held`; either replaces what was in hand. The same belt key again, H (`holster` action) and death call `put_away()`. `use_held()` (LMB, when nothing is carried) uses the held item as below, except a tool: while LMB is held, the player's `ToolUse` works the tool (`held_tool()`, its `tool_kind`) on the looked-at entity's `Lock` that accepts it ([ADR 0078](../decisions/0078-doors-locks-and-door-navigation.md)); with a weapon or nothing in hand LMB goes to the WeaponHolder.
- Use (LMB on a held item, or the Inventory tab's Use): `EQUIP_WEAPON` / `EQUIP_TOOL` (screen only) toggle the item in hand; a tool in hand shows its name; holding LMB works it (see above). `CONSUME` ([ADR 0057](../decisions/0057-forces-item-use-and-heat-as-generic-systems.md)): the item's `use_stimuli` (type -> intensity; medkit `{heal: 30}`) go to the player as CONTACT stimuli with the player as source, delivered at once (`StimulusSystem.emit_now`; the world keeps running while the Tab interface is open), and one is consumed; the player's receptrons decide what they do (the `heal` receptron -> `HealEffect` -> `BodyParts.heal`). Refused, item kept, when none of them would do anything to the player (`StimulusSystem.would_affect` dry run: a medkit when unhurt or dead): the item's `refused_message` ("You are not hurt") and `item.use_refused {item, reason: no_effect}`. Logged `item.used {item, action: consume, stimuli}`; the heal itself logs `actor.healed` (source: the player). `EQUIP_WEAPON` and `EQUIP_TOOL` stay inventory verbs: they change what is in hand and nothing in the world could react to them. `NONE` shows the item's message. An empty slot does nothing.
- Each weapon stack gets a `WeaponState`; its magazine is mirrored into the stack's `magazine` state (after every shot, reload, equip, save and drop). Spare rounds are the inventory's stacks of the weapon's `ammo_item` (`InventoryAmmo`): a reload takes what the magazine needs from the smallest stacks first; the HUD shows "magazine / rounds in the inventory".
- Death puts the item in hand away.

### Pickup and interaction ([ADR 0051](../decisions/0051-single-interactor-hud-prompts.md))

- One `Interactor` component on the player casts one ray per physics tick from the eyes, 2.0 m (`interact_reach` in `player_config.tres`), on layers 1, 4 and 5 (world, objects, hitboxes; a hitbox stands for its character), excluding the player and its hitboxes.
- Resolution order: `ItemPickup` ("E: pick up Lockpick (3)", count only above 1), `Usable` ("E: reset Training dummy": the usable's verb; a `Readable` names its title: "E: read Storage access"; a usable may write the whole prompt, `Usable.prompt(user)`: a door says "E: open" or "Locked: keycard", and may be unavailable, `Usable.available(user)`: a broken door offers nothing), `Carryable` within the carry limit ("E: carry Small crate") or above it ("Too heavy"); while carrying: "E: put down Small crate". Names come from the item, else `Usable.target_name()`, else `display_name` metadata, else the node name in words.
- E does what the prompt says. Picking up takes what fits: all of it frees the pickup, part of it leaves the rest with a smaller count ("No room in inventory (30 left behind)"), nothing leaves it untouched ("No room in inventory").

### Drop

- From the Inventory tab (its Drop button, Drop in the context menu, or drag out of the grid view) or with Q when something is in hand and nothing is carried (Q while carrying keeps its M3 meaning: let go). Drops the whole stack (split first to drop part).
- **Weapon drops** (M9, [ADR 0088](../decisions/0088-weapon-drops-and-bursts.md)): a character that goes down (knocked out or killed: `state.unconscious` / `state.dead`, any source) drops the weapons its WeaponHolder owns (a guard's fixed loadout) as pickups of their items (`WeaponData.item_id`; the guards' pistol is a `pistol`) 0.6 m to the body's right at 0.4 m height (left, or at its feet, when a wall is in the way), each with the rounds left in its magazine (`state.magazine`). The character no longer has them, also once woken. The player's weapons belong to its inventory, not to its holder: a knocked-out or dead player keeps them. Dropped weapons are saved as spawned pickups. EventLog `weapon.dropped {actor, weapon, item, magazine}`.
- Spawns the item's world scene 0.8 m ahead (horizontal view direction) at chest height (1.3 m above the feet) with 1.0 m/s forward; if a wall or object is between the eyes and that point, it appears 0.15 m before the hit. It lands with an `object.impact` noise like any physics object.

### Inventory tab ([ADR 0110](../decisions/0110-tab-interface.md))

- The first tab of the Tab interface (`ui/tab_interface/`, child of the Player; it replaced the M5 inventory screen and ADR 0052's pause): I opens it (or switches to it; again: closes), Tab opens the interface on the last tab used. The world keeps running; the player's input is off and the mouse is free while it is open (opening and closing rules: [controls.md](controls.md)).
- Left: the grid view (`InventoryView`: 64 px cells with thin grid lines, items as coloured rects with short name and count; the belt row, 40 px slots, under the grid) and a placeholder Credits box (money arrives in M19).
- Right: the selected stack (a click selects it, amber outline; on opening, the item in hand or else the first stack): its icon, name and count, description, details and actions. Details (`ItemDetails`, all from the item's data, its `WeaponData` and the player's components, never per item): a weapon's damage (each damage stimulus times the player's `<attribute_class>_damage_mult`), magazine current / max, ammo item and how many are carried, how far a shot is heard (the `fire_noise` stat with attachments), each attachment slot (what is fitted, or what fits) and its skill; a consumable's use stimuli times its `use_scale_attribute` and its skill; a tool's skill; the count of a stackable item; a keycard's key; the weapons an attachment fits. The skill is the one whose effects write the attribute that scales the item (`<attribute_class>_*`, `<tool_kind>_*` or the `use_scale_attribute`), with the player's tier. Weapons that take rounds show a placeholder "Ammo types come later". Actions: Use (consumables) or Equip / Put away (weapons, tools), Drop, and a belt-slot picker ("Not on the belt", Belt 1 ... 0). Items with nothing to use (ammo, keycards) have no Use button. Messages ("You are not hurt") show under the Credits box for a moment.
- Left-drag: the item follows the mouse; over the grid a green (fits) or red (blocked or out of bounds) footprint shows where it lands; release on the grid moves it, on a belt slot assigns it, outside the grid view drops it. Dragging an item out of a belt slot and releasing it anywhere but another slot clears that slot. Dragging an attachment highlights the weapons it fits; releasing it on one fits it ([Attachments](#attachments)).
- Right-click: Use (Equip / Put away / Use) / Drop / Split stack (half, only for counts above 1) / Assign to belt slot 1-0. Hover: tooltip (name with fitted attachments, description, count, magazine, key, "Fitted: ..."; an attachment adds "Drag onto a weapon to fit it (for good)."). The number keys select tabs while the interface is open, so hover + a belt key no longer assigns (the details' belt picker does).
- Closing the interface resyncs the player's held keys so the closing key is not also an in-game press.

### Attachments

[ADR 0085](../decisions/0085-weapons-and-attachments.md). An attachment is an item with an `AttachmentData` (`ItemData.attachment`): the slot it takes (`muzzle`), `Modifier`s on the weapon's stats, a label ("silenced", "SIL" on the icon), a model and its length. The silencer is the only one in v0.

- Compatibility is data: a weapon item's `WeaponData.attachment_slots` lists the slots it takes (pistol, sniper rifle, assault rifle: `muzzle`; shotgun: none), one attachment per slot (`Attachments.can_attach`, pure).
- In the Inventory tab, while an attachment is dragged, every stack it fits is highlighted in blue, on the grid and on the belt (`InventoryView.attach_targets()`). Dropping it on one (grid cell or belt slot) calls `PlayerInventory.attach(attachment, weapon)`: the weapon's state records it (`attachments: {"muzzle": "silencer"}`), its `WeaponState` applies the modifiers, one attachment is used up, `item.attached {item, weapon}` is logged and "Silencer fitted: Pistol (silenced)" shows. Dropped anywhere else (an incompatible item, an empty cell, a belt slot of a weapon it does not fit, outside the grid view) it behaves as a normal move, belt assignment or drop.
- **It never comes off.** It stays through save/load (the state is saved with the inventory) and drop/pick-up (the pickup keeps the state and shows the silencer on its model).
- Names say it: the tooltip title, the HUD's weapon and item names and the pickup prompt read "Pistol (silenced)"; the tooltip adds "Fitted: silenced"; the icon shows "SIL" top right.

### Datapads and the personal log

[ADR 0060](../decisions/0060-datapads-read-in-place-personal-log.md).

- A datapad (`objects/datapad/datapad.tscn`) is a physics prop, not an item: blasts and the player push it, it makes impact noise, it can never enter the inventory (and is not carried: E reads it). Its `Readable` component holds `entry_id` (stable, unique: `<level>.<room>.<name>`), `title`, `text`, `codes` (keypad code id -> code) and `source` ("Datapad"). Any entity with a `Readable` reads the same way.
- Look at it within 2 m: "E: read Storage access". E opens the reading overlay and passes the entry to the player's `PersonalLog` (`actors/common/personal_log/`, any actor can have one): a new `entry_id` is added (HUD "Added to log: Storage access", EventLog `log.entry_added {entry_id, title, codes}`) and its codes become known; reading it again only shows it.
- Known codes: the last entry added wins a shared code id. M8 keypads ask `PersonalLog.known_code(code_id)` and `code_source(code_id)` ([security.md](security.md)).
- Reading overlay (`ui/log/reading_overlay.tscn`, child of the Player): the entry's title and text in a panel, shown on every read; the world keeps running (the player's input is off and the mouse free, [ADR 0110](../decisions/0110-tab-interface.md)); E or Esc closes (that E is not also an in-game press); being knocked out or killed closes it.
- Journal tab of the Tab interface (`ui/tab_interface/tabs/journal_tab.gd`; it replaced the log screen): L (`personal_log`) opens it, again closes it. Three sections: **Objectives** (the level's Mission: its title, a short briefing line, primary and secondary objectives with their state, live as they complete; outside a mission it says there is none), **Codes and logins** (every code the log knows: what it opens, the code or "user / password", and a link to the entry it came from), **Notes** (every entry, newest first, and a reader with its title, source, text and "Learned: ...").
- What a code opens is data: `Readable.code_labels` (code id -> "Manager's office door") next to `codes`, copied into the entry (`LogEntry.code_labels`); a code without a label shows its id in words.
- Saving: `PersonalLog` is in group `saveable` (`save_state()`: `{entries: [{entry_id, title, text, source, codes, code_labels}]}`); codes are rebuilt from the entries on load.

### HUD

- Belt: bottom centre, 10 slots (52 px) with the key number, short name and count; the selected slot has a yellow border.
- The name of the item put in hand shows just above the belt for `InventoryConfig.item_name_time` (1.5 s, fading over its last half); holstering hides it at once.
- Prompt under the reticle; messages (2.5 s, fading) above the item name; the name of the item in hand and ammo bottom right.

### Saving

- `Player.save_state()` includes `inventory`: `{inventory: Inventory.to_dict(), belt: Belt.to_dict(), in_hand: stack index or -1}`; `load_state` restores it and puts the item that was in hand back in hand (never uses it). M6 wires quicksave.

### EventLog

`item.picked_up {item, count, left}`, `item.pickup_refused {item, count, reason}`, `item.dropped {item, count}`, `item.attached {item, weapon}`, `item.used {item, action}` (`equip` for every item put in hand, `consume` + `stimuli`, `nothing`), `item.use_refused {item, reason}`, `debug.gave_item {item, count}`; reading: `log.entry_added {entry_id, title, codes}`.

```mermaid
flowchart TD
    L["look within 2 m"] --> I{"Interactor: what is it?"}
    I -->|ItemPickup| P["E: pick up"]
    I -->|Usable| U["E: use"]
    I -->|Readable| RD["E: read: overlay + personal log (L)"]
    I -->|Carryable| C["E: carry / Too heavy"]
    P --> A["Inventory.add: merge into stacks, then first free cell"]
    A -->|nothing fits| R["No room in inventory, item stays"]
    A -->|part fits| S["rest stays on the floor"]
    A -->|placed| B{"auto_belt?"}
    B -->|yes| BS["first free belt slot"]
    B -->|no| G["grid only"]
    BS --> K["belt key 1-0 / mouse wheel"]
    G --> M["Inventory tab: Use / drag to belt"]
    K --> HD["in hand (H or the key again: put away)"]
    HD -->|LMB| X{"use action"}
    M --> X
    X -->|EQUIP_WEAPON| W["WeaponHolder.equip_state; again: holster"]
    X -->|EQUIP_TOOL| T["tool in hand"]
    X -->|CONSUME| H["heal 30 CONTACT on the player, remove 1"]
    X -->|NONE| N["message"]
    W --> Q["Q / Drop"]
    T --> Q
    M --> Q
    Q --> O["world pickup 0.8 m ahead, impact noise"]
    O --> L
```

## Interactions

- Dropped items are physics objects: [objects-and-fire.md](objects-and-fire.md)
- Medkits: [damage.md](damage.md); biocells: [abilities.md](abilities.md); lockpicks, keycards: [security.md](security.md); the deck: [hacking.md](hacking.md); weapons and ammo: [weapons-and-aiming.md](weapons-and-aiming.md)
- Controls: [controls.md](controls.md); debug Give item: [debug-panel.md](debug-panel.md); saving: [saving.md](saving.md)

## Open questions

- Rotation stays parked ([../backlog.md](../backlog.md)).
- Dropping part of a stack takes a Split first; DX1 drops one at a time. Revisit after playtests.
- Picking up a second pistol makes a second 2 x 1 stack (no ammo is stripped from it as DX1 does).
- Attachments cannot be removed (user decision, ADR 0085); revisit if more attachment kinds arrive.
- Keycards may move to a keyring (no grid space) now that M8 doors use them.
