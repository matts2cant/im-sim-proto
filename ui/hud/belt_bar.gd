class_name BeltBar
extends Control
## HUD belt (bottom centre): 10 small slots with the key number, the item's short name and count
## (ItemIcon); the slot whose item is in hand is highlighted. Redraws on belt / inventory changes.

const SLOT := 52.0
const GAP := 4.0
const FILL := Color(0.05, 0.06, 0.07, 0.6)
const LINE := Color(0.6, 0.66, 0.7, 0.45)
const SELECTED := Color(1.0, 0.82, 0.3)
const NUMBER := Color(0.75, 0.82, 0.85)

var player_inventory: PlayerInventory


func bind(p_inventory: PlayerInventory) -> void:
	player_inventory = p_inventory
	player_inventory.belt.changed.connect(queue_redraw)
	player_inventory.inventory.changed.connect(queue_redraw)
	var count := player_inventory.belt.size()
	custom_minimum_size = Vector2(count * SLOT + (count - 1) * GAP, SLOT)
	queue_redraw()


func slot_rect(index: int) -> Rect2:
	return Rect2(index * (SLOT + GAP), 0.0, SLOT, SLOT)


func _draw() -> void:
	if player_inventory == null:
		return
	var belt := player_inventory.belt
	var font := ThemeDB.fallback_font
	for i in belt.size():
		var rect := slot_rect(i)
		draw_rect(rect, FILL)
		var stack := belt.stack_in(i)
		if stack != null:
			ItemIcon.draw(self, rect, stack, 11)
		var selected := i == belt.selected
		draw_rect(rect, SELECTED if selected else LINE, false, 2.0 if selected else 1.0)
		draw_string(font, rect.position + Vector2(4, 12), Belt.key_label(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, NUMBER)
