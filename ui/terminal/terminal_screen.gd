class_name TerminalScreen
extends CanvasLayer
## The terminal's 2D screen (ADR 0080), child of its user (the Player). Terminal.use() opens it; the
## game keeps running (it is not a pause screen): while it is open the player's input is off and the
## mouse is free. Esc always leaves, also while typing; E leaves when no text field has focus. It also
## closes when its user can no longer act, walks or is pushed away from the terminal, or the terminal
## goes dead.
## - Login view: user and password fields. When the user's PersonalLog knows this terminal's
##   credentials it shows "Known: <user> from '<entry title>'" and a Fill in button. A wrong login
##   says "Wrong password." (the terminal beeps).
## - Device view: every device Terminal.listing() gives, its state and one button per command it
##   accepts (TerminalConfig labels); a button calls Terminal.send(). Refreshed on open and every
##   `refresh_interval` seconds, so devices it no longer reaches disappear.

const WRONG_PASSWORD: String = "Wrong password."
const HINT: String = "Esc: leave   E: leave (when not typing)"
const STATE_COLORS: Dictionary[String, Color] = {
	Terminal.ONLINE: Color(0.45, 0.95, 0.6),
	Terminal.UNPOWERED: Color(0.95, 0.75, 0.3),
	Terminal.BROKEN: Color(0.95, 0.35, 0.3),
}
const TEXT_COLOR: Color = Color(0.82, 0.95, 0.9)
const DIM_COLOR: Color = Color(0.5, 0.66, 0.64)

var terminal: Terminal
## The node using it (its parent).
var user: Node
var player: Player

var user_field: LineEdit
var password_field: LineEdit
var login_button: Button
var known_label: Label
var fill_button: Button
var message_label: Label
var session_label: Label
var logout_button: Button
var device_list: VBoxContainer
var status_label: Label

var _title: Label
var _login_view: VBoxContainer
var _device_view: VBoxContainer
var _known_row: HBoxContainer
var _input_before: bool = true
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _refresh_left: float = 0.0
var _signature: String = ""


func _ready() -> void:
	visible = false
	user = get_parent()
	player = user as Player
	_build()


## The TerminalScreen child of `node`, or null.
static func of(node: Node) -> TerminalScreen:
	if node == null:
		return null
	for child in node.get_children():
		if child is TerminalScreen:
			return child as TerminalScreen
	return null


func is_open() -> bool:
	return visible


func open(p_terminal: Terminal) -> void:
	if visible or p_terminal == null:
		return
	terminal = p_terminal
	visible = true
	_title.text = terminal.label.to_upper()
	message_label.text = ""
	status_label.text = ""
	user_field.text = ""
	password_field.text = ""
	_signature = ""
	if player != null:
		_input_before = player.input_enabled
		player.input_enabled = false
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_view()


func close() -> void:
	if not visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	visible = false
	terminal = null
	if player != null:
		player.input_enabled = _input_before
		player.resync_actions()
	Input.mouse_mode = _mouse_before


## Copies the known credentials into the fields.
func fill_in() -> void:
	var known := terminal.known_credentials(user) if terminal != null else null
	if known == null:
		return
	user_field.text = known.user
	password_field.text = known.password


## Logs in with what the fields hold.
func submit_login() -> void:
	if terminal == null:
		return
	if terminal.log_in(user_field.text, password_field.text, user):
		message_label.text = ""
		_show_view()
	else:
		message_label.text = WRONG_PASSWORD
		password_field.text = ""


func log_out() -> void:
	if terminal != null:
		terminal.log_out()
		_show_view()


## Sends `command` to `target` and says what happened.
func press(command: StringName, target: Device) -> void:
	if terminal == null:
		return
	var label := terminal.config.label_for(command)
	var target_name := Terminal.display_name(target)
	if terminal.send(command, target):
		status_label.text = "%s: %s sent." % [target_name, label]
	else:
		status_label.text = "%s: no connection." % target_name
	refresh_devices(true)


## Rebuilds the device list when what it shows changed (or `force`).
func refresh_devices(force: bool = false) -> void:
	_refresh_left = terminal.config.refresh_interval if terminal != null else 1.0
	var rows: Array[Terminal.Row] = []
	if terminal != null:
		rows = terminal.listing()
	var signature := _signature_of(rows)
	if signature == _signature and not force:
		return
	_signature = signature
	for child in device_list.get_children():
		device_list.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		device_list.add_child(_label("No devices reached.", DIM_COLOR))
	for row in rows:
		device_list.add_child(_device_row(row))


## The names on the device list now (tests).
func listed_names() -> Array[String]:
	var names: Array[String] = []
	for child in device_list.get_children():
		var name_label := child.get_node_or_null(^"Name") as Label
		if name_label != null:
			names.append(name_label.text)
	return names


