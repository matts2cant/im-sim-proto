# 50. Inventory model and belt references

Status: Accepted

Date: 2026-11-06

## Context

[ADR 0015](0015-inventory-grid.md) chose a Deus Ex 1 grid (6 x 5, footprints, no rotation, stacking consumables, 10-slot belt). M5 has to pin down how stacks are placed and merged, where per-item data (a pistol's magazine, a keycard's key, a datapad's text) lives, what the belt holds, and where weapon ammo comes from now that the M4 `WeaponHolder` kept its own magazine and reserve per weapon.

## Decision

- **Pure model**: `Inventory` (RefCounted) holds `ItemStack`s `{item, count, state, cell}`. `add()` first fills existing stacks of the same item, then places new stacks at the first free position scanning rows top to bottom, left to right; it returns what did not fit and changes nothing when nothing fits. `move()` checks bounds and overlap, ignoring the stack's own cells. `split()` puts the new stack at the first free position. `to_dict()` stores `{id, count, state, cell: [x, y]}`; ids resolve through `items/item_catalog.tres`.
- **Instance state on the stack**: a `state` Dictionary (`magazine`, `key_id`, `title`, `text`) that travels unchanged between the grid, the world `ItemPickup` and saves. Items with state have max stack 1 and never merge; stackable items carry no state.
- **Belt holds references**: `Belt` slots point at `ItemStack` objects of the same inventory, never copies; a stack is in at most one slot; a stack that leaves the grid clears its slot (`stack_removed`). Saved as stack indices. New stacks of `auto_belt` items (weapons, tools, consumables) take the first free slot, as in Deus Ex.
- **Ammo from stacks**: a `WeaponState`'s spare rounds come from an `AmmoPool`. Fixed loadouts keep a plain count; the player's weapons use `InventoryAmmo`, which counts and takes the weapon's `ammo_item` stacks (smallest first, freeing cells sooner). The magazine stays in the `WeaponState` that `PlayerInventory` keeps per weapon stack and is mirrored into the stack's `magazine` after every change.
- `WeaponHolder` can be armed with an external state (`equip_state`); its own `weapons` list remains for fixed loadouts (guards in M7) and only then is it saveable.

## Alternatives considered

- **Belt holds copies or item ids**: a medkit used from the belt would not decrement the grid stack, or the belt would need a lookup rule when several stacks of an id exist.
- **Ammo as a per-weapon reserve counter** (M4): invisible in the grid, cannot be dropped, found or traded for space.
- **Placement by best fit / gravity packing**: harder to predict for the player and to test; DX1's first-fit scan is the reference.
- **Instance state as separate Resource subclasses per item**: more files for three keys; a Dictionary round-trips through saves and pickups without code.

## Consequences

- Every inventory rule is unit-tested without a scene tree.
- Two pistols are two stacks, each with its own magazine; ammo is shared.
- M6 quicksave stores the player's inventory dict; M8 reads `key_id` and datapad `text` from stacks.
