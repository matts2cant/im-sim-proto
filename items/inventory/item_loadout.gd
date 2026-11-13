class_name ItemLoadout
extends Node
## Component of any entity with an Inventory (ADR 0142): what it carries when the level starts, as
## data. Fills the entity's Inventory once: every StartingItem of `items` (keys and keycards go onto
## its Keychain through Inventory.add()), then the ammo of each weapon of its WeaponHolder's fixed
## loadout (`holder_path`; a guard's pistol: pistol rounds): `weapon_magazines` magazines of that
## weapon (its `magazine_size`: one pistol magazine is 10 rounds, one rifle magazine 30), or
## `weapon_ammo` rounds when set (an override per entity). Guards carry one magazine by default; a
## level adds keycards, keys and other items per guard or per container.
## Filled once, when it is ready (or, when its Inventory is not ready yet, deferred after the
## entity is); what does not fit is left out with a warning. Saveable (`filled`): a loaded level never fills again,
## the Inventory and Keychain restore their own contents.

## The items given, in order.
@export var items: Array[StartingItem] = []
## Magazines of ammo given for each weapon of the holder's fixed loadout that uses ammo, each the
## weapon's `magazine_size` rounds (0: none). Ignored when `weapon_ammo` is set.
@export var weapon_magazines: int = 1
## Rounds of ammo given for each such weapon instead of `weapon_magazines` (-1: unset, use magazines;
## 0: none).
@export var weapon_ammo: int = -1
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
	for data in ammo_weapons():
		var rounds := rounds_for(data)
		if rounds > 0:
			_give(inventory, catalog.find(data.ammo_item), rounds, {})
	return true


## Rounds of ammo given for a weapon of the fixed loadout: `weapon_ammo` when set, else
## `weapon_magazines` of its magazines.
func rounds_for(data: WeaponData) -> int:
	if data == null or not data.uses_ammo():
		return 0
	if weapon_ammo >= 0:
		return weapon_ammo
	return maxi(weapon_magazines, 0) * data.magazine_size


func save_state() -> Dictionary:
	return {"filled": filled}


func load_state(data: Dictionary) -> void:
	filled = bool(data.get("filled", filled))


## The weapons of the holder's fixed loadout whose ammo is a catalogue item, in order.
func ammo_weapons() -> Array[WeaponData]:
	var found: Array[WeaponData] = []
	var holder := get_node_or_null(holder_path) as WeaponHolder if not holder_path.is_empty() else null
	if holder == null:
		return found
	for data in holder.weapons:
		if data == null or not data.uses_ammo() or data.ammo_item.is_empty():
			continue
		if catalog.find(data.ammo_item) != null:
			found.append(data)
	return found


func _give(inventory: Inventory, item: ItemData, count: int, state: Dictionary) -> void:
	var left := inventory.add(item, count, state)
	if left > 0:
		push_warning("ItemLoadout %s: no room for %d x %s" % [get_path(), left, item.id])
