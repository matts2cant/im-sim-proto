class_name LockpickFrontView
extends Control
## The lockpicking screen's front view (ADR 0107): a port of the prototype's drawFront() and
## drawGauge(). The door plate, the brass housing and plug (it turns with tension, sets, false sets
## and the open turn), the keyway, the tension wrench (it flexes with tension), the pick (its tip
## height is the lift, its bow the force), the pick-depth dots and, at assist 1+, the tension gauge
## at the right edge (bands at the picker's real thresholds, needle, % and zone word).

var screen: LockpickScreen

# The shake of the lock drawing (nudge), added to every transform of the lock.
var _jolt: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	var model := screen.model if screen != null else null
	if model == null:
		return
	var w := size.x
	var h := size.y
	var bg := LockpickStyle.radial(
		"front_bg", PackedColorArray([Color("222a32"), Color("0b0e11")]), PackedFloat32Array([0.0, 1.0])
	)
	var reach := maxf(w, h) * 0.75
	var focus := Vector2(w * 0.5, h * 0.5)
	draw_texture_rect(bg, Rect2(focus - Vector2(reach, reach), Vector2(reach, reach) * 2.0), false)
	var cy := h * 0.45
	var radius := minf(w, h) * 0.3
	var shake := model.nudge * 3.0
	_jolt = Vector2(randf() - 0.5, randf() - 0.5) * shake
	draw_set_transform(_jolt)
	_draw_lock(model, Vector2(w * 0.5, cy), radius)
	draw_set_transform(Vector2.ZERO)
	_draw_depth(model, Vector2(w * 0.5, cy), radius)
	if screen.shows_gauge():
		_draw_gauge(model, w, h, cy, radius)
	draw_style_box(LockpickStyle.rounded_box(Color(0, 0, 0, 0), LockpickStyle.LINE, 10), Rect2(Vector2.ZERO, size))


func _draw_lock(model: PinTumbler, center: Vector2, big: float) -> void:
	var small := big * 0.62
	# Door plate
	var plate := Rect2(center.x - big * 1.35, center.y - big * 1.55, big * 2.7, big * 3.2)
	draw_style_box(LockpickStyle.rounded_box(Color("1a2027"), Color("2c3640"), roundi(big * 0.12)), plate)
	# Housing
	var housing := LockpickStyle.radial(
		"housing",
		PackedColorArray([Color("e7c672"), Color("b58d3c"), Color("6e5424")]),
		PackedFloat32Array([0.0, 0.6, 1.0])
	)
	var ring := LockpickStyle.circle(center, big)
	var focus := center + Vector2(-0.3, -0.35) * big
	draw_colored_polygon(ring, Color.WHITE, LockpickStyle.radial_uvs(ring, focus, big * 1.3), housing)
	draw_arc(center, big, 0.0, TAU, 64, Color(0, 0, 0, 0.45), big * 0.03, true)
	draw_arc(center, big * 0.97, PI * 1.1, PI * 1.7, 24, Color(1.0, 0.94, 0.78, 0.25), 1.0, true)
	# Plug and keyway, turned by the plug angle
	var angle := deg_to_rad(model.plug_angle_deg())
	draw_set_transform(center + _jolt, angle)
	var plug_tex := LockpickStyle.radial(
		"plug", PackedColorArray([Color("d9b865"), Color("8f6f2e")]), PackedFloat32Array([0.0, 1.0])
	)
	var plug := LockpickStyle.circle(Vector2.ZERO, small)
	var plug_focus := Vector2(-0.3, -0.3) * small
	draw_colored_polygon(plug, Color.WHITE, LockpickStyle.radial_uvs(plug, plug_focus, small * 1.2), plug_tex)
	draw_arc(Vector2.ZERO, small, 0.0, TAU, 64, Color(0, 0, 0, 0.55), big * 0.025, true)
	var kw := small * 0.085
	var keyway := PackedVector2Array(
		[
			Vector2(-kw * 0.6, -small * 0.8),
			Vector2(kw * 0.6, -small * 0.8),
			Vector2(kw * 0.9, -small * 0.45),
			Vector2(kw * 0.2, -small * 0.3),
			Vector2(kw * 1.0, -small * 0.1),
			Vector2(kw * 0.4, small * 0.15),
			Vector2(kw * 1.1, small * 0.4),
			Vector2(kw * 1.4, small * 0.72),
			Vector2(-kw * 1.4, small * 0.72),
			Vector2(-kw * 1.1, small * 0.45),
			Vector2(-kw * 0.3, small * 0.25),
			Vector2(-kw * 1.0, 0.0),
			Vector2(-kw * 0.3, -small * 0.2),
			Vector2(-kw * 0.9, -small * 0.5),
		]
	)
	draw_colored_polygon(keyway, Color("07090b"))
	# Tension wrench: bottom of the keyway, turning with the plug and flexing with tension
	draw_set_transform(center + _jolt, angle + model.tension * 0.12)
	draw_rect(Rect2(-kw * 1.1, small * 0.6, kw * 2.2, small * 0.1), Color("c6d0d8"))
	var arm := PackedVector2Array(
		[Vector2(0, small * 0.66), Vector2(big * 1.55, small * 0.66), Vector2(big * 1.62, small * 0.66 + big * 0.55)]
	)
	_round_polyline(arm, Color("aab6c1"), big * 0.07)
	draw_line(Vector2(kw, small * 0.63), Vector2(big * 1.52, small * 0.63), Color(1, 1, 1, 0.35), 1.2, true)
	draw_set_transform(_jolt)
	_draw_pick(model, center, big, small, angle)


