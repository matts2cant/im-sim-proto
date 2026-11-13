class_name LootScreen
extends UserScreen
## The loot screen (ADR 0142, design/game/looting.md; approved mockup design/prototypes/looting.html),
## a child of its user that answers to Lootable.SCREEN: a Lootable (E on a downed character or an
## unlocked container) calls Screens.open(user, Lootable.SCREEN, entity). The subject is any entity with an
## Inventory (a Keychain optional); the user needs an Inventory too. Nothing here knows what the
## subject is: its name and state come from EntityNames and the interaction frame's words.
## - Layout (the Tab interface's look, tab_theme.tres): a panel over the dimmed world; the header
##   says "Search", the subject's line ("Guard · unconscious") and has Take all and the close
##   button; the subject's grid and keychain on the left, the user's on the right; a footer with
##   the controls and the latest notice.
## - Items (LootRules): drag a stack between or within the grids (LootGrid, a shared LootDrag:
##   green footprint fits, red not; ammo merges into the other side's stacks; planting allowed);
##   double-click, or Enter on the selected stack, moves it to the first free spot on the other side.
##   Take all takes every item that fits and every key and card; its notice names what stayed.
## - Keys: clicking a key or card on the subject's keychain moves it to the user's ("Keycard added
##   to the keychain: ..."); the user's own stay.
## - Pauses the game (a PauseScreens screen: the tree pauses, every user's input stops) and holds
##   the user's OverlayFocus (input off, mouse free, HUD hidden); the user's notices show in the
##   footer while it is open. Esc or E (`use`) or the close button closes it; it also closes when
##   the subject or user is gone or the user can no longer act.

signal closed

const LAYER: int = 22
const PANEL_MARGIN: float = 0.07
const TITLE := "Search"
const YOU := "You"
const KEYCHAIN := "Keychain"
const TAKE_ALL := "Take all"
const NO_KEYS := "No keys or cards"
const HINT := (
	"Drag items between the two grids · click a key or card to move it · Take all · Esc or E closes"
	+ " · the game is paused"
)
const NOTICE_TIME: float = 2.5
const KEYS_WIDTH: float = 150.0
## The largest grid on either side (6 x 7 cells of LootGrid.CELL); bigger grids get smaller cells.
const GRID_AREA := Vector2(6, 7) * LootGrid.CELL

## The node looting, and the entity looted.
var user: Node = null
var subject: Node = null
var drag := LootDrag.new()
var their_grid: LootGrid
var your_grid: LootGrid
var their_keys: VBoxContainer
var your_keys: VBoxContainer
var title_label: Label
var who_label: Label
var their_caption: Label
var take_all_button: Button
var close_button: Button
var notice_label: TimedLabel

# The grid clicked last (Enter moves its selected stack).
var _selected_grid: LootGrid = null
var _notices: Notices = null

@onready var root: Control = $Root


func _ready() -> void:
	visible = false
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(PauseScreens.GROUP)
	_build()


func _exit_tree() -> void:
	if visible:
		close()


func screen_id() -> StringName:
	return Lootable.SCREEN


## `subject`: the entity looted (it has an Inventory). No options.
func open_screen(p_subject: Object, p_user: Node, _options: Dictionary) -> bool:
	var entity := p_subject as Node
	if Inventory.of(entity) == null or Inventory.of(p_user) == null or entity == p_user:
		return false
	open_for(entity, p_user)
	return true


func close_screen() -> void:
	close()


func shows(p_subject: Object) -> bool:
	return visible and p_subject == subject


## Opens on `p_subject` for `p_user` (both with an Inventory).
func open_for(p_subject: Node, p_user: Node) -> void:
	if visible:
		close()
	subject = p_subject
	user = p_user
	their_grid.bind(Inventory.of(subject))
	your_grid.bind(Inventory.of(user))
	_selected_grid = null
	drag.clear()
	title_label.text = TITLE
	who_label.text = LootRules.subject_line(subject)
	their_caption.text = EntityNames.display_name(subject).to_upper()
	notice_label.clear_text()
	_notices = Notices.of(user)
	if _notices != null:
		_notices.posted.connect(show_notice)
	visible = true
	OverlayFocus.acquire(self, user, Input.MOUSE_MODE_VISIBLE, true)
	PauseScreens.update(get_tree())
	refresh()


