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
	var side := minf(size.x, size.y)
	draw_strokes(self, strokes, Rect2(Vector2.ZERO, Vector2(side, side)), colour)


## Draws `p_strokes` on `canvas` scaled into the square `rect` (its smaller side), in `p_colour`
## (also for icons drawn on another control: inventory items).
static func draw_strokes(canvas: CanvasItem, p_strokes: PackedStringArray, rect: Rect2, p_colour: Color) -> void:
	var scale_by := minf(rect.size.x, rect.size.y) / GRID
	var width := maxf(1.0, WIDTH * scale_by)
	for stroke in p_strokes:
		_draw_stroke(canvas, stroke.strip_edges(), rect.position, scale_by, width, p_colour)


static func _draw_stroke(
	canvas: CanvasItem, stroke: String, at: Vector2, scale_by: float, width: float, p_colour: Color
) -> void:
	var parts := stroke.split(" ", false)
	if parts.is_empty():
		return
	match parts[0]:
		"rect":
			if parts.size() >= 5:
				var rect := Rect2(_num(parts, 1), _num(parts, 2), _num(parts, 3), _num(parts, 4))
				canvas.draw_rect(
					Rect2(at + rect.position * scale_by, rect.size * scale_by), p_colour, false, width, true
				)
		"circle":
			if parts.size() >= 4:
				var centre := at + Vector2(_num(parts, 1), _num(parts, 2)) * scale_by
				canvas.draw_arc(centre, _num(parts, 3) * scale_by, 0.0, TAU, 24, p_colour, width, true)
		"arc":
			if parts.size() >= 6:
				var centre := at + Vector2(_num(parts, 1), _num(parts, 2)) * scale_by
				var from := deg_to_rad(_num(parts, 4))
				var to := deg_to_rad(_num(parts, 5))
				canvas.draw_arc(centre, _num(parts, 3) * scale_by, from, to, 16, p_colour, width, true)
		"dash":
			if parts.size() >= 3:
				canvas.draw_dashed_line(
					at + _point(parts[1]) * scale_by, at + _point(parts[2]) * scale_by, p_colour, width, 2.0 * scale_by
				)
		_:
			var points := PackedVector2Array()
			for part in parts:
				points.append(at + _point(part) * scale_by)
			if points.size() >= 2:
				canvas.draw_polyline(points, p_colour, width, true)


static func _num(parts: PackedStringArray, index: int) -> float:
	return parts[index].to_float()


static func _point(text: String) -> Vector2:
	var xy := text.split(",")
	return Vector2(xy[0].to_float(), xy[1].to_float()) if xy.size() >= 2 else Vector2.ZERO
