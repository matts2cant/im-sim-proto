class_name InventoryView
extends Control
## Custom-drawn grid (64 px cells) and belt row of the inventory screen. Left-drag moves a stack:
## a green / red footprint shows whether it fits; dropping it on a belt slot assigns it there;
## releasing outside this control drops it into the world. Dragging a belt slot's item off the belt
## (anywhere but another slot) clears that slot. Dragging an attachment (a silencer) highlights every
## weapon it fits, on the grid and the belt; dropping it on one fits it (ADR 0085), anywhere else it
## moves or drops as usual. Right-click asks for the context menu. Hovering shows a tooltip (name,
## description, count, what is fitted). Mouse positions are local to this control.

signal context_requested(stack: ItemStack, at: Vector2)
signal drop_requested(stack: ItemStack)

const CELL := 64.0
const BELT_SLOT := 56.0
const BELT_GAP := 4.0
## Between the grid and the belt row (the "BELT" caption sits in it).
const BELT_TOP_GAP := 34.0
const LINE := Color(0.55, 0.62, 0.66, 0.35)
const CELL_FILL := Color(0.06, 0.08, 0.09, 0.85)
const CAPTION := Color(0.62, 0.72, 0.76)
const SELECTED := Color(1.0, 0.82, 0.3)
const FITS := Color(0.3, 0.9, 0.4, 0.35)
const BLOCKED := Color(0.95, 0.25, 0.2, 0.35)
## Weapons the dragged attachment fits.
const ATTACH := Color(0.3, 0.75, 1.0, 0.3)
const TOOLTIP_BG := Color(0.04, 0.05, 0.06, 0.95)
const TOOLTIP_WIDTH := 260.0

var player_inventory: PlayerInventory

var _hover: Vector2 = Vector2(-1, -1)
var _drag: ItemStack = null
var _drag_grab: Vector2i = Vector2i.ZERO
var _drag_from_belt: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(_width(), belt_top() + BELT_SLOT)


func bind(p_inventory: PlayerInventory) -> void:
	player_inventory = p_inventory
	player_inventory.inventory.changed.connect(queue_redraw)
	player_inventory.belt.changed.connect(queue_redraw)
	custom_minimum_size = Vector2(_width(), belt_top() + BELT_SLOT)
	queue_redraw()


func inventory() -> Inventory:
	return player_inventory.inventory


func grid_origin() -> Vector2:
	return Vector2(floorf((_width() - inventory().size.x * CELL) * 0.5), 0.0)


func grid_rect() -> Rect2:
	return Rect2(grid_origin(), Vector2(inventory().size) * CELL)


func belt_top() -> float:
	return inventory().size.y * CELL + BELT_TOP_GAP if player_inventory != null else 5 * CELL + BELT_TOP_GAP


## Cell under a local point (may be outside the grid).
func cell_at(point: Vector2) -> Vector2i:
	var local := (point - grid_origin()) / CELL
	return Vector2i(floori(local.x), floori(local.y))


## Local centre of `cell` (tests aim the mouse with it).
func cell_center(cell: Vector2i) -> Vector2:
	return grid_origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func stack_rect(stack: ItemStack) -> Rect2:
	return Rect2(grid_origin() + Vector2(stack.cell) * CELL, Vector2(stack.item.footprint) * CELL)


func belt_slot_rect(index: int) -> Rect2:
	var count := player_inventory.belt.size()
	var left := floorf((_width() - (count * BELT_SLOT + (count - 1) * BELT_GAP)) * 0.5)
	return Rect2(left + index * (BELT_SLOT + BELT_GAP), belt_top(), BELT_SLOT, BELT_SLOT)


## Belt slot under a local point, -1 when none.
func belt_slot_at(point: Vector2) -> int:
	for i in player_inventory.belt.size():
		if belt_slot_rect(i).has_point(point):
			return i
	return -1


## The stack under a local point: on the grid or in a belt slot; null when none.
func stack_at_point(point: Vector2) -> ItemStack:
	if grid_rect().has_point(point):
		return inventory().stack_at(cell_at(point))
	return player_inventory.belt.stack_in(belt_slot_at(point))


