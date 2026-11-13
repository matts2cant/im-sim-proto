class_name ItemLoadout
extends Node
## Component of any entity with an Inventory (ADR 0142): what it carries when the level starts, as
## data. Fills the entity's Inventory once: every StartingItem of `items` (keys and keycards go onto
## its Keychain through Inventory.add()), then `weapon_ammo` rounds of the ammo of each weapon of its
## WeaponHolder's fixed loadout (`holder_path`; a guard's pistol: pistol rounds). Guards carry their
## ammo by default; a level adds keycards, keys and other items per guard or per container.
## Filled once, when it is ready (or, when its Inventory is not ready yet, deferred after the
## entity is); what does not fit is left out with a warning. Saveable (`filled`): a loaded level never fills again,
## the Inventory and Keychain restore their own contents.

## The items given, in order.
@export var items: Array[StartingItem] = []
## Rounds of ammo given for each weapon of the holder's fixed loadout that uses ammo (0: none).
@export var weapon_ammo: int = 0
## The entity's WeaponHolder (empty: none; `weapon_ammo` then gives nothing).
@export var holder_path: NodePath = ^""
@export var entity_path: NodePath = ^".."
## Item ids of the weapons' ammo; the default catalogue when unset.
@export var catalog: ItemCatalog

var entity: Node
## True once the inventory was filled (saved).
var filled: bool = false


static func of(node: Node) -> ItemLoadout:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is ItemLoadout:
			return child as ItemLoadout
	return null


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	entity = Entities.of_component(self, entity_path)
	if catalog == null:
		catalog = ItemCatalog.default()
	# At once when the Inventory is ready (an earlier sibling, as in the guard: before its WeaponDrop
	# can take the weapons away), else once the entity is ready.
	if not fill():
		fill.call_deferred()


## Fills the entity's Inventory from the data, once. False when it was already filled or the entity
## has no Inventory.
func fill() -> bool:
	var inventory := Inventory.of(entity)
	if filled or inventory == null or inventory.grid == null:
		return false
	filled = true
	for entry in items:
		if entry != null and entry.item != null:
			_give(inventory, entry.item, entry.count, entry.state)
	for ammo in _weapon_ammo_items():
		_give(inventory, ammo, weapon_ammo, {})
	return true


func save_state() -> Dictionary:
	return {"filled": filled}


func load_state(data: Dictionary) -> void:
	filled = bool(data.get("filled", filled))


# The ammo items of the holder's fixed loadout (one per weapon that uses ammo, in order).
func _weapon_ammo_items() -> Array[ItemData]:
	var found: Array[ItemData] = []
	var holder := get_node_or_null(holder_path) as WeaponHolder if not holder_path.is_empty() else null
	if holder == null or weapon_ammo <= 0:
		return found
	for data in holder.weapons:
		if data == null or not data.uses_ammo() or data.ammo_item.is_empty():
			continue
		var ammo := catalog.find(data.ammo_item)
		if ammo != null:
			found.append(ammo)
	return found


func _give(inventory: Inventory, item: ItemData, count: int, state: Dictionary) -> void:
	var left := inventory.add(item, count, state)
	if left > 0:
		push_warning("ItemLoadout %s: no room for %d x %s" % [get_path(), left, item.id])
