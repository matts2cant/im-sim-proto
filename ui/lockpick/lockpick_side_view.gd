class_name LockpickSideView
extends Control
## The lockpicking screen's lock (ADR 0109): a port of the final prototype's drawFront() and
## drawGauge(). The lock seen from the side, cut away along the keyway, in the proportions of a real
## clear practice lock (body `n * 0.148 + 0.25` body heights wide, housing and plug of similar height,
## chambers 45 % of the pin spacing, the plug's cam end with a screw slot). The tension wrench's blade
## sits in the keyway mouth, its arm swinging with tension. The rigid hook pick (flat handle with two
## rivets, thin shaft, small upturned hook, fixed lengths) pivots in the keyway mouth and slides in and
## out so its hook ends at the model's tip; it bends with force and pales under strain.
## With the clear lock (the Master assist, practice locks) the body is acrylic and the pins, springs,
## shear line and labels show; otherwise it is brass with a soft keyway groove, the pick solid in the
## groove and outside the lock and faded behind the brass. The tension gauge (assist 1+) stands at the
## right edge: bands at the picker's real thresholds, needle, % and zone word.

const ACRYLIC := Color(160.0 / 255.0, 205.0 / 255.0, 228.0 / 255.0)
const OPEN_TINT := Color(127.0 / 255.0, 214.0 / 255.0, 162.0 / 255.0)
const SHAFT := Color("cfd8e0")
const SHAFT_STRAINED := Color("e0d3c7")

var screen: LockpickScreen
## What the last draw showed (tests read these): the clear body, and the gauge.
var drawn_clear: bool = false
var drawn_gauge: bool = false

# The shake of the lock drawing (nudge), added to every transform of the lock.
var _jolt: Vector2 = Vector2.ZERO


## The lock's layout in the panel (the prototype's measures), for the current pin count.
class Layout:
	extends RefCounted
	var count: int
	var body_h: float
	var body_w: float
	var spacing: float
	var pin_w: float
	var x0_body: float
	var x1_body: float
	var top: float
	var bottom_body: float
	var shear: float
	var plug_bottom: float
	var key_base: float
	var lift_px: float
	## Centre of the front pin's slot minus half a slot.
	var x0: float
	var groove_top: float
	var groove_bottom: float
	var groove_end: float

	func _init(n: int, w: float, h: float) -> void:
		count = n
		var width_per_h := n * 0.148 + 0.25
		body_h = maxf(120.0, minf(h * 0.6, (w - 110.0) / 2.2 / width_per_h))
		body_w = body_h * width_per_h
		spacing = body_h * 0.148
		pin_w = spacing * 0.45
		x1_body = w - 100.0
		x0_body = x1_body - body_w
		top = (h - body_h) / 2.0 - h * 0.02
		bottom_body = top + body_h
		shear = top + body_h * 0.48
		plug_bottom = bottom_body - body_h * 0.07
		key_base = plug_bottom - (plug_bottom - shear) * 0.12
		lift_px = (plug_bottom - shear) * 0.78
		x0 = x0_body + body_w * 0.15
		groove_top = key_base - lift_px * 0.28
		groove_bottom = key_base + 5.0
		groove_end = x0 + spacing * n

	## The x of slot `slot`'s centre (0 = the front pin).
	func slot_x(slot: float) -> float:
		return x0 + spacing * (slot + 0.5)

	## The y of lift `lift` (0..1) above the keyway's base.
	func lift_y(lift: float) -> float:
		return key_base - lift * lift_px


