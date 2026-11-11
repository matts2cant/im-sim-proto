class_name WindowFrame
extends Control
## The window frame the deck (DeckScreen) and Halcyon OS (ComputerScreen) share: a rounded outer
## panel with a header row (title, subtitle, a trace bar slot, an actions slot, ✕), an optional left
## sidebar and a body. Sizes and colours come from window_theme.tres: the WindowFrame type holds the
## sizes both looks share (spacing scale, corner radius, border width, header height, sidebar width,
## close button size, inset); `<look>Frame` holds a look's colours. The frame sets that theme on
## itself, so every widget inside resolves its type variation (DeckButton, HalcyonField, ...).
## The frame paints its regions (body, header, sidebar) itself, each with the frame's radius on its
## outer corners, and draws its border last, on top of everything inside: the header row, the
## sidebar and the body have no background of their own and sit inside the border, so nothing ever
## covers the frame's rounded corners or its border.
## Alignment: the header title and the sidebar items' text start `inset` from the frame's left
## edge; the ✕ ends `inset` from its right edge, its top level with the title's; the body's
## WindowBody margins start its content `inset` inside the body region.

## The ✕ was pressed (the owner closes).
signal close_requested

const THEME: Theme = preload("res://ui/window/window_theme.tres")
const TYPE: StringName = &"WindowFrame"

## The look whose colours paint the frame: &"Deck" or &"Halcyon" (`<look>Frame` in the theme).
var look: StringName = &"Deck"
var header: MarginContainer
var title_label: Label
var subtitle_label: Label
## Labels after the title (subtitle_label first); owners may add more.
var subtitle_box: HBoxContainer
## Trace bars (DeckTraceBars) go here.
var trace_slot: HBoxContainer
## Buttons before the ✕ (a remote desktop's "Back to the map").
var actions: HBoxContainer
var close_button: Button
var sidebar: MarginContainer
## The sidebar's column (tools, dock entries).
var sidebar_column: VBoxContainer
## The area right of the sidebar and under the header.
var body: Control

var _header_color: StringName = &"header_color"
var _border: Control


func _init(p_look: StringName = &"Deck") -> void:
	look = p_look
	theme = THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## A size from the theme's WindowFrame type ("inset", "radius", "header_height", ...).
static func metric(name: StringName) -> int:
	return THEME.get_constant(name, TYPE)


## A colour of `p_look`'s frame ("body_color", "line_color", ...).
static func look_color(p_look: StringName, name: StringName) -> Color:
	return THEME.get_color(name, StringName(String(p_look) + "Frame"))


## Shows or hides the left sidebar (the body takes its place when hidden).
func set_sidebar_visible(shown: bool) -> void:
	sidebar.visible = shown
	(sidebar.get_parent().get_node(^"SidebarLine") as Control).visible = shown
	queue_redraw()


func has_sidebar() -> bool:
	return sidebar.visible


## Paints the header with colour `name` of the look ("header_color", "header_remote_color").
func set_header_color(name: StringName) -> void:
	_header_color = name
	queue_redraw()


## The header region (frame coordinates), its bottom line included.
func header_rect() -> Rect2:
	return Rect2(0.0, 0.0, size.x, metric(&"header_height"))


## The sidebar region (frame coordinates), its right line included; empty when hidden.
func sidebar_rect() -> Rect2:
	if not sidebar.visible:
		return Rect2()
	var top := float(metric(&"header_height"))
	return Rect2(0.0, top, metric(&"sidebar_width"), size.y - top)


## The body region (frame coordinates).
func body_rect() -> Rect2:
	var left := sidebar_rect().size.x
	var top := float(metric(&"header_height"))
	return Rect2(left, top, size.x - left, size.y - top)


## The frame's styleboxes: "body", "header", "sidebar" (filled, the frame's radius on their outer
## corners, their inner edge lined) and "border" (outline only).
func style(which: StringName) -> StyleBoxFlat:
	var radius := metric(&"radius")
	var line := metric(&"border")
	var box := StyleBoxFlat.new()
	box.anti_aliasing = true
	match which:
		&"body":
			box.bg_color = look_color(look, &"body_color")
			box.set_corner_radius_all(radius)
		&"header":
			box.bg_color = look_color(look, _header_color)
			box.corner_radius_top_left = radius
			box.corner_radius_top_right = radius
			box.border_width_bottom = line
			box.border_color = look_color(look, &"line_color")
		&"sidebar":
			box.bg_color = look_color(look, &"sidebar_color")
			box.corner_radius_bottom_left = radius
			box.border_width_right = line
			box.border_color = look_color(look, &"line_color")
		&"border":
			box.draw_center = false
			box.set_border_width_all(line)
			box.set_corner_radius_all(radius)
			box.border_color = look_color(look, &"border_color")
	return box


