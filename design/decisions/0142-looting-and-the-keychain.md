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
