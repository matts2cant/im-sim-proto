class_name LockpickPinsView
extends Control
## The lockpicking screen's pins view (ADR 0107), shown at assist 3 and on practice locks: a port of
## the prototype's drawSide(), the lock seen from the side through clear acrylic. Chambers, brass key
## pins (their length from each pin's shear lift: they settle at new heights after a practice
## re-layout), steel drivers (spools waisted, serrated ones notched; a set driver held above the
## shear line), springs, the dashed shear line, the pick hooked under the current pin.

const KEY_TIP := 5.0

var screen: LockpickScreen


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	var model := screen.model if screen != null else null
	if model == null or model.pins.is_empty():
		return
	var w := size.x
	var h := size.y
	draw_style_box(LockpickStyle.rounded_box(LockpickStyle.BG, LockpickStyle.LINE, 10), Rect2(Vector2.ZERO, size))
	var x0 := w * 0.08
	var x1 := w * 0.94
	var top := h * 0.1
	var shear := h * 0.52
	var bottom := h * 0.86
	var key_base := bottom - 6.0
	var lift_px := (bottom - shear) * 0.78
	# Acrylic body and plug
	var acrylic := Color(160.0 / 255.0, 205.0 / 255.0, 228.0 / 255.0)
	draw_rect(Rect2(x0, top, x1 - x0, shear - top), Color(acrylic, 0.07))
	draw_rect(Rect2(x0, top, x1 - x0, shear - top), Color(acrylic, 0.35), false, 1.0)
	var plug_tint := Color(LockpickStyle.OK, 0.10) if model.opened else Color(acrylic, 0.12)
	draw_rect(Rect2(x0, shear, x1 - x0, bottom - shear), plug_tint)
	draw_rect(Rect2(x0, shear, x1 - x0, bottom - shear), Color(acrylic, 0.35), false, 1.0)
	# Shear line
	draw_dashed_line(Vector2(x0 - 6.0, shear), Vector2(x1 + 6.0, shear), Color(LockpickStyle.BRASS, 0.6), 1.0, 5.0)
	screen.style.text(self, Vector2(x1, shear - 4.0), "shear line", 10, Color(LockpickStyle.BRASS, 0.8), 1)
	var spacing := (x1 - x0) / model.pins.size()
	var pin_w := minf(spacing * 0.42, 24.0)
	for i in model.pins.size():
		var center_x := x0 + spacing * (i + 0.5)
		_draw_pin(model.pins[i], i, center_x, pin_w, top, shear, key_base, lift_px)
	# The pick from the left, hooked up under the current pin
	var px := x0 + spacing * (model.pick_shown + 0.5)
	var tip_y := key_base - model.tip * lift_px
	var shaft := PackedVector2Array([Vector2(0, key_base + 3.0)])
	shaft.append_array(
		LockpickStyle.quadratic(
			Vector2(px - 10.0, key_base + 3.0), Vector2(px - 2.0, key_base + 3.0), Vector2(px, tip_y + 2.0)
		)
	)
	draw_polyline(shaft, Color("cfd8e0"), 3.0, true)
	# Wrench at the plug's front
	draw_rect(Rect2(x0 - 3.0, bottom - 12.0, 8.0, 10.0), LockpickStyle.STEEL)
	var practice := is_instance_valid(screen.lock) and screen.lock.is_practice()
	var title := "PRACTICE LOCK · CLEAR ACRYLIC" if practice else "PINS"
	screen.style.text(self, Vector2(12.0, 22.0), title, 12, LockpickStyle.ACRYLIC, -1)


func _draw_pin(
	pin: PinTumbler.Pin, index: int, cx: float, pin_w: float, top: float, shear: float, key_base: float, lift_px: float
) -> void:
	var half := pin_w / 2.0
	# Chamber
	draw_rect(
		Rect2(cx - half - 2.0, top + 3.0, pin_w + 4.0, key_base - top - 3.0), Color(0.63, 0.8, 0.89, 0.25), false, 1.0
	)
	var key_len := maxf(10.0, key_base - pin.shown_shear * lift_px - shear)
	var key_bottom := key_base - pin.height * lift_px
	var key_top := key_bottom - key_len
	# Key pin (brass, pointed tip)
	var key := PackedVector2Array(
		[
			Vector2(cx - half, key_top),
			Vector2(cx + half, key_top),
			Vector2(cx + half, key_bottom - KEY_TIP),
			Vector2(cx, key_bottom),
			Vector2(cx - half, key_bottom - KEY_TIP),
		]
	)
	draw_colored_polygon(key, LockpickStyle.BRASS)
	# Driver (steel); held above the shear line once set
	var driver_len := (shear - top) * 0.34
	var driver_bottom := minf(key_top, shear) if pin.is_set else key_top
	if pin.spool == PinTumbler.Spool.FALSE_SET:
		driver_bottom = minf(driver_bottom, shear + 3.0)
	var driver_top := driver_bottom - driver_len
	if pin.type == PinTumbler.SPOOL:
		draw_colored_polygon(_spool(cx, half, pin_w * 0.28, driver_top, driver_bottom, driver_len), LockpickStyle.STEEL)
	else:
		draw_rect(Rect2(cx - half, driver_top, pin_w, driver_len), LockpickStyle.STEEL)
		if pin.type == PinTumbler.SERRATED:
			for k in range(1, 5):
				var y := driver_top + driver_len * k / 5.0
				draw_line(Vector2(cx - half, y), Vector2(cx - half + 4.0, y), Color("5d6974"), 1.0)
				draw_line(Vector2(cx + half, y), Vector2(cx + half - 4.0, y), Color("5d6974"), 1.0)
	# Spring
	var spring := PackedVector2Array()
	var coils := 7
	var s0 := top + 4.0
	for k in coils * 2 + 1:
		var y := s0 + (driver_top - s0) * k / (coils * 2.0)
		var x := cx if k == 0 else (cx + half - 2.0 if k % 2 == 1 else cx - half + 2.0)
		spring.append(Vector2(x, y))
	draw_polyline(spring, Color(0.78, 0.82, 0.86, 0.6), 1.0, true)
	# Label
	var label := str(index + 1) if pin.type == PinTumbler.STANDARD else "%d %s" % [index + 1, pin.type]
	screen.style.text(self, Vector2(cx, size.y - 4.0), label, 10, LockpickStyle.MUTED)


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
