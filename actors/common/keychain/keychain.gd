class_name Keychain
extends Node
## Component of any character (ADR 0130): the keys it holds, apart from the inventory grid. A key
## takes no space, cannot be dropped or thrown and is never removed. An item whose ItemData has
## `keychain` set (the key) goes here when picked up (take(): its stack state's `key_id` and
## `key_name`, the pickup's `found_text`); a MechanicalLock whose data names a key id opens with E
## for a holder of that key. Only the player's UI shows it (the Inventory tab's keychain list).
## EventLog `keychain.key_added {key, name}`. Saveable (group `saveable`).

## A key was added (`key_name`: what the keychain list calls it).
signal key_added(key_name: String)
signal changed

## The HUD message when a key is picked up.
const ADDED := "Key added to the keychain: %s"

## The keys in the order they were added: {"id": String, "name": String, "found": String}.
var _keys: Array[Dictionary] = []


static func of(node: Node) -> Keychain:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is Keychain:
			return child as Keychain
	return null


func _ready() -> void:
	add_to_group(&"saveable")


## True when it holds the key `key_id` (an empty id is no key).
func has_key(key_id: StringName) -> bool:
	return not String(key_id).is_empty() and _index_of(String(key_id)) >= 0


## Adds key `key_id` named `key_name`, found as `found` says ("Found in the office desk"). False
## when it has no id or is already held (nothing changes).
func add(key_id: StringName, key_name: String, found: String = "") -> bool:
	var id := String(key_id)
	if id.is_empty() or _index_of(id) >= 0:
		return false
	_keys.append({"id": id, "name": key_name, "found": found})
	EventLog.record(EventKinds.KEYCHAIN_KEY_ADDED, _who(), "", {"key": id, "name": key_name})
	key_added.emit(key_name)
	changed.emit()
	return true


## Takes the key of `pickup` (an item with `keychain` set): adds it and removes the pickup from the
## world. False (the pickup stays) when it is not a keychain item or its key is already held.
func take(pickup: ItemPickup) -> bool:
	if pickup == null or pickup.item == null or not pickup.item.keychain or pickup.count <= 0:
		return false
	var state := pickup.stack_state()
	if not add(StringName(str(state.get("key_id", ""))), key_name_of(pickup.item, state), pickup.found_text):
		return false
	pickup.consume()
	return true


## The name of a key with stack `state`: its `key_name`, else the item's name.
static func key_name_of(item: ItemData, state: Dictionary) -> String:
	var shown := str(state.get("key_name", ""))
	return shown if not shown.is_empty() else item.display_name


## The keys held, oldest first (copies): {"id", "name", "found"}.
func keys() -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for key in _keys:
		copies.append(key.duplicate())
	return copies


func size() -> int:
	return _keys.size()


func save_state() -> Dictionary:
	return {"keys": keys()}


func load_state(data: Dictionary) -> void:
	_keys.clear()
	for entry: Variant in data.get("keys", []):
		if not entry is Dictionary:
			continue
		var key: Dictionary = entry
		if not str(key.get("id", "")).is_empty():
			_keys.append({"id": str(key["id"]), "name": str(key.get("name", "")), "found": str(key.get("found", ""))})
	changed.emit()


func _index_of(id: String) -> int:
	for i in _keys.size():
		if _keys[i]["id"] == id:
			return i
	return -1


func _who() -> String:
	var holder := get_parent()
	return String(holder.name) if holder != null else String(name)
