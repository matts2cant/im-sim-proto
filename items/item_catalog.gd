class_name ItemCatalog
extends Resource
## Every item type (`items/item_catalog.tres`): saves store item ids and look them up here; the
## debug panel's "Give item" lists them.

const DEFAULT_PATH := "res://items/item_catalog.tres"

@export var items: Array[ItemData] = []


static func default() -> ItemCatalog:
	return load(DEFAULT_PATH) as ItemCatalog


## The item with `id`, or null.
func find(id: StringName) -> ItemData:
	for item in items:
		if item.id == id:
			return item
	return null
