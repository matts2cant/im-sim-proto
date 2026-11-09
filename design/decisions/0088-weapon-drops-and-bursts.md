# 88. Weapon drops from a holder's own loadout; AI bursts with automatic weapons; the rifle guard

Status: Accepted

Date: 2026-11-09

## Context

ADR 0086 wants any character holding a weapon to drop it as a pickup beside the body when knocked out or killed, and a catwalk guard with the assault rifle. Guards fire through CombatBehaviour one trigger pull per shot interval, which suits pistols but not a full-auto rifle. The player holds weapons from its inventory, guards from a fixed loadout on their WeaponHolder.

## Decision

- **WeaponDrop component** (`actors/common/weapon_drop/`), on the guard scene and the player: once the character can no longer act (`state.dead` or `state.unconscious`, from any source), every weapon of its WeaponHolder's **fixed loadout** becomes a world pickup of the weapon's item, with its current magazine, 0.6 m to the body's right at 0.4 m height (left, or at its feet, when a wall is in the way). The holder loses it (`WeaponHolder.remove_from_loadout()`); a woken guard stays unarmed and CombatBehaviour never engages without a loadout. Polled every physics tick, so a quickload (paused while the holder restores) never drops twice. Logged `weapon.dropped`.
- **Only what the holder owns drops.** Weapons armed from an inventory (`WeaponHolder.equip_state()`: the player's) belong to that inventory: a knocked-out or dead player keeps them. The rule is about who owns the weapon, not about who the character is.
- **WeaponData.item_id** names the inventory item a weapon is (an id, not the ItemData, which references the weapon). The guards' loud pistol (`pistol_unsilenced`) drops as the `pistol` item. A weapon without an item (the turret's gun) is not dropped.
- **The holder saves the loadout left** (`weapons`: ids in order), so a loaded guard that had dropped its weapon stays unarmed; dropped pickups are saved as spawned entities.
- **Bursts**: with an automatic weapon CombatBehaviour holds the holder's trigger for `CombatModel.burst_length()` shots (`CombatConfig.burst_shots_min` / `max`: 3-5) at the weapon's cycle, letting go early when the line of fire closes, it must move or the magazine runs dry; the usual shot interval follows each burst. Semi-automatic weapons are unchanged.
- **Rifle guard**: `actors/guard/guard_rifle.tscn`, the guard with the assault rifle as its loadout.

## Alternatives considered

- **Drop on the BodyParts `died` / `knocked_out` signals**: misses `state.unconscious` from other sources (sleep gas) and fires again while a load restores the tags.
- **Dropping the player's held weapon as well**: the player would lose its weapon on every knockout it survives (woken by an ally later, or reloaded); the inventory already keeps it, and the rule "the owner keeps what it owns" stays general.
- **A separate AI-only burst weapon**: duplicates the rifle's data; bursts are how a shooter uses any automatic weapon.

## Consequences

- Downed guards placed in levels (the AI arena's) drop their weapon when the level loads.
- A future pickup-capable AI could re-arm from pickups; not in v0.
