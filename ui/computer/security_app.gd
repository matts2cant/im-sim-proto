class_name SecurityApp
extends HBoxContainer
## Halcyon OS's Security app (ADR 0114; replaces the terminal's Camera tab of ADR 0083). Over
## Computer.devices() (only the devices the computer controls):
## - a list grouped by kind (ComputerConfig.groups, in order; each device's kind and icon come from
##   its tags through ComputerConfig.kinds), each row with its short status in the status colour;
## - the selected device's detail pane: its name, kind and status, the live view when it has one
##   (DeviceStatus.has_view(): a FEED_SIZE SubViewport whose camera follows the device's view node,
##   rendered only while shown; "No signal" when offline or blind), its status words and address,
##   and one button per command it accepts (labels and danger style from the config's table).
## Offline devices stay listed, greyed, without actions. A computer that controls none says so and
## points to the deck. refresh() rebuilds what changed; the screen calls it a few times a second.

const LIST_WIDTH: float = 330.0
const NO_SIGNAL := "No signal"
const NONE_TITLE := "This computer controls no security devices."
const NONE_TEXT := (
	"The Security app lists only the devices that trust this machine and that it can reach. "
	+ "Explore the network with the deck to find out what controls them."
)
const NOTE := (
	"Commands go over the network: the device obeys this computer because it trusts it, "
	+ "also in a remote session from the deck."
)
## Render size of the live view (shown scaled to FEED_SHOWN).
const FEED_SIZE: Vector2i = Vector2i(480, 270)
const FEED_SHOWN: Vector2 = Vector2(448, 252)
const FEED_FOV: float = 70.0
const FEED_NEAR: float = 0.05
const FEED_FAR: float = 80.0

var computer: Computer
## Who operates the desktop (logged as the commands' operator).
var viewer: Node
## Computer.devices() at the last refresh.
var rows: Array[Computer.DeviceRow] = []
## The device shown in the detail pane (null: none).
var selected: Device
## Whether the app is on screen (the feed renders only then).
var shown: bool = false

var none_box: VBoxContainer
var detail_title: Label
var detail_meta: Label
var detail_status: Label
var detail_address: Label
var result_label: Label
var feed_frame: PanelContainer
var feed_viewport: SubViewport
var feed_camera: Camera3D
var feed_rect: TextureRect
var no_signal_label: Label
var live_label: Label
var view_label: Label

var _list: VBoxContainer
var _list_column: MarginContainer
var _detail_column: MarginContainer
var _none_column: MarginContainer
var _actions: HFlowContainer
var _signature: String = ""


func _ready() -> void:
	_build()


func bind(p_computer: Computer, p_viewer: Node) -> void:
	computer = p_computer
	viewer = p_viewer
	selected = null
	result_label.text = ""
	_signature = ""
	refresh(true)


## Reads the devices again and rebuilds what changed (or everything with `force`).
func refresh(force: bool = false) -> void:
	rows = computer.devices() if computer != null and is_instance_valid(computer) else [] as Array[Computer.DeviceRow]
	var signature := _signature_of(rows)
	if signature == _signature and not force:
		return
	_signature = signature
	if _row_of(selected) == null:
		selected = _ordered()[0].device if not rows.is_empty() else null
	_none_column.visible = rows.is_empty()
	_list_column.visible = not rows.is_empty()
	_detail_column.visible = not rows.is_empty()
	_rebuild_list()
	_rebuild_detail()
	update_feed()


## Shows device `device_name` in the detail pane; false when it is not listed.
func select(device_name: String) -> bool:
	for row in rows:
		if row.name == device_name:
			selected = row.device
			_rebuild_list()
			_rebuild_detail()
			update_feed()
			return true
	return false


## The listed groups, in order (only those with a device).
func group_names() -> Array[String]:
	var names: Array[String] = []
	for row in _ordered():
		if not names.has(row.kind.group):
			names.append(row.kind.group)
	return names


## The devices listed under `group` ("": all), in list order.
func device_names(group: String = "") -> Array[String]:
	var names: Array[String] = []
	for row in _ordered():
		if group.is_empty() or row.kind.group == group:
			names.append(row.name)
	return names


## The list row of `device_name` (its button), or null.
func entry(device_name: String) -> Button:
	for child in _list.get_children():
		var button := child as Button
		if (
			button != null
			and not button.is_queued_for_deletion()
			and button.get_meta(&"device_name", "") == device_name
		):
			return button
	return null


## The icon strokes of `device_name`'s list row (its kind's), or empty.
func icon_of(device_name: String) -> PackedStringArray:
	var button := entry(device_name)
	var icon := button.get_node_or_null(^"Row/Icon") as DeviceIcon if button != null else null
	return icon.strokes if icon != null else PackedStringArray()


