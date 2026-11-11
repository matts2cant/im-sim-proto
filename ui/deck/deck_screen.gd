class_name DeckScreen
extends CanvasLayer
## The deck's screen (ADR 0112, 0113; the approved mockup design/prototypes/hacking_screens.html),
## child of its user (the Player) beside its DeckSession. Like the Tab interface it is an 85 % panel
## over the dimmed, running world: while it is open the player's input is off, the mouse is free and
## the HUD hidden. Esc or the ✕ lowers it (never also opening the game menu); the deck stays plugged
## in and its tools keep running (LMB on the port again raises it). It closes when the deck unplugs.
## - Title bar: "Deck", the entry point and address, one trace bar per tracer watching the user
##   (DeckSession.tracers(); "unknown tracer" until its host is on the map), ✕.
## - Tools on the left: Map, Icebreaker; Exploits, Firewall and Logs greyed (M12b).
## - Map: NetworkGraph of DeckSession.map_devices() (amber: an account, grey: out of reach); a node's
##   menu: address and status, its accounts (access / "Log in (from <note>)" / Icebreaker / "too
##   strong"), a gateway's note, "Open its desktop (remote)" on a computer with an account, its
##   commands with an account, else who it trusts. Drag pans, the wheel zooms, F fits.
## - Icebreaker: the picked account's letters locking in, the progress bar, Start / Stop / Resume.
## - Skill assists (Icebreaker.assist()): Trained crack times and time left; Advanced + the trace an
##   action adds; Master + how many hidden subnets a gateway routes to.
## - A remote desktop (DeckSession.open_remote()): the user's ComputerScreen draws it over the deck's
##   content area (ComputerScreen.set_remote_area() with that area's anchors); its Esc and "Back to
##   the map" close it (the deck leaves that Esc to it) and the Map shows again.
## - Trace bars in the computer overlay too (ADR 0114's slot): while the user's ComputerScreen is
##   open, one bar per tracer watching the user there (remote: the deck's; bare-handed: the
##   computer's own device and address), refreshed with the screen.

enum Tool { MAP, ICEBREAKER }

const PANEL_FRACTION: float = 0.85
const TOAST_TIME: float = 2.5
const HINT: String = "Click a device. Amber: you have access. Drag to pan, wheel to zoom, F to fit. Esc: lower the deck"
const TETHER_NOTE: String = "Walking away unplugs the deck and stops its tools."
const ASSIST_PREFIX: String = "Computer skill · "
## Bars above this trace (%) turn red.
const HOT_TRACE: float = 70.0
const TRACE_BAR_WIDTH: float = 120.0
const MENU_WIDTH: float = 300.0

var session: DeckSession
## The deck's Icebreaker (beside the session).
var ice: IcebreakerTool
var player: Player
var tool: Tool = Tool.MAP

var root: Control
var title_meta: Label
var trace_box: HBoxContainer
var close_button: Button
var map_button: Button
var ice_button: Button
var graph: NetworkGraph
var map_view: Control
var ice_view: MarginContainer
var ice_column: VBoxContainer
## The area right of the tools and under the bar (the Map, the Icebreaker, a remote desktop).
var content_area: Control
## The user's computer overlay (trace bars, remote desktops), or null.
var computer_screen: ComputerScreen
var toast_label: Label

var _input_before: bool = true
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _hud_before: bool = true
var _refresh_left: float = 0.0
var _toast_left: float = 0.0
var _signature: String = ""
var _ice_signature: String = ""
var _fit_on_show: bool = true
var _computer_left: float = 0.0


func _ready() -> void:
	visible = false
	layer = 22
	player = get_parent() as Player
	_build()
	computer_screen = ComputerScreen.of(get_parent())
	if computer_screen != null:
		computer_screen.opened.connect(_on_computer_opened)


