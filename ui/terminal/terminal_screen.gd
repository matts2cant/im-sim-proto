class_name TerminalScreen
extends CanvasLayer
## The terminal's 2D screen (ADR 0080, redesigned by ADR 0083), child of its user (the Player).
## Terminal.use() opens it; the game keeps running (it is not a pause screen): while it is open the
## player's input is off and the mouse is free. Esc leaves, every time (also while typing); E does
## not. It also closes when its user can no longer act, walks or is pushed away from the terminal,
## or the terminal goes dead.
## - Login view: user and password fields. When the user's PersonalLog knows this terminal's
##   credentials it shows "Known: <user> from '<entry title>'" and a Fill in button. A wrong login
##   says "Wrong password." (the terminal beeps).
## - Logged in, two tabs over Terminal.devices() (the terminal's physical network):
##   - Camera: a column listing every device with a view (DeviceStatus.has_view()) and its status;
##     the selected one's live point of view on the right (a FEED_SIZE SubViewport whose Camera3D
##     follows the device's view node, rendered only while the tab shows a live view), "No signal"
##     when it is offline or sees nothing; its status and one button per command it accepts below.
##   - Network: NetworkGraph, the devices as a floor plan with their cables and statuses; a node's
##     menu has its commands.
##   Offline devices (the terminal does not reach them, whatever the reason) are greyed and have no
##   commands. Refreshed on open, after each command and every `refresh_interval` seconds.

enum Tab { CAMERA, NETWORK }

const WRONG_PASSWORD: String = "Wrong password."
const NO_SIGNAL: String = "No signal"
const HINT: String = "Esc: leave"
## Render size of the camera feed (shown scaled to FEED_SHOWN).
const FEED_SIZE: Vector2i = Vector2i(480, 270)
const FEED_SHOWN: Vector2 = Vector2(576, 324)
const FEED_FOV: float = 70.0
const FEED_NEAR: float = 0.05
const FEED_FAR: float = 80.0
const PANEL_SIZE: Vector2 = Vector2(1090, 600)
const TAB_HEIGHT: float = 440.0

var terminal: Terminal
## The node using it (its parent).
var user: Node
var player: Player
var tab: Tab = Tab.CAMERA
## Terminal.devices() at the last refresh.
var rows: Array[Terminal.Row] = []
## The device shown on the Camera tab (null: none).
var camera_device: Device

var user_field: LineEdit
var password_field: LineEdit
var login_button: Button
var known_label: Label
var fill_button: Button
var message_label: Label
var session_label: Label
var logout_button: Button
var camera_tab_button: Button
var network_tab_button: Button
var status_label: Label
var camera_list: VBoxContainer
var feed_viewport: SubViewport
var feed_camera: Camera3D
var feed_rect: TextureRect
var no_signal_label: Label
var camera_title: Label
var camera_status: Label
var camera_actions: HFlowContainer
var graph: NetworkGraph

var _title: Label
var _login_view: VBoxContainer
var _session_view: VBoxContainer
var _camera_view: HBoxContainer
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
	camera_device = null
	graph.close_menu()
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
	rows = []
	camera_device = null
	update_feed()
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


## Shows the Camera or the Network tab.
func show_tab(which: Tab) -> void:
	tab = which
	camera_tab_button.set_pressed_no_signal(tab == Tab.CAMERA)
	network_tab_button.set_pressed_no_signal(tab == Tab.NETWORK)
	_camera_view.visible = tab == Tab.CAMERA
	graph.visible = tab == Tab.NETWORK
	if tab != Tab.NETWORK:
		graph.close_menu()
	update_feed()


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


