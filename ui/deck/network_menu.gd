class_name NetworkMenu
extends PanelContainer
## The device menu of a NetworkGraph (ADR 0083, 0099, 0113): a small panel beside the selected node,
## kept inside the graph's panel. It shows the device's name, its address and status words in the
## device's colour (DeckStyle.row_color()) and, by default, one button per command of its row (none
## while offline; a button emits `command_pressed`); an owner's `builder` fills it instead (the deck:
## accounts, Icebreaker, actions). Each refresh fills a fresh column aside and reconciles it into the
## shown one (DeckStyle.reconcile()), so a button that looks the same keeps its node, its hover and
## a click held on it across the owner's refresh.

## A default command button was pressed.
signal command_pressed(command: StringName, target: Device)

var title: Label
var status: Label
## The command buttons (or what the owner's builder put there).
var buttons: VBoxContainer


func _init(width: float = NetworkGraph.MENU_WIDTH) -> void:
	visible = false
	custom_minimum_size.x = width
	z_index = 1
	theme_type_variation = &"DeckCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	add_child(column)
	title = DeckStyle.label("", DeckStyle.TITLE_COLOR, 16)
	column.add_child(title)
	status = DeckStyle.label("", DeckStyle.TEXT_COLOR, 13)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = width - 2.0 * WindowFrame.metric(&"space_m")
	column.add_child(status)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 4)
	column.add_child(buttons)


## Shows `row` at `width` px: its name, status and commands. `builder`: Callable(row, column) that
## fills the commands instead (empty: one button per command); `command_label`: command -> button
## label for the default buttons (empty: the words after `command.`).
func show_row(row: NetworkRow, width: float, builder: Callable, command_label: Callable) -> void:
	custom_minimum_size.x = width
	status.custom_minimum_size.x = width - 2.0 * WindowFrame.metric(&"space_m")
	title.text = row.name
	var words := PackedStringArray([row.address]) if not row.address.is_empty() else PackedStringArray()
	words.append_array(row.status)
	status.text = DeviceStatus.text(words)
	status.add_theme_color_override(&"font_color", DeckStyle.row_color(row))
	# Filled aside, then reconciled: a button that looks the same keeps its node (a click held on it
	# survives the owner's refreshes).
	var fresh := VBoxContainer.new()
	if builder.is_valid():
		builder.call(row, fresh)
	else:
		_fill_default(row, fresh, command_label)
	DeckStyle.reconcile(buttons, fresh)


## The shown command button `label`, or null (also while hidden).
func button(label: String) -> Button:
	if not visible:
		return null
	for child in buttons.get_children():
		var command_button := child as Button
		if command_button != null and not command_button.is_queued_for_deletion() and command_button.text == label:
			return command_button
	return null


## The shown command button labels (none while hidden).
func labels() -> Array[String]:
	var found: Array[String] = []
	if visible:
		for child in buttons.get_children():
			if child is Button and not child.is_queued_for_deletion():
				found.append((child as Button).text)
	return found


## Places the menu beside `box` (the selected node as shown, graph coordinates) inside `panel`.
## `side`: the node's side of its bus (NetworkLayout.sides). Places, each slid inside the panel: the
## node's outer side (away from its bus, where its column has no neighbours), below, above, the bus
## side (a hub: below, right, left, above); the first that does not cover the node wins, else the
## first.
func place(box: Rect2, side: int, panel: Vector2) -> void:
	reset_size()
	var menu_size := get_combined_minimum_size()
	size = menu_size
	var gap := NetworkGraph.MENU_GAP
	var middle := box.get_center()
	var below := Vector2(middle.x - menu_size.x * 0.5, box.end.y + gap)
	var above := Vector2(middle.x - menu_size.x * 0.5, box.position.y - gap - menu_size.y)
	var right := Vector2(box.end.x + gap, box.position.y)
	var left := Vector2(box.position.x - gap - menu_size.x, box.position.y)
	var candidates: Array[Vector2] = [below, right, left, above]
	if side > 0:
		candidates = [right, below, above, left]
	elif side < 0:
		candidates = [left, below, above, right]
	var limit := (panel - menu_size).max(Vector2.ZERO)
	var at := candidates[0].clamp(Vector2.ZERO, limit)
	for candidate in candidates:
		var slid := candidate.clamp(Vector2.ZERO, limit)
		if not Rect2(slid, menu_size).intersects(box):
			at = slid
			break
	position = at


# One button per command of `row` (a note when there is none).
func _fill_default(row: NetworkRow, column: VBoxContainer, command_label: Callable) -> void:
	for command in row.commands:
		var text := String(command.trim_prefix("command.")).capitalize()
		if command_label.is_valid():
			text = str(command_label.call(command))
		var command_button := DeckStyle.button(text, 14)
		command_button.pressed.connect(func() -> void: command_pressed.emit(command, row.device))
		column.add_child(command_button)
	if row.commands.is_empty():
		var reason := "No connection." if not row.online else "No commands."
		column.add_child(DeckStyle.label(reason, DeckStyle.DIM_COLOR, 13))
