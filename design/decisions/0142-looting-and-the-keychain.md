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
- **Keychain kinds**: `KeyIcon` (`ui/inventory/`) draws a brass key or a blue card by the entry's `kind`, in the loot screen and the Inventory tab's `KeychainList`; `LootRules.KEY` / `CARD` name the kinds, and an entry without one is a key. Moving a key goes through `LootRules.move_key()`, the one caller of the systems side's contract (`Keychain.remove(key_id) -> Dictionary`, `Keychain.add(key_id, key_name, found, kind)`), through `call()` until that lands; tests use a stand-in keychain (`tests/ui/loot/fixtures/keychain_stand_in.gd`).
- **Look**: the Tab interface's theme with one new variation (`TabKeyButton`, a clickable keychain row); grid cells up to 48 px at 1152 wide.