## The stack under the mouse (the screen assigns belt keys to it).
func hovered_stack() -> ItemStack:
	return stack_at_point(_hover) if _drag == null else null


func dragging() -> ItemStack:
	return _drag


## The stacks highlighted now: the weapons the dragged item can be fitted to (empty unless an
## attachment is being dragged).
func attach_targets() -> Array[ItemStack]:
	if _drag == null or _drag.item.attachment == null:
		return []
	return player_inventory.attach_targets(_drag)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover = motion.position
		queue_redraw()
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	_hover = button.position
	if button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_start_drag(button.position)
		elif _drag != null:
			_finish_drag(button.position)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		var stack := stack_at_point(button.position)
		if stack != null:
			context_requested.emit(stack, get_global_transform() * button.position)
		accept_event()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _drag == null:
		_hover = Vector2(-1, -1)
		queue_redraw()


func _start_drag(point: Vector2) -> void:
	_drag_from_belt = -1
	if grid_rect().has_point(point):
		_drag = inventory().stack_at(cell_at(point))
		if _drag != null:
			_drag_grab = cell_at(point) - _drag.cell
		return
	var slot := belt_slot_at(point)
	_drag = player_inventory.belt.stack_in(slot)
	if _drag != null:
		_drag_from_belt = slot
		_drag_grab = Vector2i.ZERO


func _finish_drag(point: Vector2) -> void:
	var stack := _drag
	var from_belt := _drag_from_belt
	_drag = null
	_drag_from_belt = -1
	var target := stack_at_point(point)
	if target != null and player_inventory.can_attach(stack, target):
		player_inventory.attach(stack, target)
		queue_redraw()
		return
	var slot := belt_slot_at(point)
	if slot >= 0:
		player_inventory.belt.assign(slot, stack)
	elif from_belt >= 0:
		player_inventory.belt.clear(from_belt)
	elif grid_rect().has_point(point):
		inventory().move(stack, cell_at(point) - _drag_grab)
	elif not Rect2(Vector2.ZERO, size).has_point(point):
		drop_requested.emit(stack)
	queue_redraw()


func _draw() -> void:
	if player_inventory == null:
		return
	var font := ThemeDB.fallback_font
	_draw_grid()
	for stack in inventory().stacks:
		var alpha := 0.35 if stack == _drag else 1.0
		ItemIcon.draw(self, stack_rect(stack), stack, 14, alpha)
	draw_string(
		font,
		Vector2(belt_slot_rect(0).position.x, belt_top() - 10.0),
		"BELT",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		CAPTION
	)
	for i in player_inventory.belt.size():
		_draw_belt_slot(i, font)
	if _drag != null:
		_draw_drag()
	else:
		_draw_tooltip(font)


func _draw_grid() -> void:
	var rect := grid_rect()
	draw_rect(rect, CELL_FILL)
	for x in inventory().size.x + 1:
		var px := rect.position.x + x * CELL
		draw_line(Vector2(px, rect.position.y), Vector2(px, rect.end.y), LINE, 1.0)
	for y in inventory().size.y + 1:
		var py := rect.position.y + y * CELL
		draw_line(Vector2(rect.position.x, py), Vector2(rect.end.x, py), LINE, 1.0)