func close() -> void:
	if not visible:
		return
	drag.clear()
	visible = false
	if is_instance_valid(_notices) and _notices.posted.is_connected(show_notice):
		_notices.posted.disconnect(show_notice)
	_notices = null
	their_grid.bind(null)
	your_grid.bind(null)
	OverlayFocus.release(self)
	PauseScreens.update(get_tree())
	subject = null
	user = null
	closed.emit()


func subject_inventory() -> Inventory:
	return Inventory.of(subject)


func user_inventory() -> Inventory:
	return Inventory.of(user)


## Rebuilds the keychain columns and Take all's state.
func refresh() -> void:
	if not visible:
		return
	_fill_keys(their_keys, Keychain.of(subject), true)
	_fill_keys(your_keys, Keychain.of(user), false)
	var keys := Keychain.of(subject)
	var has_loot := not subject_inventory().stacks().is_empty() or (keys != null and keys.size() > 0)
	take_all_button.disabled = not has_loot
	their_grid.queue_redraw()
	your_grid.queue_redraw()


## Take all: every item that fits and every key and card; the notice says what stayed.
func take_all() -> void:
	if not visible:
		return
	var stayed := LootRules.take_all(subject_inventory(), user_inventory(), Keychain.of(subject), Keychain.of(user))
	Notices.send(user, LootRules.take_all_notice(stayed))
	refresh()


## Double-click or Enter: `stack` of `grid` to the first free spot on the other side.
func quick_move(grid: LootGrid, stack: ItemStack) -> int:
	var other := your_grid if grid == their_grid else their_grid
	var count := stack.count
	var moved := LootRules.quick_move(grid.inventory, stack, other.inventory)
	if moved < count:
		Notices.send(user, LootRules.NO_ROOM)
	refresh()
	return moved


## Enter: quick-moves the stack selected on the grid clicked last.
func quick_move_selected() -> int:
	var grid := _selected_grid
	if grid == null or grid.selected == null or not grid.inventory.has(grid.selected):
		return 0
	return quick_move(grid, grid.selected)


## A key or card of the subject's keychain to the user's. Returns the entry moved ({}: none).
func take_key(key_id: String) -> Dictionary:
	var entry := LootRules.move_key(Keychain.of(subject), Keychain.of(user), key_id)
	if not entry.is_empty():
		Notices.send(user, LootRules.key_notice(entry))
	refresh()
	return entry


func begin_drag(grid: LootGrid, stack: ItemStack, grab: Vector2i) -> void:
	_select(grid)
	drag.clear()
	drag.stack = stack
	drag.source = grid
	drag.grab = grab
	move_drag(grid.global_cell_center(stack.cell + grab))


func move_drag(at_global: Vector2) -> void:
	if not drag.active():
		return
	drag.at_global = at_global
	drag.target = null
	drag.fits = false
	for grid: LootGrid in [their_grid, your_grid]:
		if grid.has_global_point(at_global):
			drag.target = grid
			drag.cell = grid.cell_at_global(at_global) - drag.grab
			drag.fits = LootRules.drop_fits(drag.source.inventory, drag.stack, grid.inventory, drag.cell)
	their_grid.queue_redraw()
	your_grid.queue_redraw()


## Drops the dragged stack where the mouse is: it lands when it fits there, else nothing moves.
func end_drag(at_global: Vector2) -> int:
	if not drag.active():
		return 0
	move_drag(at_global)
	var moved := 0
	if drag.target != null and drag.fits:
		moved = LootRules.drop(drag.source.inventory, drag.stack, drag.target.inventory, drag.cell)
	drag.clear()
	refresh()
	return moved


## A notice for the user while open (the HUD is hidden).
func show_notice(text: String) -> void:
	if visible:
		notice_label.show_text(text, NOTICE_TIME)


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(user) or not is_instance_valid(subject) or not ActorState.can_act(user):
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"use"):
		close()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		quick_move_selected()
		get_viewport().set_input_as_handled()


func _select(grid: LootGrid) -> void:
	_selected_grid = grid
	var other := your_grid if grid == their_grid else their_grid
	other.selected = null
	other.queue_redraw()


func _on_quick_move_requested(grid: LootGrid, stack: ItemStack) -> void:
	_select(grid)
	drag.clear()
	quick_move(grid, stack)


func _keep_keys() -> void:
	Notices.send(user, LootRules.KEEP_KEYS)


