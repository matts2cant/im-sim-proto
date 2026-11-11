class_name ComputerScreen
extends CanvasLayer
## The Halcyon OS overlay (ADR 0114; replaces the terminal screen of ADR 0080 / 0083), child of its
## user (the Player). Computer.use_by() (bare-handed) and Computer.open_desktop() (bare-handed or
## remote) open it. Like the Tab interface (ADR 0110): an 85 % panel over the dimmed, still running
## world (not a pause screen); while open the player's input is off, the mouse is free and the HUD
## hidden; Esc or the ✕ leaves, every time (also while typing), and that Esc never also opens the
## game menu; E never leaves. It closes when its user can no longer act (dead, knocked out) or the
## computer goes dead; a bare-handed session also closes when its user walks or is pushed away.
## - Title bar: "Halcyon OS", the host name and address (when the device has one), the account and
##   its access level once logged in, a slot for trace bars (trace_bars(), add_trace_bar(): the
##   network layer fills it), ✕.
## - Login: user and password fields, an error line, and every login the user's PersonalLog knows
##   for this computer with a "Fill in" button; Enter in either field logs in
##   (Computer.log_in() -> DeviceAccounts.try_login()).
## - Desktop: a dock with Mail, Files and Security (DocumentApp, SecurityApp), the account, Log out.
## - Remote (from the deck): the same desktop inside the deck's panel area (`remote_area`, above
##   the deck's layer), "Remote desktop" in its bar and "Back to the map", which closes it (so does
##   Esc) and emits the computer's `desktop_closed`. Walking away does not close it (the deck's
##   tether does); it never opens the computer's local session.

## A desktop opened (`remote`: inside the deck); the network layer adds trace bars on it.
signal opened(computer: Computer, remote: bool)
signal closed(computer: Computer)

enum App { MAIL, FILES, SECURITY }

const LAYER: int = 24
## Above the deck's overlay.
const REMOTE_LAYER: int = 26
const PANEL_FRACTION: float = 0.85
const WRONG_LOGIN := "Wrong user or password."
const NO_KNOWN := "None. Find one, or crack it with the deck."
const HINT := "Esc: leave"
const APP_NAMES: Array[String] = ["Mail", "Files", "Security"]
const APP_IDS: Array[StringName] = [Computer.MAIL, Computer.FILES, Computer.SECURITY]
const DOCK_WIDTH: float = 96.0
## Anchors of the panel when remote (position: left, top; end: right, bottom), unless the deck sets
## its own: the deck's content area in the mockup (below its 45 px bar, right of its 150 px tools
## column, in a 1280 x 720 frame whose 85 % panel starts at 7.5 %).
const REMOTE_AREA := Rect2(0.1921875, 0.1375, 0.7328125, 0.7875)

var computer: Computer
## The node using it (its parent).
var user: Node
var player: Player
## The account the desktop shows ("" while on the login).
var account: String = ""
var remote: bool = false
var app: App = App.MAIL
var remote_area: Rect2 = REMOTE_AREA

var panel: PanelContainer
var title_label: Label
var meta_label: Label
var account_label: Label
var close_button: Button
var back_button: Button
var user_field: LineEdit
var password_field: LineEdit
var login_button: Button
var error_label: Label
var login_title: Label
var known_box: VBoxContainer
var desktop: HBoxContainer
var login_view: CenterContainer
var dock_buttons: Array[Button] = []
var who_label: Label
var logout_button: Button
var mail_app: DocumentApp
var files_app: DocumentApp
var security_app: SecurityApp

var _dim: ColorRect
var _bar: PanelContainer
var _trace_bars: HBoxContainer
var _input_before: bool = true
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _hud_before: bool = true
var _refresh_left: float = 0.0


func _ready() -> void:
	visible = false
	layer = LAYER
	user = get_parent()
	player = user as Player
	_build()


func _exit_tree() -> void:
	if visible:
		close()


## The ComputerScreen child of `node`, or null.
static func of(node: Node) -> ComputerScreen:
	if node == null:
		return null
	for child in node.get_children():
		if child is ComputerScreen:
			return child as ComputerScreen
	return null


func is_open() -> bool:
	return visible


func is_remote() -> bool:
	return visible and remote


## The trace bar slot in the title bar.
func trace_bars() -> HBoxContainer:
	return _trace_bars


## Adds `bar` (any Control) to the title bar's trace slot.
func add_trace_bar(bar: Control) -> void:
	_trace_bars.add_child(bar)


func clear_trace_bars() -> void:
	for child in _trace_bars.get_children():
		HalcyonStyle.discard(child)