## The anchors (fractions of the viewport) of the deck's content area: where a remote desktop shows.
func content_anchors() -> Rect2:
	var view := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	var rect := content_area.get_global_rect()
	if view.x <= 0.0 or view.y <= 0.0 or rect.size.x <= 0.0:
		return ComputerScreen.REMOTE_AREA
	return Rect2(rect.position / view, rect.end / view)


func _exit_tree() -> void:
	if visible:
		close()


## The DeckScreen child of `node`, or null.
static func of(node: Node) -> DeckScreen:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is DeckScreen:
			return child as DeckScreen
	return null


func is_open() -> bool:
	return visible


## Raises the deck plugged in through `p_session`.
func open_for(p_session: DeckSession) -> void:
	if visible or p_session == null or not p_session.is_plugged():
		return
	session = p_session
	ice = IcebreakerTool.of(session.get_parent())
	if not session.changed.is_connected(_on_changed):
		session.changed.connect(_on_changed)
		session.notice.connect(_on_notice)
		session.remote_changed.connect(_on_remote_changed)
	visible = true
	if player != null:
		_input_before = player.input_enabled
		player.input_enabled = false
		var hud := player.get_node_or_null(^"Hud") as CanvasLayer
		if hud != null:
			_hud_before = hud.visible
			hud.visible = false
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_toast_left = 0.0
	toast_label.visible = false
	_signature = ""
	_ice_signature = ""
	graph.close_menu()
	_fit_on_show = true
	graph.request_fit()
	show_tool(Tool.ICEBREAKER if ice != null and ice.is_running() else Tool.MAP)
	_on_remote_changed(session.remote)
	refresh()


## Lowers the deck (its tools keep running while it stays plugged in).
func close() -> void:
	if not visible:
		return
	visible = false
	graph.close_menu()
	if player != null and is_instance_valid(player):
		player.input_enabled = _input_before
		player.resync_actions()
		var hud := player.get_node_or_null(^"Hud") as CanvasLayer
		if hud != null:
			hud.visible = _hud_before
	Input.mouse_mode = _mouse_before


## Shows the Map or the Icebreaker.
func show_tool(which: Tool) -> void:
	tool = which
	map_view.visible = tool == Tool.MAP
	ice_view.visible = tool == Tool.ICEBREAKER
	map_button.set_pressed_no_signal(tool == Tool.MAP)
	ice_button.set_pressed_no_signal(tool == Tool.ICEBREAKER)
	if tool != Tool.MAP:
		graph.close_menu()
	_ice_signature = ""
	refresh()


## Brings the title bar, the map and the Icebreaker up to date (also every refresh interval).
func refresh() -> void:
	if session == null or not session.is_plugged():
		return
	_refresh_left = session.config.refresh_interval
	title_meta.text = "Plugged into %s · %s" % [entry_label(), _address_text()]
	_refresh_traces()
	if tool == Tool.MAP:
		_refresh_map()
	else:
		_refresh_ice()


## How the title bar names the entry point ("Office Jack (wall jack)").
func entry_label() -> String:
	if session == null or not session.is_plugged():
		return ""
	var name := NetworkSource.display_name(session.port)
	match session.source.kind:
		NetworkSource.Kind.JACK:
			return "%s (wall jack)" % name
		NetworkSource.Kind.PORT:
			return "%s (maintenance port)" % name
	return "%s (computer)" % name


## What a trace bar calls `tracer`: its label once its host is on the map, else "unknown tracer".
func tracer_name(tracer: Tracer) -> String:
	if tracer.device != null and session.map_devices().has(tracer.device):
		return tracer.label
	return "unknown tracer"


## The rows the Map shows now.
func map_rows() -> Array[NetworkRow]:
	var rows: Array[NetworkRow] = []
	if session == null:
		return rows
	var reached := session.reached_devices()
	for device in session.map_devices():
		if not is_instance_valid(device) or not is_instance_valid(device.entity):
			continue
		var row := NetworkRow.new()
		row.device = device
		row.name = NetworkSource.display_name(device)
		row.is_self = session.is_entry(device)
		row.online = reached.has(device) or (row.is_self and device.is_up())
		row.status = DeviceStatus.of(device.entity, row.online)
		row.disabled = row.online and DeviceStatus.is_disabled(device.entity)
		row.has_view = DeviceStatus.has_view(device.entity)
		row.address = device.address
		row.access = session.has_access(device)
		rows.append(row)
	return rows


