# Looting

Milestone: M14d ([ADR 0142](../decisions/0142-looting-and-the-keychain.md)). Builds on the character-agnostic `Inventory` ([ADR 0139](../decisions/0139-generic-inventory-and-interaction.md)), the keychain ([inventory.md](inventory.md#keychain)) and the Tab interface. Approved mockup: [looting.html](../prototypes/looting.html).

## Purpose

Downed characters and containers hold items the player can take, and the player can put items into them. Keys and keycards found on guards open doors and bays, so looting a guard becomes a way through a level, as in Deus Ex.

## What can be looted

- **Any downed character with an `Inventory`** (unconscious or dead): guards today, any character later.
- **Containers**: objects with an `Inventory` (crates, lockers, desks, cabinets). A container is a prop scene that composes an `Inventory`; no container-specific code. A container may be locked (a `Lockable` with its locks: key, keycard, lockpick), and opens for looting once unlocked.

## Opening

- **E** on a downed character or an unlocked container opens the loot screen. On a downed character, **holding E** for 0.5 s carries the body instead (today E carries).
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

## Out of scope

Pickpocketing a conscious character, guards searching or looting bodies (M16), shops and money (M19).
