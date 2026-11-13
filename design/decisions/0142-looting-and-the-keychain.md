# 142. Looting bodies and containers; keycards on the keychain (M14d)

Status: Accepted

Date: 2026-11-13

## Context

With the character-agnostic `Inventory` (ADR 0139) any character or object can hold items. The user asked for a looting screen before M15: a downed guard's inventory beside the player's, items dragged between the two, and keycards added to the keychain next to physical keys. Decided in a design review; the mockup [looting.html](../prototypes/looting.html) was approved.

## Decision

The full specification is [looting.md](../game/looting.md):
- downed characters and containers (objects composing an `Inventory`, optionally locked) are looted through one screen;
- E opens it (holding E carries a downed body);
- side-by-side grids with drag both ways (footprint check, planting allowed), double-click or Enter quick move, Take all, keychains on both sides moved with a click; the game pauses; Esc or E closes;
- a downed character's weapon goes into its inventory instead of dropping; guards carry ammo, and levels give them keys, keycards and other items;
- keycards move to the keychain with keys (no grid space, cannot be dropped), shown with a card icon versus a key icon; locks read the keychain for both.

## Alternatives considered

- **Bodies only**: containers come for free with the same screen and make level loot more natural.
- **E carries, another key loots** / **a Carry button in the screen**: holding E to carry keeps one key for both.
- **Weapons dropped on the floor as today**: one place to find a guard's gear.
- **Keycards stay in the grid**: they are keys in all but form.

## Consequences

- New: the loot screen (a Screens id), container props, the keychain card icon, guard loadouts as data, carrying moved to hold E.
- The weapon drop on downing changes; tests of drops follow.
- The warehouse moves some keys and keycards onto guards.

## As built (M14d screen)