## The cables between `rows`, as index pairs (lower first), each once.
static func cables_of(rows: Array[NetworkRow]) -> Array[Vector2i]:
	var index_of: Dictionary[Device, int] = {}
	for i in rows.size():
		index_of[rows[i].device] = i
	var pairs: Array[Vector2i] = []
	for i in rows.size():
		for other in rows[i].device.linked():
			if not index_of.has(other):
				continue
			var pair := Vector2i(mini(i, index_of[other]), maxi(i, index_of[other]))
			if not pairs.has(pair):
				pairs.append(pair)
	return pairs


## The visible button labelled `text` anywhere on the screen (tests), or null.
func find_button(text: String) -> Button:
	return _find_button(root, text)


## The open device menu's button labelled `text` (tests), or null.
func menu_button(text: String) -> Button:
	return _find_button(graph.menu, text) if graph.menu.visible else null


## Every visible button label on the open menu (tests).
func menu_texts() -> Array[String]:
	var found: Array[String] = []
	if graph.menu.visible:
		_collect_texts(graph.menu, found)
	return found


## The text of the trace bars, one "<name> <n> %" per tracer (tests).
func trace_texts() -> Array[String]:
	var found: Array[String] = []
	for bar in trace_box.get_children():
		if bar.is_queued_for_deletion():
			continue
		var parts := PackedStringArray()
		for child in bar.get_children():
			if child is Label:
				parts.append((child as Label).text)
		found.append(" ".join(parts))
	return found


## The Icebreaker's visible text lines (tests).
func ice_texts() -> Array[String]:
	var found: Array[String] = []
	_collect_texts(ice_column, found)
	return found


func _process(delta: float) -> void:
	_computer_left -= delta
	if computer_screen != null and computer_screen.is_open() and _computer_left <= 0.0:
		refresh_computer_traces()
	if not visible:
		return
	if session == null or not session.is_plugged():
		close()
		return
	if _toast_left > 0.0:
		_toast_left -= delta
		toast_label.visible = _toast_left > 0.0
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if session != null and session.remote != null:
		# A remote desktop is open over the deck: its own screen takes the keys (Esc goes back).
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"debug_panel_toggle"):
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F and tool == Tool.MAP:
		graph.fit_view()
		get_viewport().set_input_as_handled()


func _on_changed() -> void:
	_signature = ""
	_ice_signature = ""
	if visible:
		refresh()


func _on_notice(text: String) -> void:
	if visible:
		toast_label.text = text
		toast_label.visible = true
		_toast_left = TOAST_TIME
	elif player != null:
		var hud := player.get_node_or_null(^"Hud") as Hud
		if hud != null:
			hud.show_message(text)


func _on_remote_changed(computer: Computer) -> void:
	if computer != null and computer_screen != null:
		computer_screen.set_remote_area(content_anchors())
	elif computer == null:
		_signature = ""
		refresh()


func _on_computer_opened(_computer: Computer, _remote: bool) -> void:
	refresh_computer_traces()


## Fills the computer overlay's trace slot: remote, the deck's tracers; bare-handed, those watching
## that computer for its address.
func refresh_computer_traces() -> void:
	_computer_left = 0.25
	if computer_screen == null or not computer_screen.is_open() or computer_screen.computer == null:
		return
	computer_screen.clear_trace_bars()
	var computer := computer_screen.computer
	var viewer := get_parent()
	var address := computer.address()
	var tracers: Array[Tracer] = []
	if computer_screen.is_remote() and session != null and session.is_plugged():
		address = session.source.address
		tracers = session.tracers()
	elif computer.device != null:
		var seen: Array[Device] = [computer.device]
		tracers = Tracer.bars_for(get_tree(), viewer, seen, address)
	for tracer in tracers:
		var known := tracer.device == computer.device or (session != null and session.map_devices().has(tracer.device))
		var label := tracer.label if known else "unknown tracer"
		computer_screen.add_trace_bar(trace_bar(label, tracer.trace_of(viewer), tracer.model.lockout_left(address)))