func _draw() -> void:
	draw_style_box(style(&"body"), Rect2(Vector2.ZERO, size))
	draw_style_box(style(&"header"), header_rect())
	if sidebar.visible:
		draw_style_box(style(&"sidebar"), sidebar_rect())


func _build() -> void:
	var line := metric(&"border")
	var inset := metric(&"inset")
	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = line
	column.offset_top = line
	column.offset_right = -line
	column.offset_bottom = -line
	column.add_theme_constant_override(&"separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_build_header(column, line, inset)
	var header_line := Control.new()
	header_line.name = "HeaderLine"
	header_line.custom_minimum_size.y = line
	header_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header_line)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	sidebar = MarginContainer.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size.x = metric(&"sidebar_width") - 2 * line
	# Sidebar items (DeckToolButton, HalcyonListEntry) pad their text by space_s: the text starts at
	# `inset` from the frame's edge, under the title.
	sidebar.add_theme_constant_override(&"margin_left", inset - line - metric(&"space_s"))
	sidebar.add_theme_constant_override(&"margin_right", inset - line - metric(&"space_s"))
	sidebar.add_theme_constant_override(&"margin_top", metric(&"space_s"))
	sidebar.add_theme_constant_override(&"margin_bottom", metric(&"space_s"))
	row.add_child(sidebar)
	sidebar_column = VBoxContainer.new()
	sidebar_column.name = "Items"
	sidebar_column.add_theme_constant_override(&"separation", metric(&"space_xs"))
	sidebar.add_child(sidebar_column)
	var sidebar_line := Control.new()
	sidebar_line.name = "SidebarLine"
	sidebar_line.custom_minimum_size.x = line
	sidebar_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sidebar_line)
	body = Control.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(body)
	_border = FrameBorder.new()
	_border.name = "Border"
	add_child(_border)


func _build_header(column: VBoxContainer, line: int, inset: int) -> void:
	header = MarginContainer.new()
	header.name = "Header"
	header.custom_minimum_size.y = metric(&"header_height") - 2 * line
	header.add_theme_constant_override(&"margin_left", inset - line)
	header.add_theme_constant_override(&"margin_right", inset - line)
	header.add_theme_constant_override(&"margin_top", 0)
	header.add_theme_constant_override(&"margin_bottom", 0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override(&"separation", metric(&"space_m"))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(row)
	var close_size := metric(&"close_size")
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_color_override(&"font_color", look_color(look, &"title_color"))
	title_label.add_theme_font_size_override(&"font_size", THEME.get_font_size(&"title", TYPE))
	# As tall as the ✕ and centred: the title's top and the ✕'s top share one inset.
	title_label.custom_minimum_size.y = close_size
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title_label)
	subtitle_box = HBoxContainer.new()
	subtitle_box.name = "Subtitles"
	subtitle_box.add_theme_constant_override(&"separation", metric(&"space_m"))
	subtitle_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	subtitle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(subtitle_box)
	subtitle_label = subtitle("")
	subtitle_label.name = "Subtitle"
	subtitle_box.add_child(subtitle_label)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grow)
	trace_slot = HBoxContainer.new()
	trace_slot.name = "Traces"
	trace_slot.add_theme_constant_override(&"separation", metric(&"space_l"))
	trace_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(trace_slot)
	actions = HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override(&"separation", metric(&"space_s"))
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "✕"
	close_button.theme_type_variation = StringName(String(look) + "CloseButton")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(close_size, close_size)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close_requested.emit)
	row.add_child(close_button)


## A header label after the title, in the look's subtitle colour and the monospace font.
func subtitle(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", look_color(look, &"subtitle_color"))
	label.add_theme_font_size_override(&"font_size", THEME.get_font_size(&"subtitle", TYPE))
	label.add_theme_font_override(&"font", TabStyle.mono_font())
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


## The frame's border, drawn after (over) everything inside the frame.
class FrameBorder:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var frame := get_parent() as WindowFrame
		if frame != null:
			draw_style_box(frame.style(&"border"), Rect2(Vector2.ZERO, size))