## The pick's shapes in its own frame (pivot at the origin, the shaft along +x).
class Pick:
	extends RefCounted
	var shaft: PackedVector2Array
	var width: float
	var colour: Color
	var tip: Vector2
	var handle: PackedVector2Array
	var thick: float
	var rivets: PackedVector2Array


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	var model := screen.model if screen != null else null
	if model == null or model.pins.is_empty():
		return
	var w := size.x
	var h := size.y
	var bg := screen.style.radial(
		"side_bg", PackedColorArray([Color("222a32"), Color("0b0e11")]), PackedFloat32Array([0.0, 1.0])
	)
	var reach := maxf(w, h) * 0.75
	var focus := Vector2(w * 0.5, h * 0.45)
	draw_texture_rect(bg, Rect2(focus - Vector2(reach, reach), Vector2(reach, reach) * 2.0), false)
	var clear := screen.shows_pins()
	var layout := Layout.new(model.pins.size(), w, h)
	_jolt = Vector2(randf() - 0.5, randf() - 0.5) * model.nudge * 3.0
	draw_set_transform(_jolt)
	_draw_body(model, layout, clear)
	if clear:
		for i in model.pins.size():
			_draw_pin(model.pins[i], i, layout)
	_draw_wrench(model, layout)
	_draw_pick(model, layout, clear)
	draw_set_transform(Vector2.ZERO)
	drawn_clear = clear
	drawn_gauge = screen.shows_gauge()
	if drawn_gauge:
		_draw_gauge(model, w, h, (layout.top + layout.bottom_body) / 2.0, layout.body_h / 2.6)
	draw_style_box(LockpickStyle.rounded_box(Color(0, 0, 0, 0), LockpickStyle.LINE, 10), Rect2(Vector2.ZERO, size))


# Housing with rounded top corners, the plug with its cam end and screw slot, the grooves between
# the pins, the keyway (a soft groove in brass), its mouth and the shear line.
func _draw_body(model: PinTumbler, at: Layout, clear: bool) -> void:
	var edge := Color(ACRYLIC, 0.4) if clear else Color(0, 0, 0, 0.45)
	var housing := LockpickStyle.rounded_rect(
		Rect2(at.x0_body, at.top, at.body_w, at.bottom_body - at.top), at.body_h * 0.06
	)
	if clear:
		draw_colored_polygon(housing, Color(ACRYLIC, 0.07))
	else:
		LockpickStyle.fill_vertical(self, housing, _brass(false), at.top, at.shear, Color.WHITE)
	_outline(housing, edge, 1.0)
	var cap_w := at.body_w * 0.05
	var plug_h := at.plug_bottom - at.shear
	var plug := LockpickStyle.rounded_rect(Rect2(at.x0_body, at.shear, at.body_w + cap_w, plug_h), plug_h * 0.18)
	if clear:
		LockpickStyle.fill_vertical(self, plug, _glass(model.opened), at.shear, at.plug_bottom, Color.WHITE)
	else:
		LockpickStyle.fill_vertical(self, plug, _brass(true), at.shear, at.plug_bottom, Color.WHITE)
	_outline(plug, edge, 1.0)
	# The cam end's screw slot
	var slot_x := at.x1_body + cap_w * 0.55
	var slot_colour := Color(0.78, 0.82, 0.86, 0.5) if clear else Color(60.0 / 255.0, 40.0 / 255.0, 10.0 / 255.0, 0.7)
	draw_line(
		Vector2(slot_x, at.shear + plug_h * 0.3), Vector2(slot_x, at.plug_bottom - plug_h * 0.3), slot_colour, 2.0
	)
	# Plug grooves between the pins
	var groove_colour := (
		Color(0.78, 0.84, 0.88, 0.18) if clear else Color(90.0 / 255.0, 65.0 / 255.0, 20.0 / 255.0, 0.35)
	)
	for i in at.count + 1:
		var gx := at.x0 + at.spacing * i
		draw_line(Vector2(gx, at.shear + 2.0), Vector2(gx, at.plug_bottom - 2.0), groove_colour, 1.0)
	if not clear:
		var groove := LockpickStyle.rounded_rect(
			Rect2(at.x0_body, at.groove_top, at.groove_end - at.x0_body, at.groove_bottom - at.groove_top),
			(at.groove_bottom - at.groove_top) * 0.45
		)
		LockpickStyle.fill_vertical(self, groove, _groove(), at.groove_top, at.groove_bottom, Color.WHITE)
		if model.opened:
			draw_rect(Rect2(at.x0_body, at.shear, at.body_w, plug_h), Color(OPEN_TINT, 0.18))
	# Keyway mouth in the front face
	draw_rect(Rect2(at.x0_body - 2.0, at.key_base - at.lift_px * 0.3, 7.0, at.lift_px * 0.3 + 5.0), Color("07090b"))
	# Shear line
	var shear_colour := (
		Color(LockpickStyle.BRASS, 0.6) if clear else Color(40.0 / 255.0, 28.0 / 255.0, 10.0 / 255.0, 0.8)
	)
	draw_dashed_line(Vector2(at.x0_body, at.shear), Vector2(at.x1_body, at.shear), shear_colour, 1.0, 5.0)
	if clear:
		screen.style.text(
			self, Vector2(at.x1_body - 6.0, at.shear - 4.0), "shear line", 10, Color(LockpickStyle.BRASS, 0.8), 1
		)