func _address_text() -> String:
	var address := session.source.address
	return address if not address.is_empty() else "no address"


func _refresh_map() -> void:
	var rows := map_rows()
	var signature := _signature_of(rows)
	if signature == _signature:
		return
	_signature = signature
	graph.show_network(rows, cables_of(rows))
	if _fit_on_show and not rows.is_empty():
		_fit_on_show = false
		graph.request_fit()


func _signature_of(rows: Array[NetworkRow]) -> String:
	var parts := PackedStringArray()
	for row in rows:
		var progress := 0.0
		var accounts := DeviceAccounts.of(row.device.entity)
		if accounts != null:
			for each in accounts.accounts:
				progress += ice.saved_progress(row.device, each.user)
		parts.append(
			(
				"%s|%s|%s|%s|%s|%d|%s"
				% [
					row.name,
					row.online,
					row.access,
					row.disabled,
					" ".join(row.status),
					roundi(progress * 20.0),
					session.is_blocked(row.device)
				]
			)
		)
	parts.append(str(Icebreaker.assist(session.entity)))
	parts.append(str(Icebreaker.max_strength(session.entity)))
	return "\n".join(parts)


func _refresh_traces() -> void:
	for child in trace_box.get_children():
		DeckStyle.discard(child)
	for tracer in session.tracers():
		var left := tracer.model.lockout_left(session.source.address)
		trace_box.add_child(trace_bar(tracer_name(tracer), tracer.trace_of(session.entity), left))


## One trace bar: `label`, a bar of `value` % (red above HOT_TRACE), "N %" and "blocked N s" while
## `lockout_left` > 0. The deck's title bar and the computer overlay use it.
static func trace_bar(label: String, value: float, lockout_left: float) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 8)
	bar.add_child(DeckStyle.mono(label, DeckStyle.DIM_COLOR, 12))
	var track := Panel.new()
	track.custom_minimum_size = Vector2(TRACE_BAR_WIDTH, 8.0)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_stylebox_override(
		&"panel", DeckStyle.box(DeckStyle.FIELD_COLOR, DeckStyle.LINE_COLOR, 0.0, 0.0, 0.0)
	)
	var fill := ColorRect.new()
	fill.color = DeckStyle.ERROR_COLOR if value > HOT_TRACE else DeckStyle.ALERT_COLOR
	fill.size = Vector2(TRACE_BAR_WIDTH * clampf(value / 100.0, 0.0, 1.0), 8.0)
	track.add_child(fill)
	bar.add_child(track)
	var text := "%d %%" % roundi(value)
	if lockout_left > 0.0:
		text += " · blocked %d s" % ceili(lockout_left)
	bar.add_child(DeckStyle.mono(text, DeckStyle.DIM_COLOR, 12))
	return bar


