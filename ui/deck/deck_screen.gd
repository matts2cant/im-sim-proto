class_name DeckScreen
extends CanvasLayer
## The deck's screen (ADR 0112, 0113; the approved mockup design/prototypes/hacking_screens.html),
## child of its user (the Player) beside its DeckSession. Like the Tab interface it is an 85 % panel
## over the dimmed, running world: while it is open the player's input is off, the mouse is free and
## the HUD hidden. Esc or the ✕ lowers it (never also opening the game menu); the deck stays plugged
## in and its tools keep running (LMB on the port again raises it). It closes when the deck unplugs.
## This host owns the window (a WindowFrame: header, tools sidebar, body) and switches the tools:
## - Header: "Deck", the entry point and address, one trace bar per tracer watching the user
##   (DeckTraceBars; "unknown tracer" until its host is on the map), ✕.
## - Tools in the sidebar: Map (DeckMapView, its menus DeckDeviceMenu), Icebreaker (DeckIceView),
##   Exploits (ExploitsView), Firewall (FirewallView); Logs greyed (M16). Wi-Fi (WifiPanel, M12b,
##   ADR 0117): open_wifi() raises it on the Wi-Fi key screen, plugged in or not.
## - Refreshes (every refresh interval, every session change) keep the buttons under the cursor: the
##   Map rebuilds its nodes only when they change, the menu and the Icebreaker are filled aside and
##   reconciled (DeckStyle.reconcile()), the trace bars update in place, so a still cursor keeps its
##   hover and a still click held across a refresh lands.
## - A remote desktop (DeckSession.open_remote()): the user's ComputerScreen draws it over the deck's
##   body (ComputerScreen.set_remote_area() with that area's anchors); its Esc and "Back to the map"
##   close it (the deck leaves that Esc to it) and the Map shows again.
## - Trace bars in the computer overlay too (ADR 0114's slot): while the user's ComputerScreen is
##   open, one bar per tracer watching the user there (DeckTraceBars.computer_bars()).

enum Tool { MAP, ICEBREAKER, WIFI, EXPLOITS, FIREWALL }

const PANEL_FRACTION: float = 0.85
const TOAST_TIME: float = 2.5
const TETHER_NOTE: String = "Walking away unplugs the deck and stops its tools."
const WIRELESS_NOTE: String = "Leaving the access point's range drops the Wi-Fi and stops its tools."
const UNPLUGGED_NOTE: String = DeckMapView.UNPLUGGED_NOTE
const COMPUTER_TRACE_INTERVAL: float = 0.25

var session: DeckSession
## The deck's Icebreaker (beside the session).
var ice: IcebreakerTool
## The deck's Exploits tool (beside the session).
var exploit_tool: ExploitTool
var wireless: WirelessTool
var player: Player
var tool: Tool = Tool.MAP

var root: Control
var frame: WindowFrame
var title_meta: Label
var trace_box: HBoxContainer
var close_button: Button
var map_button: Button
var ice_button: Button
var exploits_button: Button
var firewall_button: Button
var map_view: DeckMapView
var graph: NetworkGraph
## The Map's line while unplugged (UNPLUGGED_NOTE).
var unplugged_label: Label
var ice_view: DeckIceView
var exploits_view: ExploitsView
var firewall_view: FirewallView
var wifi_view: WifiPanel
var tether_label: Label
## The frame's body, right of the tools and under the header (the tools, a remote desktop).
var content_area: Control
## The user's computer overlay (trace bars, remote desktops), or null.
var computer_screen: ComputerScreen
var toast_label: Label

var _input_before: bool = true
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _hud_before: bool = true
var _refresh_left: float = 0.0
var _toast_left: float = 0.0
var _computer_left: float = 0.0