## The short status shown on `device_name`'s row ("" when not listed).
func row_status(device_name: String) -> String:
	var button := entry(device_name)
	var label := button.get_node_or_null(^"Row/Status") as Label if button != null else null
	return label.text if label != null else ""


## The full status words of `device_name` at the last refresh ("" when not listed).
func status_of(device_name: String) -> String:
	for row in rows:
		if row.name == device_name:
			return HalcyonStyle.status_text(row.status)
	return ""


## The detail pane's action button `label`, or null.
func action_button(label: String) -> Button:
	for child in _actions.get_children():
		var button := child as Button
		if button != null and not button.is_queued_for_deletion() and button.text == label:
			return button
	return null


## The detail pane's action labels, in order.
func action_labels() -> Array[String]:
	var labels: Array[String] = []
	for child in _actions.get_children():
		var button := child as Button
		if button != null and not button.is_queued_for_deletion():
			labels.append(button.text)
	return labels


## Sends `command` to `target` and says what happened.
func press(command: StringName, target: Device) -> void:
	if computer == null:
		return
	var label := computer.config.label_for(command)
	var target_name := Computer.display_name(target)
	if computer.send(command, target, viewer):
		result_label.text = "%s: %s sent." % [target_name, label]
	else:
		result_label.text = "%s: no connection." % target_name
	refresh(true)


## True while the live view renders.
func feed_live() -> bool:
	return feed_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS and feed_rect.visible


## Renders the live view only while the app shows a device that sees, else "No signal" (every frame
## while shown; tests call it after a refresh).
func update_feed() -> void:
	var row := _row_of(selected) if shown and is_visible_in_tree() else null
	var view: Node3D = DeviceStatus.view_of(row.device.entity) if row != null and row.online else null
	var live := view != null and is_instance_valid(view) and view.is_inside_tree()
	if live:
		feed_camera.global_transform = view.global_transform
	feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	feed_rect.visible = live
	no_signal_label.visible = not live
	live_label.visible = live


# Rows in list order: by group (the config's order), then nearest first.
func _ordered() -> Array[Computer.DeviceRow]:
	var ordered: Array[Computer.DeviceRow] = []
	var groups := computer.config.groups if computer != null else PackedStringArray()
	for group in groups:
		for row in rows:
			if row.kind.group == group:
				ordered.append(row)
	for row in rows:
		if not ordered.has(row):
			ordered.append(row)
	return ordered


func _row_of(device: Device) -> Computer.DeviceRow:
	if not is_instance_valid(device):
		return null
	for row in rows:
		if row.device == device:
			return row
	return null


func _signature_of(p_rows: Array[Computer.DeviceRow]) -> String:
	var parts: PackedStringArray = []
	for row in p_rows:
		parts.append(
			(
				"%d|%s|%s|%s|%s"
				% [row.device.get_instance_id(), row.name, row.online, ",".join(row.status), ",".join(row.commands)]
			)
		)
	return ";".join(parts)


func _rebuild_list() -> void:
	for child in _list.get_children():
		HalcyonStyle.discard(child)
	var group := ""
	for row in _ordered():
		if row.kind.group != group:
			group = row.kind.group
			var caption := HalcyonStyle.caption(group)
			caption.name = "Group"
			_list.add_child(caption)
		_list.add_child(_list_row(row))


