class_name MissionToast
extends CanvasLayer
## A short mission message at the top of the screen (ADR 0087): "Objective complete: ...", the
## extraction hint. Stays `show_time` seconds, its last third fading. Game time: it waits while the
## game is paused.

@export var show_time: float = 3.5

var label: Label

var _left: float = 0.0


func _ready() -> void:
	layer = 12
	label = MissionStyle.label("", 22, MissionStyle.GOOD)
	label.name = "Text"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -400.0
	label.offset_right = 400.0
	label.offset_top = 72.0
	label.offset_bottom = 104.0
	label.label_settings.outline_size = 4
	label.label_settings.outline_color = Color(0, 0, 0, 0.85)
	add_child(label)


func show_text(text: String) -> void:
	label.text = text
	label.modulate.a = 1.0
	_left = show_time


func text() -> String:
	return label.text if _left > 0.0 else ""


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	label.modulate.a = minf(_left / (show_time / 3.0), 1.0)
	if _left == 0.0:
		label.text = ""
