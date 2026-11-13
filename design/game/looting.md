# Looting

Milestone: M14d ([ADR 0142](../decisions/0142-looting-and-the-keychain.md)). Builds on the character-agnostic `Inventory` ([ADR 0139](../decisions/0139-generic-inventory-and-interaction.md)), the keychain ([inventory.md](inventory.md#keychain)) and the Tab interface. Approved mockup: [looting.html](../prototypes/looting.html).

## Purpose

Downed characters and containers hold items the player can take, and the player can put items into them. Keys and keycards found on guards open doors and bays, so looting a guard becomes a way through a level, as in Deus Ex.

## What can be looted

- **Any downed character with an `Inventory`** (unconscious or dead): guards today, any character later.
- **Containers**: objects with an `Inventory` (crates, lockers, desks, cabinets). A container is a prop scene that composes an `Inventory`; no container-specific code. A container may be locked (a `Lockable` with its locks: key, keycard, lockpick), and opens for looting once unlocked.

## Opening

- **E** (a tap) on a downed character or an unlocked container opens the loot screen. On a downed character, **holding E** for 0.5 s carries the body instead (before M14d, E carried).
- The interaction frame shows the name and the state ("Guard · Unconscious", "Locker · Locked · key or lockpick").

## The loot screen

- The other inventory (body or container) on the left, yours on the right; each side shows its grid and its keychain.
- **Drag** items between the two grids, both ways (planting items is allowed). A drop outline shows green where the item's footprint fits and red where it does not. Double-click or Enter moves an item to the first free spot on the other side. Ammo merges into existing stacks.
- **Take all** takes every item that fits and every key and card; a short message says what did not fit.
- **Keychain**: clicking a key or card on the other side moves it to yours.
- The game **pauses** (a real pause, unlike the Tab interface, which keeps the world running); **Esc or E** closes the screen.

### As built (M14d screen)

- `ui/loot/`: `LootScreen` (a `UserScreen` answering to `"loot"`, `Lootable.SCREEN`; the player's `Screens` instance `loot_screen.tscn` on first use), `LootGrid` (one side's grid), `LootDrag` (the drag both grids draw from), `LootKeyRow` (a keychain row), `LootRules` (the moves, testable without the screen). The subject is any entity with an `Inventory` (a `Keychain` optional); the screen never asks what it is.
- **Header**: "Search", the subject's line (`EntityNames.display_name()` and, for a character, the interaction frame's state word in lower case: "Guard · unconscious"; a container just "Locker"), **Take all** (amber; greyed when the subject holds nothing) and the close button. Each side: a caption (the subject's name in capitals, "YOU"), its grid, and its keychain column ("No keys or cards" when empty). Footer: the controls line and the latest notice (amber, 2.5 s).
- **Look**: the Tab interface's (`tab_theme.tres`: `TabPanel`, `TabButtonPrimary`, `TabClose`, the new `TabKeyButton`), over the dimmed world; panel 86 % of the screen; grid cells up to 48 px (the mockup's 52 px at 1280 wide), smaller for a grid larger than 6 x 7.
- **Drag**: press on a stack and release over a cell; the footprint is placed by the cell grabbed (as in the Inventory tab). The grid under the mouse shows the footprint (green fits, red not) and the item's ghost; the stack dims on its own grid. Into the other side a stackable item fills that side's stacks of the same item first and the rest lands on the cell; a drop fits when the footprint is free there or the stacks there take all of it (dropping ammo on your ammo merges). A refused drop changes nothing. Within one side the stack just moves.
- **Quick move**: double-click a stack, or click it (it is outlined) and press Enter: the first free spot on the other side, stacks of the same item first; what does not fit stays ("No room").
- **Take all**: each stack as a quick move, then every key and card; the notice is "Took everything" or "No room for: Stun baton, ...".
- **Keys**: clicking a row on the subject's keychain moves it to yours ("Keycard added to the keychain: Security room" / "Key added to the keychain: ..."); a key you already hold stays. Clicking one of yours says "Keys and cards stay on your keychain". The key's tooltip is where it was found.
- **Pause and focus**: a `PauseScreens` screen (the tree pauses, the mouse is free) that also holds the user's `OverlayFocus` (input off, HUD hidden); the user's notices show in the footer while it is open. It closes on Esc, E (`use`), the close button, or when the subject or user is gone or the user can no longer act.
- A moved stack keeps its state: a weapon's loaded rounds (`Inventory.state_of()`) and fitted attachments.

## What characters carry

- A downed character's **weapon goes into its inventory** instead of dropping as a pickup.
- Guards carry some **ammo** for their weapon; levels set the rest per guard (keycards, keys, medkits, grenades).
- The warehouse moves keycards and keys from tables onto guards where it reads better (the level brief lists each).

## Keychain: keys and keycards

- **Keycards join keys on the keychain**: no grid space, cannot be dropped or thrown, picked up only. The keychain shows a brass **key icon** for keys and a blue **card icon** for keycards, in the Inventory tab and the loot screen (`KeyIcon`, by the entry's `kind`: `&"key"` or `&"card"`; an entry without one is a key).
- Locks read the keychain for both (keycard readers and mechanical locks).

### As built (M14d systems)

- **`Lootable`** (`items/inventory/lootable.gd`, a `Usable`, `Lootable.of(entity)`, `Lootable.SCREEN = &"loot"`): on any entity with an `Inventory` (a `Keychain` optional). `can_loot(user)`: the entity has an Inventory, the user has one and is not the entity, a character (it has `BodyParts`) is down (`ActorState.can_act()` false: unconscious or dead; anything else at any time), and its `Lockable` is not locked. E (`use()`) opens `Screens.open(user, Lootable.SCREEN, entity)`, logged `loot.opened {entity, by}`. While locked, E first tries the entity's locks like a door's (`Lock.use_locked()`: a key on the user's keychain unlocks a `MechanicalLock`, a keycard grants a `KeycardLock`'s opening) and opens the screen when one lets the user in; else "Locked: needs a key or a lockpick" (the Usable's refusal). A lockpick works the lock through ToolUse as on any lock; once picked, E opens it. The frame's lock line and name come from the existing frame rules ("Locker" / "Locked · lockpick"; "Guard" / "Unconscious").
- **Offered only with a loot screen**: the Interactor offers a Lootable to a user that has the screen (`Screens.has(user, Lootable.SCREEN)`); for any other user (an AI, a character without the UI) a downed body is carried on the press as before. Any character can loot through `can_loot()` and the `Inventory` / `Keychain` API; the screen is the player's UI.
- **Hold E** (`Interactor`, [ADR 0142](../decisions/0142-looting-and-the-keychain.md#as-built-m14d-systems)): a target the Interactor would use and that the carrier could also carry (usable + an offered `Carryable`: a downed guard, a carryable container) has a hold action, `Interactor.hold_kind` (CARRY, or TOO_HEAVY). The controller calls `press()` on the key's press edge and `step_hold(held, delta)` every tick: released before `InteractorConfig.hold_time` (0.5 s) it does the tap (`perform()`: loot), held that long it carries (`perform_hold()`), looking away (the target changes) cancels. Targets without a hold action act on the press, as before. `hold_progress()` (0..1) is there for a future HUD ring (none yet).
- **Containers** (`objects/containers/`): `supply_crate.tscn` (wood, 1.0 x 0.61 x 0.6 m, grid 6 x 4, no lock), `locker.tscn` (metal, 0.6 x 1.9 x 0.5 m, grid 6 x 5, a `Lockable` locked by default with a 3-pin `MechanicalLock` and a keyhole on its door), `desk_drawers.tscn` (0.54 x 0.75 x 0.64 m, grid 6 x 3, an unlocked `Lockable` and a 3-pin `MechanicalLock` on the top drawer). Each is a `StaticBody3D` on the world layer (mask 0) with `display_name` metadata, Tags (`object.container`, `material.*`), `Inventory`, `Keychain`, an `ItemLoadout` (`Loadout`) and `Lootable`; no container code. A level sets the contents in `Loadout.items` and a key in the lock's data (`key_id`); front is +Z.
- **`ItemLoadout`** (`items/inventory/item_loadout.gd`, `ItemLoadout.of()`): what an entity carries at the start, as data. `items: Array[StartingItem]` (moved to `items/inventory/starting_item.gd`, shared with the mission kit; keys and keycards go onto the Keychain through `Inventory.add()`), `weapon_ammo` rounds of each fixed-loadout weapon's ammo item (`holder_path` to its `WeaponHolder`). Filled once, when it is ready (its Inventory is an earlier sibling; else deferred), so before `WeaponDrop` can empty the holder; saved (`filled`), the Inventory and Keychain save their own contents. What does not fit is left out with a warning.
- **Guards** (`actors/guard/guard.tscn`): `Inventory` (6 x 5), `Keychain`, `Lootable` and a `Loadout` with `weapon_ammo = 10` (pistol guards: 10 pistol rounds; SMG and rifle guards: 10 of theirs). Levels add `items` per guard instance.
- **Weapons on downing** (`WeaponDrop`): each fixed-loadout weapon goes into the character's own Inventory as its item with its magazine (`weapon.stowed {actor, weapon, item, magazine}`); a character without an Inventory, or without room, drops it beside the body as before (`weapon.dropped`). A woken guard stays unarmed (it does not re-arm from its inventory).
- **Keychain** (`Keychain`): entries are `{id, name, found, kind}`, `kind` `Keychain.KEY` or `Keychain.CARD` (from `ItemData.keychain_kind`); `add(key_id, key_name, found = "", kind = KEY) -> bool`, `remove(key_id) -> Dictionary` (the entry, `{}` when not held; `keychain.key_removed`), `has_key(key_id, kind = &"")` (a kind restricts the match). Saves keep the kind; entries saved before kinds load as keys. `Keychain.added_message(kind, name)` is the pick-up notice ("Keycard added to the keychain: ...").
- **Keycards** (`items/keycard/keycard.tres`): `keychain = true`, `keychain_kind = &"card"`, state `key_id` and `key_name`. A `KeycardLock` reads the user's keychain for a card of its access id (`has_key(id, CARD)`), a `MechanicalLock` for a key (`has_key(id, KEY)`): a card never turns a keyhole. `Inventory.key_ids()` and `LockRules.key_matches()` are gone. The level keycards got a `key_name` ("Security keycard", "Vault keycard", "Security booth keycard", "Inventory bay keycard").

## Out of scope

Pickpocketing a conscious character, guards searching or looting bodies (M16), shops and money (M19).