# One pin stack through the acrylic: chamber, brass key pin resting on its lift (its length from the
# drawn shear lift, so it settles after a re-layout), steel driver (spools waisted, serrated ones
# notched; a set driver caught above the shear line), spring, label.
func _draw_pin(pin: PinTumbler.Pin, index: int, at: Layout) -> void:
	var cx := at.slot_x(index)
	var pw := at.pin_w
	var half := pw / 2.0
	var chamber_top := at.top + at.body_h * 0.04
	draw_rect(
		Rect2(cx - half - 2.0, chamber_top, pw + 4.0, at.key_base - chamber_top), Color(ACRYLIC, 0.25), false, 1.0
	)
	var key_len := maxf(8.0, at.key_base - pin.shown_shear * at.lift_px - at.shear)
	var key_bottom := at.lift_y(pin.height)
	var key_top := key_bottom - key_len
	var key := PackedVector2Array(
		[
			Vector2(cx - half, key_top),
			Vector2(cx + half, key_top),
			Vector2(cx + half, key_bottom - pw * 0.4),
			Vector2(cx, key_bottom),
			Vector2(cx - half, key_bottom - pw * 0.4),
		]
	)
	draw_colored_polygon(key, LockpickStyle.BRASS)
	var driver_len := (at.shear - at.top) * 0.3
	var driver_bottom := minf(key_top, at.shear) if pin.is_set else key_top
	if pin.spool == PinTumbler.Spool.FALSE_SET:
		driver_bottom = minf(driver_bottom, at.shear + 3.0)
	var driver_top := driver_bottom - driver_len
	if pin.type == PinTumbler.SPOOL:
		draw_colored_polygon(_spool(cx, half, pw * 0.28, driver_top, driver_bottom, driver_len), LockpickStyle.STEEL)
	else:
		draw_rect(Rect2(cx - half, driver_top, pw, driver_len), LockpickStyle.STEEL)
		if pin.type == PinTumbler.SERRATED:
			for k in range(1, 5):
				var y := driver_top + driver_len * k / 5.0
				draw_line(Vector2(cx - half, y), Vector2(cx - half + 3.0, y), Color("5d6974"), 1.0)
				draw_line(Vector2(cx + half, y), Vector2(cx + half - 3.0, y), Color("5d6974"), 1.0)
	var spring := PackedVector2Array()
	var coils := 8
	var s0 := at.top + at.body_h * 0.05
	for k in coils * 2 + 1:
		var y := s0 + (driver_top - s0) * k / (coils * 2.0)
		var x := cx if k == 0 else (cx + half - 1.0 if k % 2 == 1 else cx - half + 1.0)
		spring.append(Vector2(x, y))
	draw_polyline(spring, Color(0.78, 0.82, 0.86, 0.65), 1.0, true)
	screen.style.text(self, Vector2(cx, at.bottom_body + 16.0), str(index + 1), 10, LockpickStyle.MUTED)
	if pin.type != PinTumbler.STANDARD:
		var label := "spool" if pin.type == PinTumbler.SPOOL else "serr."
		screen.style.text(self, Vector2(cx, at.bottom_body + 29.0), label, 10, LockpickStyle.MUTED)


# Tension wrench: a short blade in the bottom of the keyway mouth, its arm hanging outside; more
# tension swings the arm further.
func _draw_wrench(model: PinTumbler, at: Layout) -> void:
	draw_set_transform(Vector2(at.x0_body, at.key_base + 3.0) + _jolt, -0.12 - model.tension * 0.35)
	var arm := PackedVector2Array(
		[Vector2(at.spacing * 0.7, 0.0), Vector2(-at.body_w * 0.03, 0.0), Vector2(-at.body_w * 0.05, at.body_h * 0.55)]
	)
	_round_polyline(arm, LockpickStyle.STEEL, 4.0)
	draw_set_transform(_jolt)