func _ready() -> void:
	visible = false
	layer = 22
	player = get_parent() as Player
	_build()
	computer_screen = ComputerScreen.of(get_parent())
	if computer_screen != null:
		computer_screen.opened.connect(_on_computer_opened)
	if DeckSession.of(get_parent()) != null:  # Notices reach the HUD before a first raise.
		DeckSession.of(get_parent()).notice.connect(show_notice)


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


## The anchors (fractions of the viewport) of the deck's body: where a remote desktop shows.
func content_anchors() -> Rect2:
	var view := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	var rect := content_area.get_global_rect()
	if view.x <= 0.0 or view.y <= 0.0 or rect.size.x <= 0.0:
		return ComputerScreen.REMOTE_AREA
	return Rect2(rect.position / view, rect.size / view)


func is_open() -> bool:
	return visible


## Raises the deck plugged in through `p_session`.
func open_for(p_session: DeckSession) -> void:
	if visible or p_session == null or not p_session.is_plugged():
		return
	_raise(p_session, Tool.MAP)


## Raises the deck on the Wi-Fi key screen of the access point `p_session`'s WirelessTool aims at
## (plugged in or not).
func open_wifi(p_session: DeckSession) -> void:
	if visible or p_session == null or WirelessTool.of(p_session.get_parent()) == null:
		return
	_raise(p_session, Tool.WIFI)


func _raise(p_session: DeckSession, which: Tool) -> void:
	session = p_session
	ice = IcebreakerTool.of(session.get_parent())
	exploit_tool = ExploitTool.of(session.get_parent())
	wireless = WirelessTool.of(session.get_parent())
	map_view.bind(session, ice, exploit_tool)
	ice_view.bind(session, ice)
	exploits_view.bind(session, exploit_tool)
	firewall_view.bind(session)
	if not session.changed.is_connected(_on_changed):
		session.changed.connect(_on_changed)
		session.remote_changed.connect(_on_remote_changed)
	if not session.notice.is_connected(show_notice):
		session.notice.connect(show_notice)
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
	map_view.reset()
	ice_view.invalidate()
	if which == Tool.MAP and ice != null and ice.is_running():
		which = Tool.ICEBREAKER
	elif which == Tool.MAP and exploit_tool != null and exploit_tool.is_running():
		which = Tool.EXPLOITS
	show_tool(which)
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


## Shows the Map, the Icebreaker, the Exploits tool or the Firewall (on the router picked last,
## else the first the user is admin of).
func show_tool(which: Tool) -> void:
	tool = which
	map_view.visible = tool == Tool.MAP
	ice_view.visible = tool == Tool.ICEBREAKER
	exploits_view.visible = tool == Tool.EXPLOITS
	firewall_view.visible = tool == Tool.FIREWALL
	wifi_view.visible = tool == Tool.WIFI
	map_button.set_pressed_no_signal(tool == Tool.MAP)
	ice_button.set_pressed_no_signal(tool == Tool.ICEBREAKER)
	exploits_button.set_pressed_no_signal(tool == Tool.EXPLOITS)
	firewall_button.set_pressed_no_signal(tool == Tool.FIREWALL)
	if tool != Tool.MAP:
		graph.close_menu()
	if tool == Tool.FIREWALL and firewall_view.router() == null:
		var fallback := firewall_view.default_router()
		if fallback != null:
			firewall_view.show_router(fallback)
	ice_view.invalidate()
	refresh()


## Brings the header and the shown tool up to date (also every refresh interval).
func refresh() -> void:
	if session == null or (not session.is_plugged() and tool != Tool.WIFI and tool != Tool.MAP):
		return
	_refresh_left = session.config.refresh_interval
	ice_button.disabled = not session.is_plugged()
	exploits_button.disabled = not session.is_plugged()
	firewall_button.disabled = not session.is_plugged()
	tether_label.text = WIRELESS_NOTE if session.is_wireless() else TETHER_NOTE
	if tool == Tool.WIFI:
		title_meta.text = WifiPanel.title_text(wireless)
	elif not session.is_plugged():
		title_meta.text = "Not plugged in"
	else:
		var verb := "Joined" if session.is_wireless() else "Plugged into"
		title_meta.text = "%s %s · %s" % [verb, entry_label(), _address_text()]
	DeckTraceBars.show_bars(trace_box, DeckTraceBars.deck_bars(session, wireless, tool == Tool.WIFI, tracer_name))
	match tool:
		Tool.MAP:
			map_view.refresh()
		Tool.ICEBREAKER:
			ice_view.refresh()
		Tool.EXPLOITS:
			exploits_view.refresh()
		Tool.FIREWALL:
			firewall_view.refresh()
		Tool.WIFI:
			wifi_view.show_for(wireless)


