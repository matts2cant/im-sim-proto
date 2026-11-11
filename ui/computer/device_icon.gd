class_name DeviceIcon
extends Control
## A small line icon drawn from data (ADR 0114): `strokes` on a 24 x 24 grid, scaled to the control,
## in `colour`. Icons belong to device kinds and apps (ComputerConfig), never to one device. One
## stroke per string:
## - "x,y x,y ...": a polyline;
## - "rect x y w h", "circle cx cy r";
## - "arc cx cy r from to": an arc, angles in degrees (0 = +x, 90 = down);
## - "dash x,y x,y": a dashed line.

const GRID: float = 24.0
const WIDTH: float = 1.6

@export var strokes: PackedStringArray = []:
	set(value):
		strokes = value
		queue_redraw()
@export var colour: Color = HalcyonStyle.TEXT:
	set(value):
		colour = value
		queue_redraw()


static func make(p_strokes: PackedStringArray, p_colour: Color, side: float = 22.0) -> DeviceIcon:
	var icon := DeviceIcon.new()
	icon.strokes = p_strokes
	icon.colour = p_colour
	icon.custom_minimum_size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var scale_by := minf(size.x, size.y) / GRID
	var width := maxf(1.0, WIDTH * scale_by)
	for stroke in strokes:
		_draw_stroke(stroke.strip_edges(), scale_by, width)


func _draw_stroke(stroke: String, scale_by: float, width: float) -> void:
	var parts := stroke.split(" ", false)
	if parts.is_empty():
		return
	match parts[0]:
		"rect":
			if parts.size() >= 5:
				var rect := Rect2(_num(parts, 1), _num(parts, 2), _num(parts, 3), _num(parts, 4))
				draw_rect(Rect2(rect.position * scale_by, rect.size * scale_by), colour, false, width, true)
		"circle":
			if parts.size() >= 4:
				var centre := Vector2(_num(parts, 1), _num(parts, 2)) * scale_by
				draw_arc(centre, _num(parts, 3) * scale_by, 0.0, TAU, 24, colour, width, true)
		"arc":
			if parts.size() >= 6:
				var centre := Vector2(_num(parts, 1), _num(parts, 2)) * scale_by
				var from := deg_to_rad(_num(parts, 4))
				var to := deg_to_rad(_num(parts, 5))
				draw_arc(centre, _num(parts, 3) * scale_by, from, to, 16, colour, width, true)
		"dash":
			if parts.size() >= 3:
				draw_dashed_line(
					_point(parts[1]) * scale_by, _point(parts[2]) * scale_by, colour, width, 2.0 * scale_by
				)
		_:
			var points := PackedVector2Array()
			for part in parts:
				points.append(_point(part) * scale_by)
			if points.size() >= 2:
				draw_polyline(points, colour, width, true)


static func _num(parts: PackedStringArray, index: int) -> float:
	return parts[index].to_float()


static func _point(text: String) -> Vector2:
	var xy := text.split(",")
	return Vector2(xy[0].to_float(), xy[1].to_float()) if xy.size() >= 2 else Vector2.ZERO