# The deck's menu for `row` (NetworkGraph.menu_builder).
func _build_menu(row: NetworkRow, column: VBoxContainer) -> void:
	var device := row.device
	if row.is_self and session.source.kind == NetworkSource.Kind.JACK:
		column.add_child(DeckStyle.paragraph("Your entry point.", DeckStyle.DIM_COLOR, 12, MENU_WIDTH - 24.0))
		return
	if row.is_self:
		column.add_child(DeckStyle.paragraph("Your entry point.", DeckStyle.DIM_COLOR, 12, MENU_WIDTH - 24.0))
	if not row.online:
		column.add_child(DeckStyle.label("No connection.", DeckStyle.DIM_COLOR, 13))
		return
	if session.is_blocked(device):
		var left := 0.0
		for tracer in Tracer.watching(device):
			left = maxf(left, tracer.model.lockout_left(session.source.address))
		column.add_child(DeckStyle.label("Blocked by a tracer: %d s" % ceili(left), DeckStyle.ERROR_COLOR, 13))
		return
	var assist := Icebreaker.assist(session.entity)
	var accounts := DeviceAccounts.of(device.entity)
	if accounts != null and not accounts.accounts.is_empty():
		column.add_child(DeckStyle.mono("ACCOUNTS", DeckStyle.DIM_COLOR, 11))
		for each in accounts.accounts:
			column.add_child(_account_row(device, accounts, each, assist))
	var gateway := Gateway.of(device.entity)
	if gateway != null:
		var note := "Hacked: the subnets behind it are on the map."
		if not row.access:
			note = "A gateway. Hack it to see what lies behind it; a subnet behind may hide another gateway."
		column.add_child(DeckStyle.paragraph(note, DeckStyle.DIM_COLOR, 12, MENU_WIDTH - 24.0))
		if assist >= Icebreaker.ASSIST_ROUTES and not row.access:
			var routes := session.hidden_routes(device)
			column.add_child(_assist("routes to %d hidden subnet%s" % [routes, "" if routes == 1 else "s"]))
	if row.access and Computer.of(device.entity) != null:
		var remote := DeckStyle.button("Open its desktop (remote)", 13, true)
		remote.pressed.connect(func() -> void: session.open_remote(device))
		column.add_child(remote)
	if row.access:
		var commands := DeviceStatus.applicable(session.commands_for(device), row.status, row.disabled)
		if not commands.is_empty():
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override(&"h_separation", 6)
			flow.add_theme_constant_override(&"v_separation", 6)
			for command in commands:
				var button := DeckStyle.button(session.config.label_for(command), 13)
				button.pressed.connect(_on_command.bind(command, device))
				flow.add_child(button)
			column.add_child(flow)
	elif accounts == null or accounts.accounts.is_empty():
		var trusted := DeviceNetwork.trusted(device)
		var note := "No accounts."
		if not trusted.is_empty():
			var names := PackedStringArray()
			for each in trusted:
				names.append(NetworkSource.display_name(each))
			note = "No accounts. Trusts %s: control it from that computer's Security app." % ", ".join(names)
		column.add_child(DeckStyle.paragraph(note, DeckStyle.DIM_COLOR, 12, MENU_WIDTH - 24.0))


func _account_row(device: Device, accounts: DeviceAccounts, account: DeviceAccount, assist: int) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 0)
	var known := accounts.knows_login(session.entity, account.user)
	var has := accounts.has_access(session.entity, account.user)
	var detail := DeviceAccount.strength_name(account.strength)
	var can := ice.can_crack(device, account.user)
	if not known and not has and can and assist >= Icebreaker.ASSIST_TIMES:
		detail += " · %s" % _seconds(ice.crack_time(device, account.user))
	info.add_child(DeckStyle.mono(account.user, DeckStyle.TEXT_COLOR, 13))
	info.add_child(DeckStyle.mono(detail, DeckStyle.DIM_COLOR, 11))
	if not known and not has and can and assist >= Icebreaker.ASSIST_TRACE:
		var gain := Tracer.highest_gain(device)
		var progress := ice.saved_progress(device, account.user)
		var trace := (
			(1.0 - progress) * ice.crack_time(device, account.user) * gain * Icebreaker.trace_mult(session.entity)
		)
		info.add_child(DeckStyle.mono(ASSIST_PREFIX + "about +%d %% trace" % roundi(trace), DeckStyle.SELF_COLOR, 11))
	line.add_child(info)
	if has:
		line.add_child(DeckStyle.label("access", DeckStyle.ACCESS_COLOR, 13))
	elif known:
		var source := accounts.known_source(session.entity, account.user)
		var login := DeckStyle.button("Log in (from %s)" % source if not source.is_empty() else "Log in", 12, true)
		login.pressed.connect(func() -> void: session.log_in(device, account.user))
		login.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(login)
	else:
		var progress := ice.saved_progress(device, account.user)
		var text := "Icebreaker" if can else "too strong"
		if can and progress > 0.0:
			text = "Icebreaker (%d %%)" % roundi(progress * 100.0)
		var crack := DeckStyle.button(text, 12)
		crack.disabled = not can
		crack.pressed.connect(_on_crack.bind(device, account.user))
		crack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(crack)
	return line