## Reads the network again and rebuilds what changed (or everything with `force`).
func refresh_devices(force: bool = false) -> void:
	_refresh_left = terminal.config.refresh_interval if terminal != null else 1.0
	var fresh: Array[Terminal.Row] = []
	if terminal != null:
		fresh = terminal.devices()
	rows = fresh
	var signature := _signature_of(rows)
	if signature == _signature and not force:
		return
	_signature = signature
	if _row_of(camera_device) == null:
		camera_device = null
	if camera_device == null:
		for row in rows:
			if row.has_view:
				camera_device = row.device
				break
	_rebuild_camera_list()
	_rebuild_camera_panel()
	graph.show_network(rows, Terminal.cables(rows), terminal.config if terminal != null else null)
	update_feed()


## Shows the device named `device_name` on the Camera tab; false when it has no view (tests).
func select_camera(device_name: String) -> bool:
	for row in rows:
		if row.name == device_name and row.has_view:
			camera_device = row.device
			_rebuild_camera_list()
			_rebuild_camera_panel()
			update_feed()
			return true
	return false


## The names on the Camera tab's list.
func camera_names() -> Array[String]:
	var names: Array[String] = []
	for row in rows:
		if row.has_view:
			names.append(row.name)
	return names


## The Camera tab's list entry of `device_name` (its button), or null.
func camera_entry(device_name: String) -> Button:
	for child in camera_list.get_children():
		var entry := child.get_node_or_null(^"Button") as Button
		if entry != null and not child.is_queued_for_deletion() and entry.text == device_name:
			return entry
	return null


## The Camera tab's command button `label` (for the selected device), or null.
func camera_button(label: String) -> Button:
	for child in camera_actions.get_children():
		var command_button := child as Button
		if command_button != null and not command_button.is_queued_for_deletion() and command_button.text == label:
			return command_button
	return null


## True while the Camera tab shows a live view (the SubViewport renders).
func feed_live() -> bool:
	return feed_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS and feed_rect.visible


## The status words of `device_name` at the last refresh ("" when not on the network).
func status_of(device_name: String) -> String:
	for row in rows:
		if row.name == device_name:
			return TerminalStyle.status_text(row.status)
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		update_feed()


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
	_session_view.visible = logged_in
	if logged_in:
		session_label.text = "Logged in as %s" % terminal.username
		refresh_devices(true)
		show_tab(tab)
		return
	update_feed()
	var known := terminal.known_credentials(user) if terminal != null else null
	_known_row.visible = known != null
	if known != null:
		known_label.text = "Known: %s from '%s'" % [known.user, terminal.credentials_source(user)]
	user_field.grab_focus()


func _row_of(device: Device) -> Terminal.Row:
	if not is_instance_valid(device):
		return null
	for row in rows:
		if row.device == device:
			return row
	return null


## Renders the feed only while the Camera tab shows a device that sees, else "No signal" (every
## frame while open; tests call it after a refresh).
func update_feed() -> void:
	var row := _row_of(camera_device) if visible and tab == Tab.CAMERA and _session_view.visible else null
	var view: Node3D = DeviceStatus.view_of(row.device.entity) if row != null and row.online else null
	var live := view != null and is_instance_valid(view) and view.is_inside_tree()
	if live:
		feed_camera.global_transform = view.global_transform
	feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	feed_rect.visible = live
	no_signal_label.visible = not live
	no_signal_label.text = NO_SIGNAL if is_instance_valid(camera_device) else "No camera on this network."


func _signature_of(p_rows: Array[Terminal.Row]) -> String:
	var parts: PackedStringArray = []
	for row in p_rows:
		var line := (
			"%d|%s|%s|%s|%s"
			% [row.device.get_instance_id(), row.name, row.online, ",".join(row.status), ",".join(row.commands)]
		)
		parts.append(line)
	return ";".join(parts)