# The rigid hook pick. The pivot is the keyway mouth; the hook (fixed size) ends at the tip, so the
# shaft's angle and how far it is inserted follow from the tip; the rest (shaft, handle, fixed
# lengths) sticks out of the lock behind the pivot. On a brass lock it is drawn in three clipped
# passes: solid outside the lock, faded behind the brass, solid in the keyway groove.
func _draw_pick(model: PinTumbler, at: Layout, clear: bool) -> void:
	var tip := Vector2(at.slot_x(model.tip_x), at.lift_y(model.tip))
	var hook_h := clampf(at.lift_px * 0.18, 6.0, 14.0)
	var hook_w := hook_h * 0.8
	var pivot := Vector2(at.x0_body + 1.0, at.key_base - 3.0)
	var d := tip - pivot
	var reach := sqrt(maxf(1.0, d.length_squared() - hook_h * hook_h))
	var angle := atan2(d.y, d.x) + atan2(hook_h, reach)
	var inside := reach - hook_w
	var shaft_len := (at.x0 + at.spacing * at.count - pivot.x) * 1.06
	var handle_len := shaft_len * 1.15
	var thick := maxf(8.0, at.body_h * 0.05)
	var outside := shaft_len - inside
	var bow := minf(0.5, model.force) * at.body_h * 0.06
	var shaft := PackedVector2Array([Vector2(-outside, 0.0)])
	shaft.append_array(LockpickStyle.quadratic(Vector2.ZERO, Vector2(inside / 2.0, bow), Vector2(inside, 0.0), 10))
	shaft.append_array(
		LockpickStyle.quadratic(
			Vector2(inside, 0.0), Vector2(inside + hook_w, 0.0), Vector2(inside + hook_w, -hook_h), 8
		)
	)
	var hx1 := -outside
	var hx0 := hx1 - handle_len
	var pick := Pick.new()
	pick.shaft = shaft
	pick.width = maxf(2.5, at.body_h * 0.012)
	pick.colour = SHAFT_STRAINED if model.strain > 0.5 else SHAFT
	pick.tip = Vector2(inside + hook_w, -hook_h)
	pick.handle = LockpickStyle.rounded_rect(Rect2(hx0, -thick / 2.0, handle_len, thick), thick / 2.0, 4)
	pick.thick = thick
	pick.rivets = PackedVector2Array([Vector2(hx1 - thick * 0.8, 0.0), Vector2(hx0 + thick * 0.7, 0.0)])
	var frame := Transform2D(angle, pivot)
	draw_set_transform(pivot + _jolt, angle)
	if clear:
		_draw_pick_part(pick, PackedVector2Array(), 1.0)
	else:
		# Outside the lock: solid; inside the brass: faded; in the keyway groove: solid again.
		var big := size.x + size.y
		var inverse := frame.affine_inverse()
		var outside_lock := Rect2(-big, -big, at.x0_body + big, 3.0 * big)
		var inside_lock := Rect2(at.x0_body, -big, 2.0 * big, 3.0 * big)
		var groove := Rect2(at.x0_body, at.groove_top, at.groove_end - at.x0_body, at.groove_bottom - at.groove_top)
		_draw_pick_part(pick, inverse * LockpickStyle.rect_points(outside_lock), 1.0)
		_draw_pick_part(pick, inverse * LockpickStyle.rect_points(inside_lock), 0.4)
		_draw_pick_part(pick, inverse * LockpickStyle.rect_points(groove), 1.0)
	draw_set_transform(_jolt)