func _assist(text: String) -> Label:
	var label := DeckStyle.mono(ASSIST_PREFIX + text, DeckStyle.SELF_COLOR, 12)
	var style := DeckStyle.box(Color(0, 0, 0, 0), Color(DeckStyle.SELF_COLOR, 0.5), 4.0, 8.0, 4.0)
	label.add_theme_stylebox_override(&"normal", style)
	return label


func _refresh_ice() -> void:
	var job := ice.job
	var assist := Icebreaker.assist(session.entity)
	var mult := Icebreaker.crack_mult(session.entity)
	var signature := "none"
	if job != null:
		signature = (
			"%s|%d|%s|%s|%d" % [job.key, job.locked_letters(), job.running, job.is_done(), roundi(job.progress * 200.0)]
		)
	signature += "|%d|%s" % [assist, mult]
	if signature == _ice_signature:
		return
	_ice_signature = signature
	for child in ice_column.get_children():
		DeckStyle.discard(child)
	if job == null:
		ice_column.add_child(DeckStyle.label("Icebreaker", DeckStyle.TITLE_COLOR, 20))
		ice_column.add_child(
			DeckStyle.paragraph(
				"Pick an account on the Map to crack its password. Progress stays on the deck if you stop.",
				DeckStyle.DIM_COLOR,
				14,
				480.0
			)
		)
		var names := PackedStringArray()
		for strength in range(Icebreaker.max_strength(session.entity) + 1):
			names.append(DeviceAccount.strength_name(strength as DeviceAccount.Strength))
		ice_column.add_child(
			DeckStyle.paragraph(
				"What your Computer skill can crack: %s." % ", ".join(names), DeckStyle.DIM_COLOR, 14, 480.0
			)
		)
		return
	ice_column.add_child(DeckStyle.label("Icebreaker · %s@%s" % [job.user, job.host], DeckStyle.TITLE_COLOR, 20))
	var strength_line := (
		"Password strength %s · base %s · deterministic"
		% [DeviceAccount.strength_name(job.strength as DeviceAccount.Strength), _seconds(job.base_time)]
	)
	ice_column.add_child(DeckStyle.mono(strength_line, DeckStyle.DIM_COLOR, 12))
	var letters := HBoxContainer.new()
	letters.name = "Letters"
	letters.add_theme_constant_override(&"separation", 6)
	var locked := job.locked_letters()
	for i in job.password.length():
		var shown := job.password[i] if i < locked else "·"
		var cell := DeckStyle.mono(shown, DeckStyle.TITLE_COLOR if i < locked else DeckStyle.DIM_COLOR, 20)
		cell.custom_minimum_size = Vector2(34, 44)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var border := DeckStyle.TITLE_COLOR if i < locked else DeckStyle.LINE_COLOR
		cell.add_theme_stylebox_override(&"normal", DeckStyle.box(DeckStyle.FIELD_COLOR, border, 2.0, 0.0, 0.0))
		letters.add_child(cell)
	ice_column.add_child(letters)
	var track := Panel.new()
	track.custom_minimum_size = Vector2(520, 10)
	track.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	track.add_theme_stylebox_override(
		&"panel", DeckStyle.box(DeckStyle.FIELD_COLOR, DeckStyle.LINE_COLOR, 0.0, 0.0, 0.0)
	)
	var fill := ColorRect.new()
	fill.color = DeckStyle.TITLE_COLOR
	fill.size = Vector2(520.0 * job.progress, 10.0)
	track.add_child(fill)
	ice_column.add_child(track)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override(&"h_separation", 8)
	actions.add_theme_constant_override(&"v_separation", 8)
	if job.is_done():
		actions.add_child(
			DeckStyle.label("Cracked: added to the Journal (Codes and logins)", DeckStyle.ACCESS_COLOR, 14)
		)
		var back := DeckStyle.button("Back to the map", 13)
		back.pressed.connect(show_tool.bind(Tool.MAP))
		actions.add_child(back)
	else:
		var text := "Stop (keeps progress)" if job.running else ("Resume" if job.progress > 0.0 else "Start")
		var toggle := DeckStyle.button(text, 13, not job.running)
		toggle.pressed.connect(_on_ice_toggle)
		actions.add_child(toggle)
		if assist >= Icebreaker.ASSIST_TIMES:
			actions.add_child(_assist("%s left" % _seconds(job.time_left(mult))))
		if assist >= Icebreaker.ASSIST_TRACE and is_instance_valid(ice.device):
			var trace := job.trace_to_finish(
				Tracer.highest_gain(ice.device), mult, Icebreaker.trace_mult(session.entity)
			)
			actions.add_child(_assist("about +%d %% trace to finish" % roundi(trace)))
	ice_column.add_child(actions)
	var note := "Adds trace while it runs (4 %%/s x your skill's trace gain) to every tracer watching %s." % job.host
	if is_instance_valid(ice.device):
		var gain := Tracer.highest_gain(ice.device)
		if gain > 0.0:
			note = (
				"Adds trace while it runs (%s %%/s x your skill's trace gain) to every tracer watching %s."
				% [_number(gain), job.host]
			)
	ice_column.add_child(DeckStyle.paragraph(note, DeckStyle.DIM_COLOR, 12, 480.0))


