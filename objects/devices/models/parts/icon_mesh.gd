class_name IconMesh
extends RefCounted
## Turns a kind's line icon (SecurityKind.icon: the same strokes DeviceIcon draws on screen, on a
## 24-unit grid with y down) into a flat mesh of thin quads in the XY plane facing +Z, `side` metres
## square and centred on the origin, so the 3D models and the Map share one source (ADR 0130).
## Strokes: "x,y x,y ..." polyline, "rect x y w h", "circle cx cy r", "arc cx cy r from to"
## (degrees, 0 = +x, 90 = down), "dash x,y x,y" (2-unit dashes).

const GRID: float = 24.0
## The stroke width in grid units (the mockup's 2-unit pen).
const STROKE: float = 2.0
const CIRCLE_SEGMENTS: int = 24
const ARC_SEGMENTS: int = 12


## The segments of `strokes` as pairs of points in metres (a square `side` wide centred on the
## origin, y up).
static func segments(strokes: PackedStringArray, side: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for stroke in strokes:
		var parts := stroke.strip_edges().split(" ", false)
		if parts.is_empty():
			continue
		var points := _stroke_points(parts)
		var dashed := parts[0] == "dash"
		for i in range(0, points.size() - 1, 2 if dashed else 1):
			result.append(_to_metres(points[i], side))
			result.append(_to_metres(points[i + 1], side))
	return result


## The icon as one mesh (no material: the caller sets the kind's).
static func build(strokes: PackedStringArray, side: float) -> ArrayMesh:
	var half_width := side * STROKE / GRID * 0.5
	var lines := segments(strokes, side)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(0, lines.size() - 1, 2):
		var a := lines[i]
		var b := lines[i + 1]
		var along := (b - a).normalized() if a.distance_to(b) > 1e-6 else Vector2.RIGHT
		var across := Vector2(-along.y, along.x)
		var start := vertices.size()
		# Each end extends half a stroke so joints and caps close; clockwise from +Z (front faces).
		for corner: Vector2 in [
			a - along * half_width + across * half_width,
			b + along * half_width + across * half_width,
			b + along * half_width - across * half_width,
			a - along * half_width - across * half_width,
		]:
			vertices.append(Vector3(corner.x, corner.y, 0.0))
		indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.BACK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# The stroke's points on the grid, as a polyline (dashes: pairs of points).
static func _stroke_points(parts: PackedStringArray) -> PackedVector2Array:
	var points := PackedVector2Array()
	match parts[0]:
		"rect":
			if parts.size() >= 5:
				var x := parts[1].to_float()
				var y := parts[2].to_float()
				var w := parts[3].to_float()
				var h := parts[4].to_float()
				points = PackedVector2Array(
					[Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h), Vector2(x, y)]
				)
		"circle":
			if parts.size() >= 4:
				points = _arc(_num_point(parts, 1), parts[3].to_float(), 0.0, 360.0, CIRCLE_SEGMENTS)
		"arc":
			if parts.size() >= 6:
				var from := parts[4].to_float()
				var to := parts[5].to_float()
				points = _arc(_num_point(parts, 1), parts[3].to_float(), from, to, ARC_SEGMENTS)
		"dash":
			if parts.size() >= 3:
				points = _dashes(_point(parts[1]), _point(parts[2]))
		_:
			for part in parts:
				points.append(_point(part))
	return points


static func _arc(centre: Vector2, radius: float, from: float, to: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in steps + 1:
		var angle := deg_to_rad(lerpf(from, to, float(k) / float(steps)))
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


# 2-unit dashes with 2-unit gaps from `a` to `b`, as pairs of points.
static func _dashes(a: Vector2, b: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var length := a.distance_to(b)
	var t := 0.0
	while t < length:
		points.append(a.lerp(b, t / length))
		points.append(a.lerp(b, minf(t + 2.0, length) / length))
		t += 4.0
	return points


static func _to_metres(point: Vector2, side: float) -> Vector2:
	return Vector2(point.x / GRID - 0.5, 0.5 - point.y / GRID) * side


static func _num_point(parts: PackedStringArray, index: int) -> Vector2:
	return Vector2(parts[index].to_float(), parts[index + 1].to_float())


static func _point(text: String) -> Vector2:
	var xy := text.split(",")
	return Vector2(xy[0].to_float(), xy[1].to_float()) if xy.size() >= 2 else Vector2.ZERO