func _rebuild_camera_list() -> void:
	for child in camera_list.get_children():
		TerminalStyle.discard(child)
	for row in rows:
		if not row.has_view:
			continue
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override(&"separation", 2)
		var entry_button := TerminalStyle.button(row.name, 15)
		entry_button.name = "Button"
		entry_button.toggle_mode = true
		entry_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry_button.set_pressed_no_signal(row.device == camera_device)
		entry_button.add_theme_color_override(
			&"font_color", TerminalStyle.TEXT_COLOR if row.online else TerminalStyle.OFFLINE_COLOR
		)
		var chosen := StyleBoxFlat.new()
		chosen.bg_color = Color(0.06, 0.16, 0.15)
		chosen.border_color = TerminalStyle.TITLE_COLOR
		chosen.set_border_width_all(1)
		chosen.set_content_margin_all(4)
		entry_button.add_theme_stylebox_override(&"pressed", chosen)
		entry_button.add_theme_stylebox_override(&"hover_pressed", chosen)
		entry_button.pressed.connect(select_camera.bind(row.name))
		entry.add_child(entry_button)
		var status := TerminalStyle.label(
			TerminalStyle.status_text(row.status), TerminalStyle.status_color(row.status), 12
		)
		status.name = "Status"
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(status)
		camera_list.add_child(entry)
	if camera_names().is_empty():
		camera_list.add_child(TerminalStyle.label("No cameras.", TerminalStyle.DIM_COLOR))


