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
- The game **pauses** (like the Tab interface); **Esc or E** closes the screen.

## What characters carry

- A downed character's **weapon goes into its inventory** instead of dropping as a pickup.
- Guards carry some **ammo** for their weapon; levels set the rest per guard (keycards, keys, medkits, grenades).
- The warehouse moves keycards and keys from tables onto guards where it reads better (the level brief lists each).

## Keychain: keys and keycards

- **Keycards join keys on the keychain**: no grid space, cannot be dropped or thrown, picked up only. The keychain shows a brass **key icon** for keys and a blue **card icon** for keycards, in the Inventory tab and the loot screen.
- Locks read the keychain for both (keycard readers and mechanical locks).

## Out of scope

Pickpocketing a conscious character, guards searching or looting bodies (M16), shops and money (M19).
