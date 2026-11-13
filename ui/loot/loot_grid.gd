class_name LootGrid
extends Control
## One side's inventory grid on the loot screen (ADR 0142): any Inventory's stacks drawn as in the
## Inventory tab (InventoryView's colours, ItemIcon), with cells of up to CELL px (smaller when the
## grid would not fit `max_area`). Input only reports: a left press on a stack asks to start a drag
## (`drag_started`, with the cell grabbed), motion and release while dragging report the global
## mouse position (`drag_moved`, `drag_released`: the press keeps the mouse, so the release over the
## other grid still comes here), a double-click asks for a quick move. The screen owns the drag (a
## LootDrag shared by both grids) and draws through it: the dragged stack dimmed on its grid, the
## footprint where it would land on the grid under the mouse (green fits, red not) with the item's
## ghost. Mouse positions are local to this control.

signal drag_started(grid: LootGrid, stack: ItemStack, grab: Vector2i)
signal drag_moved(at_global: Vector2)
signal drag_released(at_global: Vector2)
signal quick_move_requested(grid: LootGrid, stack: ItemStack)

## The mockup's 52 px cell on its 1280 px frame, at the base 1152 px width.
const CELL := 48.0

var inventory: Inventory
## The shared drag (set by the screen).
var drag: LootDrag
## The stack outlined as selected (Enter moves it), or null.
var selected: ItemStack = null
## The largest size the grid may take; cells shrink to fit it.
var max_area: Vector2 = Vector2(6, 7) * CELL
## Cell edge now (px).
var cell_size: float = CELL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func bind(p_inventory: Inventory) -> void:
	if inventory != null and inventory.changed.is_connected(queue_redraw):
		inventory.changed.disconnect(queue_redraw)
	inventory = p_inventory
	selected = null
	if inventory != null:
		inventory.changed.connect(queue_redraw)
		var cells := Vector2(inventory.grid.size)
		cell_size = floorf(minf(CELL, minf(max_area.x / cells.x, max_area.y / cells.y)))
		custom_minimum_size = cells * cell_size
	queue_redraw()


func grid_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(inventory.grid.size) * cell_size) if inventory != null else Rect2()


## Cell under a local point (may be outside the grid).
func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))


## Local centre of `cell` (tests aim the mouse with it).
func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


## Global centre of `cell`.
func global_cell_center(cell: Vector2i) -> Vector2:
	return get_global_transform() * cell_center(cell)


## True when the global point is over this grid.
func has_global_point(at_global: Vector2) -> bool:
	return grid_rect().has_point(get_global_transform().affine_inverse() * at_global)


## Cell under a global point.
func cell_at_global(at_global: Vector2) -> Vector2i:
	return cell_at(get_global_transform().affine_inverse() * at_global)


func stack_rect(stack: ItemStack) -> Rect2:
	return Rect2(Vector2(stack.cell) * cell_size, Vector2(stack.item.footprint) * cell_size)


## The stack under a local point, or null.
func stack_at_point(point: Vector2) -> ItemStack:
	if inventory == null or not grid_rect().has_point(point):
		return null
	return inventory.grid.stack_at(cell_at(point))


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if drag != null and drag.source == self:
			drag_moved.emit(get_global_transform() * motion.position)
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if button.pressed:
		var stack := stack_at_point(button.position)
		if stack == null:
			return
		selected = stack
		queue_redraw()
		if button.double_click:
			quick_move_requested.emit(self, stack)
		else:
			drag_started.emit(self, stack, cell_at(button.position) - stack.cell)
	elif drag != null and drag.source == self:
		drag_released.emit(get_global_transform() * button.position)


func _draw() -> void:
	if inventory == null:
		return
	_draw_cells()
	var dragged := drag.stack if drag != null else null
	for stack in inventory.stacks():
		ItemIcon.draw(self, stack_rect(stack), stack, 12, 0.35 if stack == dragged else 1.0)
	if selected != null and inventory.has(selected) and selected != dragged:
		draw_rect(stack_rect(selected).grow(-1.0), InventoryView.SELECTED, false, 2.0)
	if drag != null and drag.target == self and dragged != null:
		_draw_drop(dragged)


func _draw_cells() -> void:
	var rect := grid_rect()
	draw_rect(rect, InventoryView.CELL_FILL)
	for x in inventory.grid.size.x + 1:
		var px := x * cell_size
		draw_line(Vector2(px, 0.0), Vector2(px, rect.end.y), InventoryView.LINE, 1.0)
	for y in inventory.grid.size.y + 1:
		var py := y * cell_size
		draw_line(Vector2(0.0, py), Vector2(rect.end.x, py), InventoryView.LINE, 1.0)


# The footprint where the dragged stack would land (green fits, red not) and its ghost at the mouse.
func _draw_drop(dragged: ItemStack) -> void:
	var footprint := Vector2(dragged.item.footprint) * cell_size
	var preview := Rect2(Vector2(drag.cell) * cell_size, footprint).intersection(grid_rect())
	var colour := InventoryView.FITS if drag.fits else InventoryView.BLOCKED
	draw_rect(preview, colour)
	draw_rect(preview.grow(-1.0), Color(colour, 1.0), false, 2.0)
	var mouse := get_global_transform().affine_inverse() * drag.at_global
	var ghost := Rect2(mouse - (Vector2(drag.grab) + Vector2(0.5, 0.5)) * cell_size, footprint)
	ItemIcon.draw(self, ghost, dragged, 12, 0.5)