## How the header names the entry point ("Office Jack (wall jack)").
func entry_label() -> String:
	if session == null or not session.is_plugged():
		return ""
	var name := NetworkSource.display_name(session.port)
	match session.source.kind:
		NetworkSource.Kind.JACK:
			return "%s (wall jack)" % name
		NetworkSource.Kind.PORT:
			return "%s (maintenance port)" % name
		NetworkSource.Kind.WIRELESS:
			return "%s (Wi-Fi)" % name
	return "%s (computer)" % name


## What a trace bar calls `tracer`: its label once its host is on the map, else "unknown tracer".
func tracer_name(tracer: Tracer) -> String:
	if tracer.device != null and session.map_devices().has(tracer.device):
		return tracer.label
	return DeckTraceBars.UNKNOWN


## The rows the Map shows now.
func map_rows() -> Array[NetworkRow]:
	return map_view.map_rows()


## Shows `text` in the deck's toast (open) or as a HUD message (lowered).
func show_notice(text: String) -> void:
	if visible:
		toast_label.text = text
		toast_label.visible = true
		_toast_left = TOAST_TIME
	elif player != null:
		var hud := player.get_node_or_null(^"Hud") as Hud
		if hud != null:
			hud.show_message(text)


## The visible button labelled `text` anywhere on the screen (tests), or null.
func find_button(text: String) -> Button:
	return UiQuery.find_button(root, text)


## The open device menu's button labelled `text` (tests), or null.
func menu_button(text: String) -> Button:
	return UiQuery.find_button(graph.menu, text) if graph.menu.visible else null


## Every visible button label on the open menu (tests).
func menu_texts() -> Array[String]:
	return UiQuery.texts(graph.menu) if graph.menu.visible else [] as Array[String]


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
	return UiQuery.texts(ice_view.column)


## Fills the computer overlay's trace slot (DeckTraceBars.computer_bars()).
func refresh_computer_traces() -> void:
	_computer_left = COMPUTER_TRACE_INTERVAL
	if computer_screen == null or not computer_screen.is_open() or computer_screen.computer == null:
		return
	# In place while the tracers stay the same: the overlay's bar (and its Back button) stay put.
	DeckTraceBars.show_bars(
		computer_screen.trace_bars(), DeckTraceBars.computer_bars(computer_screen, session, get_parent())
	)


func _process(delta: float) -> void:
	_computer_left -= delta
	if computer_screen != null and computer_screen.is_open() and _computer_left <= 0.0:
		refresh_computer_traces()
	if not visible:
		return
	if session == null or (not session.is_plugged() and tool != Tool.WIFI):
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
	map_view.invalidate()
	ice_view.invalidate()
	if visible:
		refresh()


func _on_remote_changed(computer: Computer) -> void:
	if computer != null and computer_screen != null:
		computer_screen.set_remote_area(content_anchors())
	elif computer == null and is_inside_tree():
		# Deferred: a desktop also closes while the level leaves the tree.
		map_view.invalidate()
		refresh.call_deferred()


func _on_computer_opened(_computer: Computer, _remote: bool) -> void:
	refresh_computer_traces()


func _on_crack_started() -> void:
	show_tool(Tool.ICEBREAKER)