func _on_crack(device: Device, user: String) -> void:
	if ice.start(device, user):
		show_tool(Tool.ICEBREAKER)


func _on_ice_toggle() -> void:
	if ice.job == null:
		return
	if ice.job.running:
		ice.stop()
	else:
		ice.resume()
	_ice_signature = ""
	refresh()


func _on_command(command: StringName, device: Device) -> void:
	var label := session.config.label_for(command)
	var target := NetworkSource.display_name(device)
	_on_notice("%s: %s sent." % [target, label] if session.send(command, device) else "%s: no connection." % target)
	_signature = ""


static func _seconds(value: float) -> String:
	return "%s s" % _number(value)


static func _number(value: float) -> String:
	var rounded := snappedf(value, 0.1)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(roundi(rounded))
	return "%.1f" % rounded


func _find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var canvas := child as CanvasItem
		if canvas != null and not canvas.visible:
			continue
		var button := child as Button
		if button != null and button.text == text:
			return button
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _collect_texts(node: Node, found: Array[String]) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var canvas := child as CanvasItem
		if canvas != null and not canvas.visible:
			continue
		if child is Button:
			found.append((child as Button).text)
		elif child is Label:
			found.append((child as Label).text)
		_collect_texts(child, found)


func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = DeckStyle.WORLD_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var margin := (1.0 - PANEL_FRACTION) * 0.5
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = margin
	panel.anchor_top = margin
	panel.anchor_right = 1.0 - margin
	panel.anchor_bottom = 1.0 - margin
	var shell := DeckStyle.box(DeckStyle.SCREEN_COLOR, DeckStyle.LINE_COLOR, 6.0, 0.0, 0.0)
	panel.add_theme_stylebox_override(&"panel", shell)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	panel.add_child(column)
	column.add_child(_build_bar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 0)
	column.add_child(body)
	body.add_child(_build_tools())
	var content := Control.new()
	content_area = content
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	body.add_child(content)
	_build_map(content)
	_build_ice(content)
	toast_label = DeckStyle.mono("", DeckStyle.TEXT_COLOR, 13)
	toast_label.name = "Toast"
	toast_label.visible = false
	toast_label.add_theme_stylebox_override(
		&"normal", DeckStyle.box(Color(0, 0, 0, 0.8), Color(0, 0, 0, 0), 4.0, 14.0, 6.0)
	)
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.anchor_top = 1.0
	toast_label.anchor_bottom = 1.0
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_label.offset_bottom = -40.0
	toast_label.z_index = 3
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(toast_label)


