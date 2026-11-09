class_name ItemStack
extends RefCounted
## One stack on the inventory grid: an item type, how many, its instance state (a pistol's
## `magazine`, a keycard's `key_id`) and its top-left cell. The belt references stacks, not copies
## (ADR 0050).

var item: ItemData
var count: int = 1
var state: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO


func _init(p_item: ItemData, p_count: int = 1, p_state: Dictionary = {}, p_cell: Vector2i = Vector2i.ZERO) -> void:
	item = p_item
	count = p_count
	state = p_state
	cell = p_cell


## How many more fit on this stack.
func room() -> int:
	return maxi(item.max_stack - count, 0)


## The cells it covers.
func rect() -> Rect2i:
	return Rect2i(cell, item.footprint)


## The item's name with what is fitted to it: "Pistol (silenced)" (ADR 0085).
func display_name() -> String:
	return Attachments.display_name(item, state)


## "Pistol ammo (40)"; the count only when more than one.
func label() -> String:
	return display_name() if count <= 1 else "%s (%d)" % [display_name(), count]