# The pick's parts inside `clip` (a polygon in the pick's frame; empty: everything) at `alpha`.
func _draw_pick_part(pick: Pick, clip: PackedVector2Array, alpha: float) -> void:
	var shafts: Array[PackedVector2Array] = [pick.shaft]
	var handles: Array[PackedVector2Array] = [pick.handle]
	if not clip.is_empty():
		shafts.assign(Geometry2D.intersect_polyline_with_polygon(pick.shaft, clip))
		handles.assign(Geometry2D.intersect_polygons(pick.handle, clip))
	for part in shafts:
		# Faded: no round joints (they would overlap and show as dots).
		if alpha < 1.0:
			draw_polyline(part, Color(pick.colour, alpha), pick.width, true)
		else:
			_round_polyline(part, pick.colour, pick.width)
	if clip.is_empty() or Geometry2D.is_point_in_polygon(pick.tip, clip):
		draw_circle(pick.tip, 1.8, Color(Color("e8eef3"), alpha), true, -1.0, true)
	var gradient := screen.style.linear(
		"pick_handle",
		PackedColorArray([Color("c3ccd4"), Color("9aa5ae"), Color("6f7a83")]),
		PackedFloat32Array([0.0, 0.5, 1.0])
	)
	for part in handles:
		LockpickStyle.fill_vertical(self, part, gradient, -pick.thick / 2.0, pick.thick / 2.0, Color(1, 1, 1, alpha))
		_outline(part, Color(0, 0, 0, 0.35 * alpha), 1.0)
	for rivet in pick.rivets:
		if clip.is_empty() or Geometry2D.is_point_in_polygon(rivet, clip):
			draw_circle(rivet, pick.thick * 0.16, Color(Color("7b858e"), alpha), true, -1.0, true)


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
	screen.style.text(self, Vector2(mid, y0 - 10.0), "TENSION", 10, LockpickStyle.MUTED)
	var zone := params.zone(t)
	var zone_colour := (
		LockpickStyle.OK if zone == "sweet" else (LockpickStyle.WARN if zone == "low" else LockpickStyle.BAD)
	)
	screen.style.text(self, Vector2(mid, y1 + 16.0), "%d%%" % roundi(t * 100.0), 11, zone_colour)
	screen.style.text(self, Vector2(mid, y1 + 28.0), zone, 10, zone_colour)


func _brass(light: bool) -> GradientTexture2D:
	if light:
		return screen.style.linear(
			"brass_light",
			PackedColorArray([Color("d9b865"), Color("e6c97a"), Color("a9853a")]),
			PackedFloat32Array([0.0, 0.5, 1.0])
		)
	return screen.style.linear(
		"brass",
		PackedColorArray([Color("c49a45"), Color("b58d3c"), Color("7d5f28")]),
		PackedFloat32Array([0.0, 0.5, 1.0])
	)


func _glass(opened: bool) -> GradientTexture2D:
	var tint := OPEN_TINT if opened else ACRYLIC
	return screen.style.linear(
		"glass_open" if opened else "glass",
		PackedColorArray([Color(tint, 0.08), Color(tint, 0.2), Color(tint, 0.06)]),
		PackedFloat32Array([0.0, 0.45, 1.0])
	)


func _groove() -> GradientTexture2D:
	var dark := Color(10.0 / 255.0, 8.0 / 255.0, 4.0 / 255.0)
	var rim := Color(20.0 / 255.0, 14.0 / 255.0, 4.0 / 255.0)
	return screen.style.linear(
		"groove",
		PackedColorArray([Color(rim, 0.15), Color(dark, 0.75), Color(dark, 0.8), Color(rim, 0.2)]),
		PackedFloat32Array([0.0, 0.35, 0.8, 1.0])
	)


func _spool(cx: float, half: float, waist: float, y0: float, y1: float, length: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(cx - half, y0),
			Vector2(cx + half, y0),
			Vector2(cx + half, y0 + length * 0.25),
			Vector2(cx + waist, y0 + length * 0.4),
			Vector2(cx + waist, y0 + length * 0.6),
			Vector2(cx + half, y0 + length * 0.75),
			Vector2(cx + half, y1),
			Vector2(cx - half, y1),
			Vector2(cx - half, y0 + length * 0.75),
			Vector2(cx - waist, y0 + length * 0.6),
			Vector2(cx - waist, y0 + length * 0.4),
			Vector2(cx - half, y0 + length * 0.25),
		]
	)


func _outline(points: PackedVector2Array, colour: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, colour, width, true)


func _round_polyline(points: PackedVector2Array, colour: Color, width: float) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, colour, width, true)
	for point in points:
		draw_circle(point, width * 0.5, colour, true, -1.0, true)
