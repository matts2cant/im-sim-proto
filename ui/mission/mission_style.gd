class_name MissionStyle
extends RefCounted
## Look of the mission screens (briefing, summary, toast; ADR 0087): the game menu's teal-on-dark
## panel and buttons (mission_theme.tres: its Button styles and the MissionPanel variation).

const PANEL_BG := Color(0.04, 0.08, 0.08, 0.97)
const BORDER := Color(0.3, 0.7, 0.68, 0.9)
const TITLE := Color(0.55, 0.92, 0.88, 1)
const TEXT := Color(0.85, 0.92, 0.9, 1)
const HINT := Color(0.5, 0.64, 0.64, 1)
const GOOD := Color(1, 0.82, 0.4, 1)
const MISSED := Color(0.4, 0.5, 0.5, 1)
const THEME: Theme = preload("res://ui/mission/mission_theme.tres")


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
	panel.theme = THEME
	panel.theme_type_variation = &"MissionPanel"
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	return box
