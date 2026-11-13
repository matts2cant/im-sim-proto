class_name InventoryAmmo
extends AmmoPool
## A weapon's spare rounds are its ammo item's stacks in an Inventory: the HUD's total is their sum
## and a reload empties the smallest stacks first (Inventory.take()).

var inventory: InventoryGrid
var item_id: StringName


func _init(p_inventory: InventoryGrid, p_item_id: StringName) -> void:
	inventory = p_inventory
	item_id = p_item_id


func available() -> int:
	return inventory.count_of(item_id)


func take(count: int) -> int:
	return inventory.take(item_id, count)


func restore(_value: int) -> void:
	pass
