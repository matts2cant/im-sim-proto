class_name Keychain
extends Node
## Component of any character or container (ADR 0130, ADR 0142): the keys and keycards it holds,
## apart from the inventory grid. An entry takes no space and cannot be dropped or thrown. An item
## whose ItemData has `keychain` set (a key, a keycard) goes here when picked up or added (take(),
## Inventory.add(): its stack state's `key_id` and `key_name`, the pickup's `found_text`, the item's
## `keychain_kind`: KEY or CARD). A MechanicalLock opens with E for a holder of its key, a
## KeycardLock for a holder of its card (has_key() with the kind). Entries move between keychains
## only through remove() and add() (the loot screen). The player's UI shows it (the Inventory tab's
## keychain list, the loot screen).
## EventLog `keychain.key_added {key, name, kind}`, `keychain.key_removed {key, name, kind}`.
## Saveable (group `saveable`).

## A key or card was added (`key_name`: what the keychain list calls it).
signal key_added(key_name: String)
signal changed

## Entry kinds (ItemData.keychain_kind).
const KEY: StringName = &"key"
const CARD: StringName = &"card"
## The HUD message when a key is picked up.
const ADDED := "Key added to the keychain: %s"
## The HUD message when a keycard is picked up.
const CARD_ADDED := "Keycard added to the keychain: %s"

## The entries in the order they were added: {"id": String, "name": String, "found": String,
## "kind": StringName}.
var _keys: Array[Dictionary] = []


static func of(node: Node) -> Keychain:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is Keychain:
			return child as Keychain
	return null


## The HUD message for an entry of `kind` named `key_name` added on pick-up.
static func added_message(kind: StringName, key_name: String) -> String:
	return (CARD_ADDED if kind == CARD else ADDED) % key_name


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)


## True when it holds `key_id` (of `kind`, when given: a card never opens a keyhole). An empty id is
## no key.
func has_key(key_id: StringName, kind: StringName = &"") -> bool:
	if String(key_id).is_empty():
		return false
	var index := _index_of(String(key_id))
	return index >= 0 and (kind == &"" or _keys[index]["kind"] == kind)


## Adds `key_id` named `key_name`, found as `found` says ("Found in the office desk"), of `kind`
## (KEY or CARD). False when it has no id or is already held (nothing changes).
func add(key_id: StringName, key_name: String, found: String = "", kind: StringName = KEY) -> bool:
	var id := String(key_id)
	if id.is_empty() or _index_of(id) >= 0:
		return false
	var entry_kind := kind if kind != &"" else KEY
	_keys.append({"id": id, "name": key_name, "found": found, "kind": entry_kind})
	EventLog.record(EventKinds.KEYCHAIN_KEY_ADDED, _who(), "", {"key": id, "name": key_name, "kind": entry_kind})
	key_added.emit(key_name)
	changed.emit()
	return true


## Removes `key_id` and returns its entry ({"id", "name", "found", "kind"}: add() it to another
## keychain), or {} when it is not held.
func remove(key_id: StringName) -> Dictionary:
	var index := _index_of(String(key_id))
	if index < 0:
		return {}
	var entry: Dictionary = _keys[index]
	_keys.remove_at(index)
	var data := {"key": entry["id"], "name": entry["name"], "kind": entry["kind"]}
	EventLog.record(EventKinds.KEYCHAIN_KEY_REMOVED, _who(), "", data)
	changed.emit()
	return entry.duplicate()


## Takes the key or card of `pickup` (an item with `keychain` set): adds it and removes the pickup
## from the world. False (the pickup stays) when it is not a keychain item or it is already held.
func take(pickup: ItemPickup) -> bool:
	if pickup == null or pickup.item == null or not pickup.item.keychain or pickup.count <= 0:
		return false
	var state := pickup.stack_state()
	var key_id := StringName(str(state.get(ItemStack.KEY_ID, "")))
	if not add(key_id, key_name_of(pickup.item, state), pickup.found_text, pickup.item.keychain_kind):
		return false
	pickup.consume()
	return true


## The name of a key with stack `state`: its `key_name`, else the item's name.
static func key_name_of(item: ItemData, state: Dictionary) -> String:
	var shown := str(state.get(ItemStack.KEY_NAME, ""))
	return shown if not shown.is_empty() else item.display_name


## The entries held, oldest first (copies): {"id", "name", "found", "kind"}.
func keys() -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for key in _keys:
		copies.append(key.duplicate())
	return copies


func size() -> int:
	return _keys.size()


func save_state() -> Dictionary:
	return {"keys": keys()}


## Entries saved before keycards joined the keychain have no `kind`: keys.
func load_state(data: Dictionary) -> void:
	_keys.clear()
	for entry: Variant in data.get("keys", []):
		if not entry is Dictionary:
			continue
		var key: Dictionary = entry
		if str(key.get("id", "")).is_empty():
			continue
		var kind := StringName(str(key.get("kind", KEY)))
		_keys.append(
			{"id": str(key["id"]), "name": str(key.get("name", "")), "found": str(key.get("found", "")), "kind": kind}
		)
	changed.emit()


func _index_of(id: String) -> int:
	for i in _keys.size():
		if _keys[i]["id"] == id:
			return i
	return -1


func _who() -> String:
	var holder := get_parent()
	return String(holder.name) if holder != null else String(name)