func _fill_keys(box: VBoxContainer, keychain: Keychain, theirs: bool) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var entries: Array[Dictionary] = keychain.keys() if keychain != null else ([] as Array[Dictionary])
	if entries.is_empty():
		var none := TabStyle.label(NO_KEYS, 12, TabStyle.DIM)
		none.name = "Empty"
		box.add_child(none)
		return
	for entry in entries:
		var row := LootKeyRow.make(entry)
		var key_id := str(entry.get("id", ""))
		if theirs:
			row.pressed.connect(take_key.bind(key_id))
		else:
			row.pressed.connect(_keep_keys)
		box.add_child(row)


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = TabStyle.WORLD_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = PANEL_MARGIN
	panel.anchor_top = PANEL_MARGIN
	panel.anchor_right = 1.0 - PANEL_MARGIN
	panel.anchor_bottom = 1.0 - PANEL_MARGIN
	TabStyle.themed(panel, &"TabPanel")
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", 0)
	panel.add_child(box)
	box.add_child(_build_head())
	box.add_child(_rule("HeadRule"))
	var cols := HBoxContainer.new()
	cols.name = "Columns"
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override(&"separation", 0)
	box.add_child(cols)
	their_grid = _build_side(cols, "Theirs", true)
	cols.add_child(TabStyle.divider())
	your_grid = _build_side(cols, "Yours", false)
	box.add_child(_rule("FootRule"))
	box.add_child(_build_foot())


func _build_head() -> MarginContainer:
	var margin := _margin("Head", 16, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	margin.add_child(row)
	title_label = TabStyle.label(TITLE, 18, TabStyle.FG)
	title_label.name = "Title"
	row.add_child(title_label)
	who_label = TabStyle.label("", 13, TabStyle.CAPTION)
	who_label.name = "Who"
	who_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	take_all_button = TabStyle.button(TAKE_ALL, true)
	take_all_button.name = "TakeAll"
	take_all_button.pressed.connect(take_all)
	row.add_child(take_all_button)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.tooltip_text = "Close (Esc or E)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(36, 34)
	TabStyle.themed(close_button, &"TabClose")
	close_button.pressed.connect(close)
	# Two strokes, like the Tab interface's close button (the fallback font may lack the glyph).
	close_button.draw.connect(_draw_close)
	row.add_child(close_button)
	return margin


# One side: its grid (caption above) and its keychain column. Returns the grid.
func _build_side(cols: HBoxContainer, side_name: String, theirs: bool) -> LootGrid:
	var margin := _margin(side_name, 16, 14)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 8)
	row.add_child(left)
	var caption := TabStyle.caption(YOU)
	left.add_child(caption)
	var grid := LootGrid.new()
	grid.name = "Grid"
	grid.max_area = GRID_AREA
	grid.drag = drag
	grid.drag_started.connect(begin_drag)
	grid.drag_moved.connect(move_drag)
	grid.drag_released.connect(end_drag)
	grid.quick_move_requested.connect(_on_quick_move_requested)
	left.add_child(grid)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(KEYS_WIDTH, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 8)
	row.add_child(right)
	right.add_child(TabStyle.caption(KEYCHAIN))
	var keys := VBoxContainer.new()
	keys.name = "Keys"
	keys.add_theme_constant_override(&"separation", 4)
	right.add_child(keys)
	if theirs:
		their_caption = caption
		their_keys = keys
	else:
		your_keys = keys
	return grid


func _build_foot() -> MarginContainer:
	var margin := _margin("Foot", 16, 9)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	margin.add_child(row)
	var hint := TabStyle.label(HINT, 12, TabStyle.DIM)
	hint.name = "Hint"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(hint)
	notice_label = TimedLabel.new()
	notice_label.name = "Notice"
	TabStyle.style_label(notice_label, 12, TabStyle.AMBER)
	row.add_child(notice_label)
	return margin


func _margin(node_name: String, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = node_name
	for side: StringName in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(side, horizontal)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, vertical)
	return margin


func _rule(node_name: String) -> ColorRect:
	var rule := ColorRect.new()
	rule.name = node_name
	rule.color = TabStyle.LINE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _draw_close() -> void:
	var colour := TabStyle.BAD if close_button.is_hovered() else TabStyle.CAPTION
	var centre := close_button.size * 0.5
	var half := 6.0
	close_button.draw_line(centre + Vector2(-half, -half), centre + Vector2(half, half), colour, 2.0, true)
	close_button.draw_line(centre + Vector2(-half, half), centre + Vector2(half, -half), colour, 2.0, true)