## The deck's content area (anchors) a remote desktop fills.
func set_remote_area(anchors: Rect2) -> void:
	remote_area = anchors
	if is_remote():
		_place_panel()


## Opens `p_computer`: its desktop as `p_user`, or its login when `p_user` is empty (bare-handed
## only); `p_remote` inside the deck.
func open(p_computer: Computer, p_user: String, p_remote: bool) -> void:
	if p_computer == null:
		return
	if visible:
		close()
	computer = p_computer
	remote = p_remote
	account = p_user
	visible = true
	layer = REMOTE_LAYER if remote else LAYER
	_dim.visible = not remote
	_place_panel()
	if player != null:
		_input_before = player.input_enabled
		player.input_enabled = false
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hud := _hud()
	if hud != null:
		_hud_before = hud.visible
		hud.visible = false
	user_field.text = ""
	password_field.text = ""
	error_label.text = ""
	_show_view()
	opened.emit(computer, remote)


func close() -> void:
	if not visible:
		return
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and panel.is_ancestor_of(focused):
		focused.release_focus()
	visible = false
	security_app.shown = false
	security_app.update_feed()
	var hud := _hud()
	if hud != null:
		hud.visible = _hud_before
	if is_instance_valid(player):
		player.input_enabled = _input_before
		player.resync_actions()
	Input.mouse_mode = _mouse_before
	var was := computer
	var was_remote := remote
	computer = null
	account = ""
	if is_instance_valid(was):
		if was_remote:
			was.desktop_closed.emit()
		closed.emit(was)


## Copies known login `index` (known_logins()) into the fields.
func fill_in(index: int = 0) -> void:
	var known := _known()
	if index < 0 or index >= known.size():
		return
	user_field.text = known[index].user
	password_field.text = known[index].password


## The "Fill in" buttons, one per known login.
func fill_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for row in known_box.get_children():
		var button := row.get_node_or_null(^"Fill") as Button
		if button != null and not row.is_queued_for_deletion():
			buttons.append(button)
	return buttons


## The users of the known logins offered, in order.
func known_users() -> Array[String]:
	var users: Array[String] = []
	for login in _known():
		users.append(login.user)
	return users


## Logs in with what the fields hold.
func submit_login() -> void:
	if computer == null or remote:
		return
	if computer.log_in(user_field.text, password_field.text, user):
		error_label.text = ""
		account = computer.session_user
		_show_view()
	else:
		error_label.text = WRONG_LOGIN
		password_field.text = ""


func log_out() -> void:
	if computer == null or remote:
		return
	computer.log_out()
	account = ""
	_show_view()


## Shows `which` app on the desktop.
func show_app(which: App) -> void:
	app = which
	for i in dock_buttons.size():
		dock_buttons[i].set_pressed_no_signal(i == app)
	mail_app.visible = app == App.MAIL
	files_app.visible = app == App.FILES
	security_app.visible = app == App.SECURITY
	security_app.shown = app == App.SECURITY
	match app:
		App.MAIL:
			mail_app.show_documents(computer, user, computer.documents(Computer.MAIL, account), "Mail")
		App.FILES:
			files_app.show_documents(computer, user, computer.documents(Computer.FILES, account), "Files")
		App.SECURITY:
			security_app.bind(computer, user)
			_refresh_left = computer.config.refresh_interval
	security_app.update_feed()


## True while the desktop (not the login) shows.
func desktop_shown() -> bool:
	return visible and desktop.visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		security_app.update_feed()


func _physics_process(delta: float) -> void:
	if not visible:
		return
	if not _still_usable():
		close()
		return
	if desktop.visible and app == App.SECURITY:
		_refresh_left -= delta
		if _refresh_left <= 0.0:
			_refresh_left = computer.config.refresh_interval
			security_app.refresh()


func _still_usable() -> bool:
	if computer == null or not is_instance_valid(computer) or not computer.is_up():
		return false
	if user != null and not ActorState.can_act(user):
		return false
	if remote:
		return true
	var user_3d := user as Node3D
	if user_3d != null and is_instance_valid(computer.entity):
		var distance := user_3d.global_position.distance_to(computer.entity.global_position)
		if distance > computer.config.max_use_distance:
			return false
	return true


func _known() -> Array[LoginCredentials]:
	return computer.known_logins(user) if computer != null else [] as Array[LoginCredentials]