Details in [looting.md](../game/looting.md#as-built-m14d-screen).
- **The screen** is `ui/loot/`: `LootScreen` (a `UserScreen` for id `"loot"`, registered in the player's `Screens` scenes), two `LootGrid`s sharing a `LootDrag`, and `LootRules` for every move (drop with the footprint check, merging stackable items into the other side's stacks first, quick move, Take all, keys). The subject is any entity with an `Inventory`; its line comes from `EntityNames` and the interaction frame's state word.
- **It pauses for real** (user-approved in the design review): it is a `PauseScreens` screen, like the game menu, and also holds the user's `OverlayFocus` so the HUD hides; the Tab interface, which the spec compared it to, keeps the world running (ADR 0110). Notices show in the screen's footer while it is open.
- **Moving a stack keeps its state**: `Inventory.state_of(stack)` (new) gives a copy with the weapon's loaded rounds synced.
- **Keychain kinds**: `KeyIcon` (`ui/inventory/`) draws a brass key or a blue card by the entry's `kind`, in the loot screen and the Inventory tab's `KeychainList`; `Keychain.KEY` / `CARD` name the kinds (moved there from `LootRules` at the merge), and an entry without one is a key. Moving a key goes through `LootRules.move_key()`: `Keychain.remove(key_id) -> Dictionary` and `Keychain.add(key_id, key_name, found, kind)`. `LootScreen` answers to `Lootable.SCREEN`.
- **Look**: the Tab interface's theme with one new variation (`TabKeyButton`, a clickable keychain row); grid cells up to 48 px at 1152 wide.

## As built (M14d systems)

Details in [looting.md](../game/looting.md#as-built-m14d-systems).
- **`Lootable` is a `Usable`** (`items/inventory/lootable.gd`): the Interactor, the frame's name and lock line and E's "Locked: needs ..." refusal work for it as for a door, with no new Interactor kind. `can_loot(user)` is decided by properties: a character (it has `BodyParts`) only while down, anything else always, never while its `Lockable` is locked; while locked, E tries the entity's locks (`Lock.use_locked()`) first. It is offered only to a user with the loot screen (`Screens.has()`), so a user without one carries a body on the press as before.
- **Hold to carry is generic**: any target that is used and is also an offered `Carryable` (a downed guard, a carryable container) gets a hold action (`Interactor.hold_kind`); `press()` / `step_hold()` / `perform_hold()` do tap vs hold for any controller; `InteractorConfig.hold_time` = 0.5 s. Nothing else is both usable and carryable today, so no other target changes.
- **`ItemLoadout`** (one component for guards and containers, not two): `items` (`StartingItem`, moved from the mission kit to `items/inventory/`) and `weapon_ammo` rounds per fixed-loadout weapon; fills once when ready (before `WeaponDrop` can empty the holder), saved as `filled`. Guards: `weapon_ammo = 10` (one magazine of the held weapon since M14d levels, below), `Inventory`, `Keychain`, `Lootable`.
- **Keychain kinds live on the keychain**: `Keychain.KEY` / `CARD`, `add(key_id, key_name, found, kind)`, `remove(key_id) -> Dictionary`, `has_key(key_id, kind)`; `ItemData.keychain_kind`. A card never turns a keyhole and a key never swipes a reader. `Inventory.key_ids()` and `LockRules.key_matches()` are removed (keycards never enter a grid now). An old save with a keycard stack in a grid keeps it there, where it opens nothing (saves do not carry across levels).
- **`WeaponDrop` stows** the weapon in the character's own Inventory (`weapon.stowed`), dropping it only without an Inventory or room.
- **Containers**: `objects/containers/` supply crate, locker (locked by default, lockpick or its key), desk drawers (unlocked, with a lock levels can close); static props on the world layer composing the components.
- Tests: `tests/items/inventory/lootable_test.gd`, `item_loadout_test.gd`, `tests/actors/common/interaction/interactor_hold_test.gd`, `tests/actors/common/keychain/keychain_cards_test.gd`, and the cross-feature `tests/scenarios/looting_test.gd` (tap E on a downed guard with a keycard in its loadout, Take all on the real screen, the card opens a reader; a locked locker opens once its key is on the keychain).

## As built (M14d levels)

Details in [looting.md](../game/looting.md#as-built-m14d-levels) and [mission-warehouse.md](../levels/mission-warehouse.md#loot-m14d).
- **Guard ammo is a number of magazines of the held weapon**, read from its data (`WeaponData.magazine_size`): `ItemLoadout.weapon_magazines` (1 by default), with `weapon_ammo` rounds as an override per entity (-1: unset). Before, every guard carried 10 rounds whatever its weapon (one pistol magazine, a third of a rifle's). `guard.tscn` sets neither: one magazine.
- **The hold ring**: a HUD ring around the crosshair fills over the 0.5 s hold while E is held on a target with a hold action, hidden otherwise (`HoldRing`, theme variation `HudHoldRing` in `hud_theme.tres`).
- **Warehouse keys move onto the guards who would carry them**: the vault keycard onto G7 (the vault door guard, who has the vault access tag), the security keycard onto G6 (the break room across the corridor; G5, the operator, sits behind the security door, so his card would only open a door already passed), the office bay key onto G10 (a patrol: catching it is a choice with a cost; lockpicks still open the bay); G8 carries the key of his locker. Every route stays solvable (console, duct C, lockpicks), checked by the key graph test, which now counts a key on a keychain where its holder stands.
- **Warehouse containers** are generated with the people population (`warehouse_people.py`: `CONTAINERS`): three supply crates (dock, store, the back strip's dead end), two lockers (one locked with G8's key), two desk drawers (the manager's holds a new key to the second office); the dock's frag, the locker room's gas grenade and the manager's jammer moved into them. Datapads stay on desks (read in place, not items).
- **Hub**: the inventory bay's looting corner (crate, drawers with the locker's key, locked locker, sign) and the AI arena's downed guard with a security booth keycard and pistol rounds.
- **Screens name warehouse guards "Guard"** (`display_name` metadata set by the generator): the loot screen read "G 7 vault door".
- Tests: `tests/ui/hud/hold_ring_test.gd`, `tests/levels/mission/warehouse_loot_test.gd`, `tests/levels/gallery/inventory_bay/inventory_bay_loot_corner_test.gd`; the item loadout, AI arena, people, doors and office bay suites updated.