# Pick: shaft into the keyway; the tip height is the lift, the bow is the force.
func _draw_pick(model: PinTumbler, center: Vector2, big: float, small: float, angle: float) -> void:
	var tip_local := small * 0.5 - model.tip * small * 1.05
	var tip := center + Vector2(-sin(angle) * tip_local, cos(angle) * tip_local)
	var count := model.pins.size()
	var depth := (count - 1 - model.pick_shown) / maxf(1.0, count - 1)
	var handle := center + Vector2(-big * (1.1 + depth * 0.45), big * (1.05 + depth * 0.2))
	var bow := minf(0.5, model.force) * big * 0.9
	var control := (handle + tip) * 0.5 + Vector2(bow * 0.3, bow)
	var shaft_colour := Color("e0d3c7") if model.strain > 0.5 else Color("cfd8e0")
	_round_polyline(LockpickStyle.quadratic(handle, control, tip), shaft_colour, big * 0.03)
	draw_circle(tip, big * 0.022, Color("e8eef3"), true, -1.0, true)
	var grip := handle - (tip - handle) * 0.25
	_round_polyline(PackedVector2Array([handle, grip]), Color("5a3f33"), big * 0.11)


# Pick depth dots (how far the pick is in), under the plate.
func _draw_depth(model: PinTumbler, center: Vector2, big: float) -> void:
	var count := model.pins.size()
	var y := center.y + big * 1.75
	var gap := minf(22.0, big * 0.3)
	var x0 := center.x - gap * (count - 1) / 2.0
	var current := roundi(model.pick_shown)
	for i in count:
		var here := i == current
		draw_circle(Vector2(x0 + gap * i, y), 4.0 if here else 3.0, LockpickStyle.BRASS if here else Color("33404c"))
	LockpickStyle.text(self, Vector2(center.x, y + 18.0), "pick depth", 11, LockpickStyle.MUTED)


# Tension gauge: a vertical bar at the right edge, 0 % at the bottom. Its bands are the picker's
# real thresholds (drop zone, too low, sweet spot, too high).
func _draw_gauge(model: PinTumbler, w: float, h: float, cy: float, big: float) -> void:
	var params := model.params
	var bar_w := 14.0
	var bar_h := minf(h - 70.0, big * 2.6)
	var x := w - bar_w - 26.0
	var y0 := maxf(34.0, cy - bar_h / 2.0)
	var y1 := y0 + bar_h
	var bands: Array[Array] = [
		[0.0, params.drop, LockpickStyle.BAD],
		[params.drop, params.low, LockpickStyle.WARN],
		[params.low, params.high, LockpickStyle.OK],
		[params.high, 1.0, LockpickStyle.BAD],
	]
	var t := model.tension
	var frame := Rect2(x - 3.0, y0 - 3.0, bar_w + 6.0, bar_h + 6.0)
	draw_style_box(LockpickStyle.rounded_box(LockpickStyle.BG, Color("2c3640"), 5), frame)
	for band in bands:
		var a: float = band[0]
		var b: float = band[1]
		var colour: Color = band[2]
		var inside := t >= a and (t < b or b == 1.0)
		draw_rect(Rect2(x, y1 - b * bar_h, bar_w, (b - a) * bar_h), Color(colour, 0.22))
		# The filled part, up to the current tension, in the colour of each band it covers
		if t > a:
			var top := minf(t, b)
			draw_rect(Rect2(x, y1 - top * bar_h, bar_w, (top - a) * bar_h), Color(colour, 0.95 if inside else 0.55))
	# Sweet-spot edges, drawn across the bar
	for edge: float in [params.low, params.high]:
		var y := y1 - edge * bar_h
		draw_line(Vector2(x - 5.0, y), Vector2(x + bar_w + 5.0, y), LockpickStyle.OK, 1.5)
	# Needle at the current tension
	var ny := y1 - t * bar_h
	draw_colored_polygon(
		PackedVector2Array([Vector2(x - 4.0, ny), Vector2(x - 11.0, ny - 5.0), Vector2(x - 11.0, ny + 5.0)]),
		LockpickStyle.FG
	)
	draw_rect(Rect2(x - 2.0, ny - 1.0, bar_w + 4.0, 2.0), LockpickStyle.FG)
	# Labels
	var mid := x + bar_w / 2.0
	LockpickStyle.text(self, Vector2(mid, y0 - 10.0), "TENSION", 10, LockpickStyle.MUTED)
	var zone := params.zone(t)
	var zone_colour := (
		LockpickStyle.OK if zone == "sweet" else (LockpickStyle.WARN if zone == "low" else LockpickStyle.BAD)
	)
	LockpickStyle.text(self, Vector2(mid, y1 + 16.0), "%d%%" % roundi(t * 100.0), 11, zone_colour)
	LockpickStyle.text(self, Vector2(mid, y1 + 28.0), zone, 10, zone_colour)


func _round_polyline(points: PackedVector2Array, colour: Color, width: float) -> void:
	draw_polyline(points, colour, width, true)
	for point in points:
		draw_circle(point, width * 0.5, colour, true, -1.0, true)