func _build_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "Bar"
	bar.add_theme_stylebox_override(
		&"panel", DeckStyle.box(DeckStyle.PANEL_COLOR, DeckStyle.LINE_COLOR, 0.0, 12.0, 6.0)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	bar.add_child(row)
	row.add_child(DeckStyle.label("Deck", DeckStyle.TITLE_COLOR, 16))
	title_meta = DeckStyle.mono("", DeckStyle.DIM_COLOR, 12)
	title_meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title_meta)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(grow)
	trace_box = HBoxContainer.new()
	trace_box.name = "Traces"
	trace_box.add_theme_constant_override(&"separation", 16)
	row.add_child(trace_box)
	close_button = DeckStyle.button("✕", 15)
	close_button.name = "Close"
	close_button.tooltip_text = "Close (Esc): tools keep running while you stay plugged in"
	close_button.pressed.connect(close)
	row.add_child(close_button)
	return bar


func _build_tools() -> Control:
	var tools := PanelContainer.new()
	tools.name = "Tools"
	tools.custom_minimum_size.x = 150.0
	tools.add_theme_stylebox_override(
		&"panel", DeckStyle.box(DeckStyle.PANEL_COLOR, DeckStyle.LINE_COLOR, 0.0, 8.0, 12.0)
	)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	tools.add_child(column)
	map_button = _tool_button("Map")
	map_button.pressed.connect(show_tool.bind(Tool.MAP))
	column.add_child(map_button)
	ice_button = _tool_button("Icebreaker")
	ice_button.pressed.connect(show_tool.bind(Tool.ICEBREAKER))
	column.add_child(ice_button)
	for later: String in ["Exploits", "Firewall", "Logs"]:
		var button := _tool_button("%s  (M12b)" % later)
		button.disabled = true
		column.add_child(button)
	var who := DeckStyle.paragraph(TETHER_NOTE, DeckStyle.DIM_COLOR, 11, 130.0)
	who.custom_minimum_size.y = 40.0
	column.add_child(who)
	return tools


func _tool_button(text: String) -> Button:
	var button := DeckStyle.button(text, 13)
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var on := DeckStyle.box(Color(DeckStyle.TITLE_COLOR, 0.06), DeckStyle.TITLE_COLOR, 4.0, 10.0, 7.0)
	button.add_theme_stylebox_override(&"pressed", on)
	button.add_theme_stylebox_override(&"hover_pressed", on)
	var off := DeckStyle.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4.0, 10.0, 7.0)
	button.add_theme_stylebox_override(&"normal", off)
	button.add_theme_stylebox_override(&"disabled", off)
	return button


func _build_map(content: Control) -> void:
	map_view = Control.new()
	map_view.name = "Map"
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(map_view)
	graph = NetworkGraph.new()
	graph.name = "Graph"
	graph.set_anchors_preset(Control.PRESET_FULL_RECT)
	graph.menu_width = MENU_WIDTH
	graph.menu_builder = _build_menu
	map_view.add_child(graph)
	var hint := DeckStyle.mono(HINT, DeckStyle.DIM_COLOR, 12)
	hint.name = "Hint"
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 16.0
	hint.offset_top = -28.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.add_child(hint)


func _build_ice(content: Control) -> void:
	ice_view = MarginContainer.new()
	ice_view.name = "Icebreaker"
	ice_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		ice_view.add_theme_constant_override("margin_" + side, 18)
	content.add_child(ice_view)
	ice_column = VBoxContainer.new()
	ice_column.add_theme_constant_override(&"separation", 14)
	ice_view.add_child(ice_column)