func _open_exploits(device: Device) -> void:
	exploit_tool.select(device)
	show_tool(Tool.EXPLOITS)


func _open_firewall(device: Device) -> void:
	firewall_view.show_router(device)
	show_tool(Tool.FIREWALL)


func _address_text() -> String:
	var address := session.source.address
	return address if not address.is_empty() else "no address"


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
	frame = WindowFrame.new(&"Deck")
	frame.name = "Panel"
	var margin := (1.0 - PANEL_FRACTION) * 0.5
	frame.anchor_left = margin
	frame.anchor_top = margin
	frame.anchor_right = 1.0 - margin
	frame.anchor_bottom = 1.0 - margin
	root.add_child(frame)
	frame.title_label.text = "Deck"
	title_meta = frame.subtitle_label
	trace_box = frame.trace_slot
	close_button = frame.close_button
	close_button.tooltip_text = "Close (Esc): tools keep running while you stay plugged in"
	frame.close_requested.connect(close)
	content_area = frame.body
	_build_tools()
	map_view = DeckMapView.new()
	graph = map_view.graph
	unplugged_label = map_view.unplugged_label
	map_view.menu.exploits_requested.connect(_open_exploits)
	map_view.menu.firewall_requested.connect(_open_firewall)
	map_view.menu.crack_started.connect(_on_crack_started)
	map_view.menu.notice.connect(show_notice)
	map_view.menu.map_changed.connect(map_view.invalidate)
	content_area.add_child(map_view)
	ice_view = DeckIceView.new()
	ice_view.map_requested.connect(show_tool.bind(Tool.MAP))
	ice_view.refresh_requested.connect(refresh)
	content_area.add_child(ice_view)
	exploits_view = ExploitsView.new()
	exploits_view.visible = false
	content_area.add_child(exploits_view)
	firewall_view = FirewallView.new()
	firewall_view.visible = false
	content_area.add_child(firewall_view)
	wifi_view = WifiPanel.new()
	wifi_view.map_requested.connect(show_tool.bind(Tool.MAP))
	content_area.add_child(wifi_view)
	_build_toast()


func _build_tools() -> void:
	var column := frame.sidebar_column
	map_button = _tool_button("Map", Tool.MAP)
	ice_button = _tool_button("Icebreaker", Tool.ICEBREAKER)
	exploits_button = _tool_button("Exploits", Tool.EXPLOITS)
	firewall_button = _tool_button("Firewall", Tool.FIREWALL)
	var logs := _tool_button("Logs  (M16)", -1)
	logs.disabled = true
	logs.tooltip_text = "Reading and erasing device logs comes later (M16)."
	var text_width := float(WindowFrame.metric(&"sidebar_width") - 2 * WindowFrame.metric(&"inset"))
	tether_label = DeckStyle.paragraph(TETHER_NOTE, DeckStyle.DIM_COLOR, 11, text_width)
	tether_label.custom_minimum_size.y = 40.0
	# Text at the frame's inset, like the tools' names above it.
	var note := MarginContainer.new()
	note.name = "Tether"
	note.add_theme_constant_override(&"margin_left", WindowFrame.metric(&"space_s"))
	note.add_child(tether_label)
	column.add_child(note)


func _tool_button(text: String, which: int) -> Button:
	var button := Button.new()
	button.name = text.get_slice(" ", 0)
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.theme_type_variation = &"DeckToolButton"
	if which >= 0:
		button.pressed.connect(show_tool.bind(which))
	frame.sidebar_column.add_child(button)
	return button


func _build_toast() -> void:
	toast_label = DeckStyle.mono("", DeckStyle.TEXT_COLOR, 13)
	toast_label.name = "Toast"
	toast_label.visible = false
	toast_label.theme_type_variation = &"DeckToast"
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.anchor_top = 1.0
	toast_label.anchor_bottom = 1.0
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_label.offset_bottom = -40.0
	toast_label.z_index = 3
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_area.add_child(toast_label)
