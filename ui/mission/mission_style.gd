class_name MissionStyle
extends RefCounted
## Look of the mission screens (briefing, summary, toast; ADR 0087): the game menu's teal-on-dark
## panel and buttons, built in code.

const PANEL_BG := Color(0.04, 0.08, 0.08, 0.97)
const BORDER := Color(0.3, 0.7, 0.68, 0.9)
const TITLE := Color(0.55, 0.92, 0.88, 1)
const TEXT := Color(0.85, 0.92, 0.9, 1)
const HINT := Color(0.5, 0.64, 0.64, 1)
const GOOD := Color(1, 0.82, 0.4, 1)
const MISSED := Color(0.4, 0.5, 0.5, 1)


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 18.0
	return style


static func label(text: String, size: int, colour: Color) -> Label:
	var node := Label.new()
	node.text = text
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = colour
	node.label_settings = settings
	return node


## A full-screen dim layer with a centred panel; returns the panel's content box.
static func centred_panel(layer: CanvasLayer, min_width: float) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var centre := CenterContainer.new()
	centre.name = "Center"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(min_width, 0)
	panel.add_theme_stylebox_override(&"panel", panel_style())
	panel.theme = button_theme()
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	return box


static func button_theme() -> Theme:
	var theme := Theme.new()
	var states := {
		&"normal": Color(0.07, 0.14, 0.14, 1),
		&"hover": Color(0.1, 0.22, 0.21, 1),
		&"pressed": Color(0.16, 0.32, 0.31, 1),
	}
	for state: StringName in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state]
		box.border_color = Color(0.4, 0.8, 0.77, 1) if state != &"normal" else Color(0.2, 0.42, 0.41, 1)
		box.set_border_width_all(1)
		box.content_margin_left = 16.0
		box.content_margin_right = 16.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
		theme.set_stylebox(state, &"Button", box)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = TITLE
	focus.set_border_width_all(2)
	theme.set_stylebox(&"focus", &"Button", focus)
	theme.set_color(&"font_color", &"Button", Color(0.85, 0.95, 0.92, 1))
	theme.set_color(&"font_hover_color", &"Button", Color(1, 1, 1, 1))
	theme.set_color(&"font_focus_color", &"Button", Color(1, 1, 1, 1))
	theme.set_font_size(&"font_size", &"Button", 18)
	return theme