## The command button `label` of the row named `device_name`, or null (tests).
func button(device_name: String, label: String) -> Button:
	for child in device_list.get_children():
		var name_label := child.get_node_or_null(^"Name") as Label
		if name_label == null or name_label.text != device_name:
			continue
		for node in child.find_children("*", "Button", true, false):
			if (node as Button).text == label:
				return node as Button
	return null


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"use") and not _typing():
		close()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not visible:
		return
	if not _still_usable():
		close()
		return
	if terminal.logged_in:
		_refresh_left -= delta
		if _refresh_left <= 0.0:
			refresh_devices()


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _still_usable() -> bool:
	if terminal == null or not is_instance_valid(terminal) or not terminal.is_up():
		return false
	if user != null and not ActorState.can_act(user):
		return false
	var user_3d := user as Node3D
	if user_3d != null and is_instance_valid(terminal.entity):
		var distance := user_3d.global_position.distance_to(terminal.entity.global_position)
		if distance > terminal.config.max_use_distance:
			return false
	return true


func _show_view() -> void:
	var logged_in := terminal != null and terminal.logged_in
	_login_view.visible = not logged_in
	_device_view.visible = logged_in
	if logged_in:
		session_label.text = "Logged in as %s" % terminal.username
		refresh_devices(true)
		return
	var known := terminal.known_credentials(user) if terminal != null else null
	_known_row.visible = known != null
	if known != null:
		known_label.text = "Known: %s from '%s'" % [known.user, terminal.credentials_source(user)]
	user_field.grab_focus()


func _signature_of(rows: Array[Terminal.Row]) -> String:
	var parts: PackedStringArray = []
	for row in rows:
		parts.append("%d|%s|%s|%s" % [row.device.get_instance_id(), row.name, row.state, ",".join(row.commands)])
	return ";".join(parts)


func _device_row(row: Terminal.Row) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	var name_label := _label(row.name, TEXT_COLOR)
	name_label.name = "Name"
	name_label.custom_minimum_size.x = 190
	line.add_child(name_label)
	var state_label := _label(row.state, STATE_COLORS.get(row.state, DIM_COLOR))
	state_label.name = "State"
	state_label.custom_minimum_size.x = 90
	line.add_child(state_label)
	var buttons := HFlowContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override(&"h_separation", 6)
	buttons.add_theme_constant_override(&"v_separation", 6)
	for command in row.commands:
		var command_button := Button.new()
		command_button.text = terminal.config.label_for(command)
		command_button.focus_mode = Control.FOCUS_NONE
		command_button.disabled = not row.is_online()
		command_button.pressed.connect(press.bind(command, row.device))
		buttons.add_child(command_button)
	line.add_child(buttons)
	return line


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.07, 0.07, 0.97)
	style.border_color = Color(0.3, 0.75, 0.66, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	_title = _label("TERMINAL", Color(0.55, 0.95, 0.85), 22)
	column.add_child(_title)
	_build_login(column)
	_build_devices(column)
	column.add_child(_label(HINT, DIM_COLOR, 13))


func _build_login(column: VBoxContainer) -> void:
	_login_view = VBoxContainer.new()
	_login_view.add_theme_constant_override(&"separation", 10)
	column.add_child(_login_view)
	_login_view.add_child(_label("Log in", TEXT_COLOR, 17))
	user_field = _field("User", false)
	password_field = _field("Password", true)
	password_field.text_submitted.connect(func(_text: String) -> void: submit_login())
	user_field.text_submitted.connect(func(_text: String) -> void: password_field.grab_focus())
	login_button = Button.new()
	login_button.text = "Log in"
	login_button.focus_mode = Control.FOCUS_NONE
	login_button.pressed.connect(submit_login)
	_login_view.add_child(login_button)
	_known_row = HBoxContainer.new()
	_known_row.add_theme_constant_override(&"separation", 12)
	known_label = _label("", Color(0.55, 0.85, 0.95))
	_known_row.add_child(known_label)
	fill_button = Button.new()
	fill_button.text = "Fill in"
	fill_button.focus_mode = Control.FOCUS_NONE
	fill_button.pressed.connect(fill_in)
	_known_row.add_child(fill_button)
	_login_view.add_child(_known_row)
	message_label = _label("", Color(0.95, 0.4, 0.35))
	_login_view.add_child(message_label)


func _build_devices(column: VBoxContainer) -> void:
	_device_view = VBoxContainer.new()
	_device_view.add_theme_constant_override(&"separation", 10)
	_device_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_device_view)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 12)
	session_label = _label("", TEXT_COLOR, 17)
	session_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(session_label)
	logout_button = Button.new()
	logout_button.text = "Log out"
	logout_button.focus_mode = Control.FOCUS_NONE
	logout_button.pressed.connect(log_out)
	header.add_child(logout_button)
	_device_view.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_device_view.add_child(scroll)
	device_list = VBoxContainer.new()
	device_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	device_list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(device_list)
	status_label = _label("", DIM_COLOR)
	_device_view.add_child(status_label)


func _field(caption: String, secret: bool) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var caption_label := _label(caption, TEXT_COLOR)
	caption_label.custom_minimum_size.x = 100
	row.add_child(caption_label)
	var field := LineEdit.new()
	field.secret = secret
	field.custom_minimum_size.x = 280
	row.add_child(field)
	_login_view.add_child(row)
	return field


func _label(text: String, color: Color, font_size: int = 15) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", font_size)
	return label