func _show_view() -> void:
	var logged_in := not account.is_empty()
	login_view.visible = not logged_in
	desktop.visible = logged_in
	_update_bar()
	if logged_in:
		who_label.text = "%s\n%s" % [account, computer.access_level(account)]
		logout_button.visible = not remote
		for i in dock_buttons.size():
			var icon := dock_buttons[i].get_node(^"Column/Icon") as DeviceIcon
			icon.strokes = computer.config.app_icons.get(APP_IDS[i], PackedStringArray())
		show_app(app)
		return
	security_app.shown = false
	security_app.update_feed()
	login_title.text = computer.label.capitalize()
	if not computer.host_name.is_empty():
		login_title.text += " · " + computer.host_name
	_rebuild_known()
	user_field.grab_focus()


func _update_bar() -> void:
	var parts := PackedStringArray()
	if remote:
		parts.append("Halcyon OS")
	if not computer.host_name.is_empty():
		parts.append(computer.host_name)
	var address := computer.address()
	if not address.is_empty():
		parts.append(address)
	title_label.text = "Remote desktop" if remote else "Halcyon OS"
	meta_label.text = " · ".join(parts)
	account_label.text = "%s · %s" % [account, computer.access_level(account)] if not account.is_empty() else ""
	close_button.visible = not remote
	back_button.visible = remote
	_bar.add_theme_stylebox_override(&"panel", _bar_style())


func _bar_style() -> StyleBoxFlat:
	var style := HalcyonStyle.box(HalcyonStyle.REMOTE_BAR if remote else HalcyonStyle.OS_PANEL, HalcyonStyle.LINE, 0, 0)
	style.border_width_bottom = 1
	style.content_margin_left = 12
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _rebuild_known() -> void:
	for child in known_box.get_children():
		HalcyonStyle.discard(child)
	var known := _known()
	if known.is_empty():
		known_box.add_child(HalcyonStyle.label(NO_KNOWN, 13, HalcyonStyle.DIM))
		return
	for i in known.size():
		var row := HBoxContainer.new()
		row.name = "Known%d" % i
		row.add_theme_constant_override(&"separation", 10)
		var text := known[i].user
		if not known[i].source.is_empty():
			text += "  · from %s" % known[i].source
		var known_label := HalcyonStyle.label(text, 13, HalcyonStyle.TEXT, true)
		known_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		known_label.clip_text = true
		row.add_child(known_label)
		var fill := HalcyonStyle.button("Fill in")
		fill.name = "Fill"
		fill.pressed.connect(fill_in.bind(i))
		row.add_child(fill)
		known_box.add_child(row)


func _place_panel() -> void:
	var margin := (1.0 - PANEL_FRACTION) * 0.5
	var area := remote_area if remote else Rect2(Vector2(margin, margin), Vector2.ONE * PANEL_FRACTION)
	panel.anchor_left = area.position.x
	panel.anchor_top = area.position.y
	panel.anchor_right = area.end.x
	panel.anchor_bottom = area.end.y
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0


func _hud() -> CanvasLayer:
	return player.get_node_or_null(^"Hud") as CanvasLayer if is_instance_valid(player) else null


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = TabStyle.WORLD_DIM
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_dim)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override(&"panel", HalcyonStyle.box(HalcyonStyle.OS_BG, HalcyonStyle.LINE, 1, 6))
	panel.clip_contents = true
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	panel.add_child(column)
	_build_bar(column)
	var body := Control.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_build_login(body)
	_build_desktop(body)
	_place_panel()


func _build_bar(column: VBoxContainer) -> void:
	_bar = PanelContainer.new()
	_bar.name = "Bar"
	column.add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	_bar.add_child(row)
	title_label = HalcyonStyle.label("Halcyon OS", 15, HalcyonStyle.TEAL)
	title_label.name = "Title"
	row.add_child(title_label)
	meta_label = HalcyonStyle.label("", 12, HalcyonStyle.DIM, true)
	meta_label.name = "Meta"
	row.add_child(meta_label)
	account_label = HalcyonStyle.label("", 12, HalcyonStyle.DIM, true)
	account_label.name = "Account"
	row.add_child(account_label)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grow)
	_trace_bars = HBoxContainer.new()
	_trace_bars.name = "TraceBars"
	_trace_bars.add_theme_constant_override(&"separation", 14)
	row.add_child(_trace_bars)
	back_button = HalcyonStyle.button("Back to the map")
	back_button.name = "Back"
	back_button.pressed.connect(close)
	row.add_child(back_button)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "✕"
	close_button.tooltip_text = "Close (Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.flat = true
	close_button.custom_minimum_size = Vector2(34, 28)
	close_button.add_theme_font_size_override(&"font_size", 15)
	close_button.add_theme_color_override(&"font_color", HalcyonStyle.DIM)
	close_button.add_theme_color_override(&"font_hover_color", HalcyonStyle.BAD)
	close_button.pressed.connect(close)
	row.add_child(close_button)


