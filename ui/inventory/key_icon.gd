class_name KeyIcon
extends Control
## A keychain entry's icon in line strokes (the approved mockups' glyphs, ADR 0130 and 0142): a brass
## key (a ring and a blade with two teeth) for a key, a blue card (a rounded card with a stripe and a
## chip line) for a keycard. Drawn on a 24-unit square scaled to the control.

## Keychain.KEY or Keychain.CARD (anything else: a key).
var kind: StringName = Keychain.KEY


func _init(p_kind: StringName = Keychain.KEY) -> void:
	kind = p_kind
	custom_minimum_size = Vector2(20, 20)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The colour it is drawn in.
func colour() -> Color:
	return TabStyle.CARD if kind == Keychain.CARD else TabStyle.AMBER


func _draw() -> void:
	var unit := minf(size.x, size.y) / 24.0
	var width := maxf(1.5 * unit, 1.0)
	var tint := colour()
	if kind == Keychain.CARD:
		_draw_card(unit, width, tint)
		return
	draw_arc(Vector2(7, 12) * unit, 4.0 * unit, 0.0, TAU, 20, tint, width, true)
	draw_line(Vector2(11, 12) * unit, Vector2(21, 12) * unit, tint, width, true)
	draw_line(Vector2(17, 12) * unit, Vector2(17, 15) * unit, tint, width, true)
	draw_line(Vector2(20, 12) * unit, Vector2(20, 14) * unit, tint, width, true)


func _draw_card(unit: float, width: float, tint: Color) -> void:
	var points := PackedVector2Array([Vector2(3, 6), Vector2(21, 6), Vector2(21, 18), Vector2(3, 18), Vector2(3, 6)])
	for i in points.size():
		points[i] *= unit
	draw_polyline(points, tint, width, true)
	draw_line(Vector2(3, 10) * unit, Vector2(21, 10) * unit, tint, width, true)
	draw_line(Vector2(6, 15) * unit, Vector2(11, 15) * unit, tint, width, true)
