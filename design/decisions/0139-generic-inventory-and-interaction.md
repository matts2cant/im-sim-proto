# 139. Generic inventory, carrying and interaction

Status: Accepted

Date: 2026-11-13

## Context

The code audit ([audit-2026-11-13.md](../tech/audit-2026-11-13.md), S3, S7, Q22, Q26) found:

- World systems read the player's `PlayerInventory` (typed to `Player`): a guard holding a keycard could not open a reader, only the player could disarm a mine; three files re-implemented `PlayerInventory.of()`.
- Carrying (`PlayerCarry`) and interaction (`Interactor`) held a `Player` and read its config, camera and look ray: no other character could carry or use anything.
- "Who is the player" was answered three ways (the `actor.player` tag, the `player` group, node names), with the tag and group literals repeated.
- Stack state keys (`key_id`, `magazine`, `key_name`) were bare strings.

## Decision

- **`Inventory` is any character's carried items.** A component (`items/inventory/inventory.gd`, found with `Inventory.of(entity)`) over the pure grid, renamed `InventoryGrid`. It answers world systems' questions (`stacks()`, `has()`, `count(item)`, `key_ids()`) and changes (`add(item, amount, state) -> left over`, `take(item, amount) -> taken`, `remove(stack, amount)`, `pick_up(pickup)`); it owns each weapon stack's `WeaponState` and fitting attachments, routes a keychain item to the holder's `Keychain`, and saves itself (group `saveable`) unless `saved_by_entity`. Signals: `changed`, `stack_added`, `stack_removed`, `message`.
- **The player's belt and hand extend it.** `PlayerInventory extends Inventory`: the Belt, the item in hand, use, drop and thrown weapons; it needs a `WeaponHolder` (`setup()`) and `Eyes`, never the Player class. Extending rather than a second node keeps one node per character, keeps the save format (the Player saves `{inventory, belt, in_hand}`) and keeps `PlayerInventory.of()` callers working; `Inventory.of(player)` returns it. `PlayerInventory.inventory` (the grid) and `give()` (same as `add()`) stay for existing callers and tests.
- **`Eyes` is where a character looks from.** A component (`actors/common/eyes/eyes.gd`): a view node (the player's camera, which eases after a step) or `height` above the feet facing the entity's -Z. `Eyes.view_of(entity)` is what the Carrier, the Interactor and PlayerInventory's drop point ask.
- **`Carrier` and `Interactor` work for any character.** `Carrier` (was `PlayerCarry`, `actors/common/carry/`) and `Interactor` (`actors/common/interaction/`) find their entity by `entity_path`, look through its Eyes, read its `carry_mass_limit` attribute, put pickups into its Inventory and send failures to its Notices. A character without an Inventory is offered no pickups; without a Carrier, nothing to carry. Their controller drives them (`refresh()`, `physics_step()`, `perform()`): the Player maps input to them, an AI controller would do the same. Tuning moved out of `PlayerConfig` into `CarryConfig` (`carry.tres`) and `InteractorConfig` (`interactor.tres`), values unchanged; a release clears the carrier's own capsule radius instead of the player's config value. The carry EventLog kinds keep their `player.` names.
- **One player tag.** `ActorState.PLAYER` (`actor.player`) is the only definition; perception, missions, extraction, level exits and turrets default to it. The `player` group is only the debug tools' index (`DebugPanel.PLAYER_GROUP`, `DebugPanel.player()`).
- **Stack state keys are constants**: `ItemStack.MAGAZINE`, `KEY_ID`, `KEY_NAME` (attachments: `Attachments.STATE_KEY`).

## Consequences

- No behaviour, layout or save change for the player: the Inventory tab and belt render pixel-identical before and after; every existing test passes.
- Guards get no items in any level yet (a later milestone); `tests/items/inventory/inventory_test.gd` (a keycard opening a reader), `tests/items/grenades/mine_disarm_test.gd` (disarming into an Inventory) and `tests/actors/common/carry/carrier_test.gd` (picking up, carrying and putting down a crate; picking up an item) prove the capability on minimal characters.
- `items/deck/deck_session.gd`, `items/deck/wireless_tool.gd` and `items/exploit/exploit_items.gd` still call `PlayerInventory.of()` (another agent's files in this wave); they switch to `Inventory.of()` next, after which `PlayerInventory.of()`, `.inventory` and `give()` can go. (Done in the last audit wave, [ADR 0141](0141-lookup-conventions-interfaces-device-keys.md): all three are gone.)