func _build_login(body: Control) -> void:
	login_view = CenterContainer.new()
	login_view.name = "Login"
	login_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(login_view)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 0)
	card.add_theme_stylebox_override(&"panel", HalcyonStyle.box(HalcyonStyle.OS_PANEL, HalcyonStyle.LINE, 1, 6, 26))
	login_view.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)
	box.add_child(HalcyonStyle.label("HALCYON OS", 22, HalcyonStyle.TEAL))
	login_title = HalcyonStyle.label("", 12, HalcyonStyle.DIM, true)
	box.add_child(login_title)
	box.add_child(HalcyonStyle.label("User", 12, HalcyonStyle.DIM, true))
	user_field = HalcyonStyle.field(false)
	user_field.name = "User"
	user_field.text_submitted.connect(func(_text: String) -> void: submit_login())
	box.add_child(user_field)
	box.add_child(HalcyonStyle.label("Password", 12, HalcyonStyle.DIM, true))
	password_field = HalcyonStyle.field(true)
	password_field.name = "Password"
	password_field.text_submitted.connect(func(_text: String) -> void: submit_login())
	box.add_child(password_field)
	error_label = HalcyonStyle.label("", 12, HalcyonStyle.BAD, true)
	error_label.custom_minimum_size = Vector2(0, 16)
	box.add_child(error_label)
	login_button = HalcyonStyle.button("Log in", true)
	login_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	login_button.pressed.connect(submit_login)
	box.add_child(login_button)
	box.add_child(HalcyonStyle.rule())
	box.add_child(HalcyonStyle.caption("Logins you know for this machine"))
	known_box = VBoxContainer.new()
	known_box.name = "Known"
	known_box.add_theme_constant_override(&"separation", 6)
	box.add_child(known_box)
	box.add_child(HalcyonStyle.label(HINT, 11, HalcyonStyle.DIM, true))


func _build_desktop(body: Control) -> void:
	desktop = HBoxContainer.new()
	desktop.name = "Desktop"
	desktop.set_anchors_preset(Control.PRESET_FULL_RECT)
	desktop.add_theme_constant_override(&"separation", 0)
	body.add_child(desktop)
	var dock := PanelContainer.new()
	dock.name = "Dock"
	dock.custom_minimum_size = Vector2(DOCK_WIDTH, 0)
	dock.add_theme_stylebox_override(&"panel", HalcyonStyle.box(HalcyonStyle.OS_PANEL, HalcyonStyle.LINE, 0, 0, 8))
	desktop.add_child(dock)
	var dock_box := VBoxContainer.new()
	dock_box.add_theme_constant_override(&"separation", 10)
	dock.add_child(dock_box)
	for i in APP_NAMES.size():
		var button := _dock_button(i)
		dock_buttons.append(button)
		dock_box.add_child(button)
	who_label = HalcyonStyle.label("", 11, HalcyonStyle.DIM, true)
	who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dock_box.add_child(who_label)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_box.add_child(grow)
	logout_button = HalcyonStyle.button("Log out")
	logout_button.pressed.connect(log_out)
	dock_box.add_child(logout_button)
	var hint := HalcyonStyle.label(HINT, 11, HalcyonStyle.DIM, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dock_box.add_child(hint)
	desktop.add_child(HalcyonStyle.rule(true))
	var window := Control.new()
	window.name = "Window"
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.clip_contents = true
	desktop.add_child(window)
	mail_app = DocumentApp.new()
	mail_app.name = "Mail"
	files_app = DocumentApp.new()
	files_app.name = "Files"
	security_app = SecurityApp.new()
	security_app.name = "Security"
	for app_node: Control in [mail_app, files_app, security_app]:
		app_node.set_anchors_preset(Control.PRESET_FULL_RECT)
		window.add_child(app_node)


func _dock_button(index: int) -> Button:
	var button := HalcyonStyle.list_entry()
	button.name = APP_NAMES[index]
	button.custom_minimum_size = Vector2(DOCK_WIDTH - 16.0, 62)
	button.pressed.connect(show_app.bind(index))
	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var icon := DeviceIcon.make(PackedStringArray(), HalcyonStyle.TEXT, 28.0)
	icon.name = "Icon"
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var caption := HalcyonStyle.label(APP_NAMES[index], 12, HalcyonStyle.TEXT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)
	return button