func _rebuild_camera_panel() -> void:
	for child in camera_actions.get_children():
		TerminalStyle.discard(child)
	var row := _row_of(camera_device)
	camera_title.text = row.name if row != null else ""
	camera_status.text = TerminalStyle.status_text(row.status) if row != null else ""
	camera_status.add_theme_color_override(
		&"font_color", TerminalStyle.status_color(row.status) if row != null else TerminalStyle.DIM_COLOR
	)
	if row == null:
		return
	for command in row.commands:
		var command_button := TerminalStyle.button(terminal.config.label_for(command))
		command_button.pressed.connect(press.bind(command, row.device))
		camera_actions.add_child(command_button)
	if not row.online:
		camera_actions.add_child(TerminalStyle.label("No connection.", TerminalStyle.DIM_COLOR))


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
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override(&"panel", TerminalStyle.panel_style(TerminalStyle.BORDER_COLOR, 1, 18.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	panel.add_child(column)
	_title = TerminalStyle.label("TERMINAL", TerminalStyle.TITLE_COLOR, 22)
	column.add_child(_title)
	_build_login(column)
	_build_session(column)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(TerminalStyle.label(HINT, TerminalStyle.DIM_COLOR, 13))
	_build_feed()


func _build_login(column: VBoxContainer) -> void:
	_login_view = VBoxContainer.new()
	_login_view.add_theme_constant_override(&"separation", 10)
	column.add_child(_login_view)
	_login_view.add_child(TerminalStyle.label("Log in", TerminalStyle.TEXT_COLOR, 17))
	user_field = _field("User", false)
	password_field = _field("Password", true)
	password_field.text_submitted.connect(func(_text: String) -> void: submit_login())
	user_field.text_submitted.connect(func(_text: String) -> void: password_field.grab_focus())
	login_button = TerminalStyle.button("Log in")
	login_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	login_button.pressed.connect(submit_login)
	_login_view.add_child(login_button)
	_known_row = HBoxContainer.new()
	_known_row.add_theme_constant_override(&"separation", 12)
	known_label = TerminalStyle.label("", Color(0.55, 0.85, 0.95))
	_known_row.add_child(known_label)
	fill_button = TerminalStyle.button("Fill in")
	fill_button.pressed.connect(fill_in)
	_known_row.add_child(fill_button)
	_login_view.add_child(_known_row)
	message_label = TerminalStyle.label("", TerminalStyle.ERROR_COLOR)
	_login_view.add_child(message_label)


func _build_session(column: VBoxContainer) -> void:
	_session_view = VBoxContainer.new()
	_session_view.add_theme_constant_override(&"separation", 8)
	column.add_child(_session_view)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	camera_tab_button = _tab_button("Camera", Tab.CAMERA)
	header.add_child(camera_tab_button)
	network_tab_button = _tab_button("Network", Tab.NETWORK)
	header.add_child(network_tab_button)
	session_label = TerminalStyle.label("", TerminalStyle.DIM_COLOR, 14)
	session_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(session_label)
	logout_button = TerminalStyle.button("Log out")
	logout_button.pressed.connect(log_out)
	header.add_child(logout_button)
	_session_view.add_child(header)
	_build_camera_tab()
	graph = NetworkGraph.new()
	graph.custom_minimum_size = Vector2(0, TAB_HEIGHT)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.command_pressed.connect(press)
	_session_view.add_child(graph)
	status_label = TerminalStyle.label("", TerminalStyle.DIM_COLOR, 14)
	_session_view.add_child(status_label)


func _tab_button(text: String, which: Tab) -> Button:
	var tab_button := TerminalStyle.button(text, 16)
	tab_button.toggle_mode = true
	tab_button.custom_minimum_size.x = 110
	tab_button.pressed.connect(show_tab.bind(which))
	return tab_button


func _build_camera_tab() -> void:
	_camera_view = HBoxContainer.new()
	_camera_view.custom_minimum_size.y = TAB_HEIGHT
	_camera_view.add_theme_constant_override(&"separation", 16)
	_session_view.add_child(_camera_view)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230, TAB_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_camera_view.add_child(scroll)
	camera_list = VBoxContainer.new()
	camera_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(camera_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 8)
	_camera_view.add_child(right)
	var title_row := HBoxContainer.new()
	camera_title = TerminalStyle.label("", TerminalStyle.TITLE_COLOR, 16)
	title_row.add_child(camera_title)
	camera_status = TerminalStyle.label("", TerminalStyle.DIM_COLOR, 14)
	camera_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(camera_status)
	title_row.custom_minimum_size.x = FEED_SHOWN.x
	title_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(title_row)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.0, 0.02, 0.02)
	frame_style.border_color = TerminalStyle.BORDER_COLOR.darkened(0.3)
	frame_style.set_border_width_all(1)
	frame.add_theme_stylebox_override(&"panel", frame_style)
	frame.custom_minimum_size = FEED_SHOWN
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(frame)
	feed_rect = TextureRect.new()
	feed_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed_rect.stretch_mode = TextureRect.STRETCH_SCALE
	feed_rect.custom_minimum_size = FEED_SHOWN
	frame.add_child(feed_rect)
	no_signal_label = TerminalStyle.label(NO_SIGNAL, TerminalStyle.OFFLINE_COLOR, 24)
	no_signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_signal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(no_signal_label)
	camera_actions = HFlowContainer.new()
	camera_actions.custom_minimum_size.x = FEED_SHOWN.x
	camera_actions.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	camera_actions.add_theme_constant_override(&"h_separation", 6)
	camera_actions.add_theme_constant_override(&"v_separation", 6)
	right.add_child(camera_actions)


# The feed's SubViewport shares the level's world (it has no world of its own); its camera is moved
# onto the selected device's view node every frame while live.
func _build_feed() -> void:
	feed_viewport = SubViewport.new()
	feed_viewport.size = FEED_SIZE
	feed_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	feed_viewport.audio_listener_enable_3d = false
	add_child(feed_viewport)
	feed_camera = Camera3D.new()
	feed_camera.fov = FEED_FOV
	feed_camera.near = FEED_NEAR
	feed_camera.far = FEED_FAR
	feed_camera.current = true
	feed_viewport.add_child(feed_camera)
	feed_rect.texture = feed_viewport.get_texture()


func _field(caption: String, secret: bool) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var caption_label := TerminalStyle.label(caption, TerminalStyle.TEXT_COLOR)
	caption_label.custom_minimum_size.x = 100
	row.add_child(caption_label)
	var field := LineEdit.new()
	field.secret = secret
	field.custom_minimum_size.x = 280
	row.add_child(field)
	_login_view.add_child(row)
	return field
