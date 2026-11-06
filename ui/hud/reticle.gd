class_name Reticle
extends Control
## HUD reticle: a centre dot, and with a ranged weapon a circle that is exactly the aim cone
## (AimModel.reticle_radius), moved by the aim sway. Fills the screen; draws at its centre.

const COLOR := Color(1, 1, 1, 0.85)
const SHADOW := Color(0, 0, 0, 0.6)
const DOT_RADIUS: float = 2.0

## Cone radius in pixels; 0 = dot only.
var radius: float = 0.0
## Offset of the aim point from the screen centre in pixels (sway).
var offset: Vector2 = Vector2.ZERO


func show_cone(p_radius: float, p_offset: Vector2) -> void:
	if is_equal_approx(p_radius, radius) and p_offset.is_equal_approx(offset):
		return
	radius = p_radius
	offset = p_offset
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5 + offset
	draw_circle(centre, DOT_RADIUS + 1.0, SHADOW)
	draw_circle(centre, DOT_RADIUS, COLOR)
	if radius <= 0.0:
		return
	draw_arc(centre, radius, 0.0, TAU, 64, SHADOW, 3.0, true)
	draw_arc(centre, radius, 0.0, TAU, 64, COLOR, 1.5, true)