func _draw_belt_slot(index: int, font: Font) -> void:
	var rect := belt_slot_rect(index)
	var belt := player_inventory.belt
	draw_rect(rect, CELL_FILL)
	var stack := belt.stack_in(index)
	if stack != null:
		ItemIcon.draw(self, rect, stack, 11, 0.35 if stack == _drag else 1.0)
	var selected := index == belt.selected
	draw_rect(rect, SELECTED if selected else LINE, false, 2.0 if selected else 1.0)
	draw_string(font, rect.position + Vector2(4, 12), Belt.key_label(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CAPTION)


# The ghost follows the mouse; over it, the footprint where it would land (green fits, red not)
# or the belt slot it would go to.
func _draw_drag() -> void:
	var targets := attach_targets()
	for target in targets:
		_draw_highlight(stack_rect(target), ATTACH)
		var slot_index := player_inventory.belt.slot_of(target)
		if slot_index >= 0:
			_draw_highlight(belt_slot_rect(slot_index), ATTACH)
	var over := stack_at_point(_hover)
	if over != null and targets.has(over):
		# Dropping here fits it: no move footprint.
		var ghost_rect := Rect2(_hover - Vector2(0.5, 0.5) * CELL, Vector2(_drag.item.footprint) * CELL)
		ItemIcon.draw(self, ghost_rect, _drag, 14, 0.5)
		return
	var ghost := Rect2(_hover - (Vector2(_drag_grab) + Vector2(0.5, 0.5)) * CELL, Vector2(_drag.item.footprint) * CELL)
	ItemIcon.draw(self, ghost, _drag, 14, 0.5)
	if grid_rect().has_point(_hover):
		var cell := cell_at(_hover) - _drag_grab
		var fits := inventory().can_place(_drag.item.footprint, cell, _drag)
		var preview := Rect2(grid_origin() + Vector2(cell) * CELL, Vector2(_drag.item.footprint) * CELL)
		preview = preview.intersection(grid_rect())
		var colour := FITS if fits else BLOCKED
		draw_rect(preview, colour)
		draw_rect(preview.grow(-1.0), Color(colour, 1.0), false, 2.0)
	var slot := belt_slot_at(_hover)
	if slot >= 0:
		_draw_highlight(belt_slot_rect(slot), FITS)


func _draw_highlight(rect: Rect2, colour: Color) -> void:
	draw_rect(rect, colour)
	draw_rect(rect.grow(-1.0), Color(colour, 1.0), false, 2.0)


func _draw_tooltip(font: Font) -> void:
	var stack := stack_at_point(_hover)
	if stack == null:
		return
	var body := tooltip_text(stack)
	var title_size := 16
	var body_size := 13
	var text_width := TOOLTIP_WIDTH - 16.0
	var body_height := font.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, text_width, body_size).y
	var box := Rect2(_hover + Vector2(16, 16), Vector2(TOOLTIP_WIDTH, 34.0 + body_height))
	# Keep it inside the view horizontally (it may hang below the belt).
	box.position.x = minf(box.position.x, size.x - box.size.x)
	draw_rect(box, TOOLTIP_BG)
	draw_rect(box, stack.item.colour, false, 1.0)
	var title_at := box.position + Vector2(8, 8 + font.get_ascent(title_size))
	draw_string(font, title_at, stack.display_name(), HORIZONTAL_ALIGNMENT_LEFT, text_width, title_size, ItemIcon.TEXT)
	var body_at := box.position + Vector2(8, 30 + font.get_ascent(body_size))
	draw_multiline_string(font, body_at, body, HORIZONTAL_ALIGNMENT_LEFT, text_width, body_size, -1, CAPTION)


## Tooltip body: description, then count / magazine / key lines.
static func tooltip_text(stack: ItemStack) -> String:
	var lines: Array[String] = [stack.item.description]
	if stack.item.stackable():
		lines.append("Count: %d / %d" % [stack.count, stack.item.max_stack])
	if stack.state.has("magazine"):
		lines.append("Magazine: %d" % int(stack.state["magazine"]))
	if not str(stack.state.get("key_id", "")).is_empty():
		lines.append("Key: %s" % stack.state["key_id"])
	if not str(stack.state.get("title", "")).is_empty():
		lines.append('"%s"' % stack.state["title"])
	for attachment in Attachments.fitted(stack.state):
		lines.append("Fitted: " + attachment.label)
	if stack.item.attachment != null:
		lines.append("Drag onto a weapon to fit it (for good).")
	return "\n".join(lines)


func _width() -> float:
	var slots := player_inventory.belt.size() if player_inventory != null else 10
	var columns := inventory().size.x if player_inventory != null else 6
	return maxf(columns * CELL, slots * BELT_SLOT + (slots - 1) * BELT_GAP)