func _list_row(row: Computer.DeviceRow) -> Button:
	var button := HalcyonStyle.list_entry()
	button.set_meta(&"device_name", row.name)
	button.custom_minimum_size = Vector2(0, 38)
	button.set_pressed_no_signal(row.device == selected)
	button.pressed.connect(select.bind(row.name))
	var line := HBoxContainer.new()
	line.name = "Row"
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8
	line.offset_right = -8
	line.add_theme_constant_override(&"separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)
	var colour := HalcyonStyle.status_color(row.status, row.disabled)
	var icon := DeviceIcon.make(row.kind.icon, HalcyonStyle.TEXT if row.online else HalcyonStyle.OFFLINE)
	icon.name = "Icon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var name_label := HalcyonStyle.label(row.name, 13, HalcyonStyle.TEXT if row.online else HalcyonStyle.OFFLINE)
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.clip_text = true
	line.add_child(name_label)
	var status := HalcyonStyle.label(HalcyonStyle.short_status(row.status), 11, colour, true)
	status.name = "Status"
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.size_flags_vertical = Control.SIZE_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.custom_minimum_size = Vector2(120, 0)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(status)
	return button


func _rebuild_detail() -> void:
	for child in _actions.get_children():
		HalcyonStyle.discard(child)
	var row := _row_of(selected)
	if row == null:
		detail_title.text = ""
		detail_meta.text = ""
		detail_status.text = ""
		detail_address.text = ""
		feed_frame.visible = false
		return
	var colour := HalcyonStyle.status_color(row.status, row.disabled)
	detail_title.text = row.name
	detail_meta.text = "%s · %s" % [row.kind.name, HalcyonStyle.short_status(row.status)]
	detail_meta.label_settings.font_color = colour
	detail_status.text = "Status   " + HalcyonStyle.status_text(row.status)
	detail_status.label_settings.font_color = colour
	var address := _address_of(row.device)
	detail_address.text = "Address  " + address
	detail_address.visible = not address.is_empty()
	feed_frame.visible = row.has_view
	view_label.text = row.name.to_upper()
	for command in row.commands:
		var danger := computer.config.danger_commands.has(command)
		var button := HalcyonStyle.button(computer.config.label_for(command), false, danger)
		button.pressed.connect(press.bind(command, row.device))
		_actions.add_child(button)
	if not row.online:
		_actions.add_child(HalcyonStyle.label("No connection.", 13, HalcyonStyle.DIM))


static func _address_of(device: Device) -> String:
	if not is_instance_valid(device.entity):
		return ""
	for child in device.entity.get_children():
		if child.has_method(Computer.ADDRESS_METHOD):
			var value := str(child.call(Computer.ADDRESS_METHOD))
			if not value.is_empty():
				return value
	return ""


func _build() -> void:
	add_theme_constant_override(&"separation", 0)
	_list_column = MarginContainer.new()
	_list_column.name = "List"
	_list_column.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	DocumentApp._margins(_list_column, 14)
	add_child(_list_column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)
	_detail_column = MarginContainer.new()
	_detail_column.name = "Detail"
	_detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DocumentApp._margins(_detail_column, 18)
	add_child(_detail_column)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_column.add_child(detail_scroll)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override(&"separation", 8)
	detail_scroll.add_child(detail)
	detail_title = HalcyonStyle.label("", 18, HalcyonStyle.TEAL)
	detail.add_child(detail_title)
	detail_meta = HalcyonStyle.label("", 12, HalcyonStyle.DIM, true)
	detail.add_child(detail_meta)
	_build_feed(detail)
	detail_status = HalcyonStyle.label("", 13, HalcyonStyle.TEXT, true)
	detail_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(detail_status)
	detail_address = HalcyonStyle.label("", 13, HalcyonStyle.TEXT, true)
	detail.add_child(detail_address)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override(&"h_separation", 8)
	_actions.add_theme_constant_override(&"v_separation", 8)
	detail.add_child(_actions)
	result_label = HalcyonStyle.label("", 13, HalcyonStyle.DIM, true)
	detail.add_child(result_label)
	detail.add_child(HalcyonStyle.paragraph(NOTE, 12, HalcyonStyle.DIM))
	none_box = VBoxContainer.new()
	none_box.name = "None"
	none_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	none_box.add_theme_constant_override(&"separation", 10)
	_none_column = MarginContainer.new()
	_none_column.name = "NoDevices"
	DocumentApp._margins(_none_column, 18)
	_none_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_none_column.visible = false
	_none_column.add_child(none_box)
	add_child(_none_column)
	none_box.add_child(HalcyonStyle.label("Security", 18, HalcyonStyle.TEAL))
	none_box.add_child(HalcyonStyle.paragraph(NONE_TITLE, 14, HalcyonStyle.TEXT))
	none_box.add_child(HalcyonStyle.paragraph(NONE_TEXT, 13, HalcyonStyle.DIM))


# The live view's SubViewport shares the level's world (it has no world of its own); its camera is
# moved onto the selected device's view node every frame while live.
func _build_feed(detail: VBoxContainer) -> void:
	feed_frame = PanelContainer.new()
	feed_frame.name = "View"
	feed_frame.add_theme_stylebox_override(&"panel", HalcyonStyle.box(Color(0.0, 0.02, 0.02), HalcyonStyle.LINE, 1, 0))
	feed_frame.custom_minimum_size = FEED_SHOWN
	feed_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	detail.add_child(feed_frame)
	feed_rect = TextureRect.new()
	feed_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed_rect.stretch_mode = TextureRect.STRETCH_SCALE
	feed_rect.custom_minimum_size = FEED_SHOWN
	feed_frame.add_child(feed_rect)
	no_signal_label = HalcyonStyle.label(NO_SIGNAL, 22, HalcyonStyle.OFFLINE)
	no_signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_signal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feed_frame.add_child(no_signal_label)
	# The view's caption row, top of the frame: the device's name left, LIVE right.
	var caption_margin := MarginContainer.new()
	caption_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	caption_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top"]:
		caption_margin.add_theme_constant_override("margin_" + side, 8)
	feed_frame.add_child(caption_margin)
	var caption := HBoxContainer.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_margin.add_child(caption)
	view_label = HalcyonStyle.label("", 11, HalcyonStyle.TEAL, true)
	view_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_child(view_label)
	live_label = HalcyonStyle.label("● LIVE", 11, HalcyonStyle.BAD, true)
	caption.add_child(live_label)
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
