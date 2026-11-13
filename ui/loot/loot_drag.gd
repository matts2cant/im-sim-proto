class_name LootDrag
extends RefCounted
## The drag in progress on the loot screen, shared by its two LootGrids (they draw from it): the
## stack, the grid it came from, the cell of it grabbed, the mouse (global), the grid under the mouse
## with the cell its top-left would land on, and whether it fits there (LootRules.drop_fits()).

var stack: ItemStack = null
var source: LootGrid = null
var grab: Vector2i = Vector2i.ZERO
var at_global: Vector2 = Vector2.ZERO
## The grid under the mouse (null: none).
var target: LootGrid = null
var cell: Vector2i = Vector2i.ZERO
var fits: bool = false


func active() -> bool:
	return stack != null


func clear() -> void:
	stack = null
	source = null
	target = null
	fits = false
