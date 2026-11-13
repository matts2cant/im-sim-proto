class_name LootRules
extends RefCounted
## What the loot screen does to two inventories and two keychains (ADR 0142), apart from the screen:
## - drop(): a stack dragged onto a cell. In the same inventory it moves there (footprint check, as
##   in the Inventory tab). Into the other one a stackable item (ammo) first fills that side's stacks
##   of the same item, and the rest lands with its top-left on the cell; it fits when the cell has
##   room for the footprint or the stacks there take all of it (drop_fits(): the green / red
##   outline). Planting (from the player's side to the other) is the same move.
## - quick_move(): double-click or Enter: into the first free spot on the other side, filling stacks
##   of the same item first; what does not fit stays.
## - take_all(): every item that fits and every key and card; returns the names of what stayed.
## - move_key(): a key or card from one keychain to the other, keeping its kind.
## A moved stack keeps its state (a weapon's loaded rounds, fitted attachments: Inventory.state_of()).

## Keychain entry kinds (the entry's "kind"; none: a key).
const KEY: StringName = &"key"
const CARD: StringName = &"card"
const KEY_ADDED := "Key added to the keychain: %s"
const CARD_ADDED := "Keycard added to the keychain: %s"
const TOOK_ALL := "Took everything"
const NO_ROOM_FOR := "No room for: %s"
const NO_ROOM := "No room"
const KEEP_KEYS := "Keys and cards stay on your keychain"


## True when `stack` of `from` dropped with its top-left on `cell` of `to` would land.
static func drop_fits(from: Inventory, stack: ItemStack, to: Inventory, cell: Vector2i) -> bool:
	if from == null or to == null or stack == null or not from.has(stack):
		return false
	if to == from:
		return to.grid.can_place(stack.item.footprint, cell, stack)
	if to.grid.can_place(stack.item.footprint, cell):
		return true
	return stack.item.stackable() and room_for(to, stack.item) >= stack.count


## Drops `stack` of `from` with its top-left on `cell` of `to` (see the class notes). Returns how many
## moved (0: refused, nothing changed).
static func drop(from: Inventory, stack: ItemStack, to: Inventory, cell: Vector2i) -> int:
	if not drop_fits(from, stack, to, cell):
		return 0
	if to == from:
		return stack.count if to.grid.move(stack, cell) else 0
	var item := stack.item
	var count := stack.count
	var state := from.state_of(stack)
	var merged := mini(room_for(to, item), count) if item.stackable() else 0
	if merged > 0:
		to.add(item, merged, state)
	var rest := count - merged
	if rest > 0:
		var before := to.stacks().duplicate()
		if to.add(item, rest, state) > 0:
			return 0
		for placed in to.stacks():
			if not before.has(placed):
				to.grid.move(placed, cell)
	from.remove(stack, count)
	return count


## Moves `stack` of `from` to the first free spot of `to` (stacks of the same item first). Returns
## how many moved (0: no room).
static func quick_move(from: Inventory, stack: ItemStack, to: Inventory) -> int:
	if from == null or to == null or stack == null or to == from or not from.has(stack):
		return 0
	var left := to.add(stack.item, stack.count, from.state_of(stack))
	var moved := stack.count - left
	if moved > 0:
		from.remove(stack, moved)
	return moved


## Moves everything that fits from `from` to `to` (each stack as quick_move()) and every key and card
## of `from_keys` to `to_keys`. Returns the display names of the stacks that stayed (all or part).
static func take_all(from: Inventory, to: Inventory, from_keys: Keychain, to_keys: Keychain) -> Array[String]:
	var stayed: Array[String] = []
	if from != null and to != null:
		for stack: ItemStack in from.stacks().duplicate():
			var count := stack.count
			if quick_move(from, stack, to) < count:
				stayed.append(stack.display_name())
	if from_keys != null and to_keys != null:
		for entry in from_keys.keys():
			move_key(from_keys, to_keys, str(entry.get("id", "")))
	return stayed


## The notice after take_all() left `stayed` behind.
static func take_all_notice(stayed: Array[String]) -> String:
	return TOOK_ALL if stayed.is_empty() else NO_ROOM_FOR % ", ".join(stayed)


## How many more of `item` the stacks of `inventory` take without a new stack.
static func room_for(inventory: Inventory, item: ItemData) -> int:
	var room := 0
	for stack in inventory.stacks():
		if stack.item.id == item.id:
			room += stack.room()
	return room


## The kind of keychain `entry` (KEY when it has none).
static func kind_of(entry: Dictionary) -> StringName:
	var kind := StringName(str(entry.get("kind", "")))
	return CARD if kind == CARD else KEY


## The notice for `entry` reaching the player's keychain.
static func key_notice(entry: Dictionary) -> String:
	return (CARD_ADDED if kind_of(entry) == CARD else KEY_ADDED) % str(entry.get("name", ""))


## The kind's word under a keychain row ("Keycard", "Key").
static func kind_word(entry: Dictionary) -> String:
	return "Keycard" if kind_of(entry) == CARD else "Key"


## Moves key `key_id` from `from` to `to` with its name, where it was found and its kind. Returns the
## entry moved ({}: none, or `to` already holds it).
## The one place that uses the M14d keychain contract (Keychain.remove(key_id) -> Dictionary and
## Keychain.add(key_id, key_name, found, kind)): called through call() until that lands.
static func move_key(from: Keychain, to: Keychain, key_id: String) -> Dictionary:
	if from == null or to == null or from == to or key_id.is_empty() or to.has_key(StringName(key_id)):
		return {}
	var entry: Dictionary = from.call(&"remove", StringName(key_id))
	if entry.is_empty():
		return {}
	var id := StringName(str(entry.get("id", key_id)))
	to.call(&"add", id, str(entry.get("name", "")), str(entry.get("found", "")), kind_of(entry))
	return entry


## The subject's line under the title: its display name and, for a character, its state ("Guard ·
## unconscious"; TargetStatus's word, as the interaction frame says it).
static func subject_line(subject: Node) -> String:
	var shown := EntityNames.display_name(subject)
	var word := TargetStatus.word_of(subject, [] as Array[Device]) if TargetStatus.is_character(subject) else null
	return shown if word == null else "%s · %s" % [shown, word.text.to_lower()]
