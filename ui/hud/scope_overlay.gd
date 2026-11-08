class_name ScopeOverlay
extends Control
## HUD scope view (ADR 0085), shown instead of the reticle while the player is scoped: black outside
## a round lens, a thin crosshair across it and a thin ring that is the scoped aim cone (the same
## AimModel.reticle_radius as the reticle, at the scope's field of view), all moved by the aim sway
## like the reticle. Fills the screen.

const BLACK := Color(0, 0, 0, 1)
const LINE := Color(0.05, 0.05, 0.05, 0.95)
const RING := Color(0.85, 0.15, 0.1, 0.9)
## Lens radius as a share of the viewport height.
const LENS_SHARE: float = 0.46
const SEGMENTS: int = 96

## Aim cone radius in pixels.
var radius: float = 0.0
## Offset of the aim point from the screen centre in pixels (sway).
var offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_cone(p_radius: float, p_offset: Vector2) -> void:
	if is_equal_approx(p_radius, radius) and p_offset.is_equal_approx(offset):
		return
	radius = p_radius
	offset = p_offset
	queue_redraw()


## Radius of the lens in pixels.
func lens_radius() -> float:
	return size.y * LENS_SHARE


func _draw() -> void:
	var centre := size * 0.5
	var lens := lens_radius()
	# Black everywhere but the lens: one thick ring from the lens edge out past the screen corners.
	var outer := size.length() * 0.5 + 4.0
	draw_arc(centre, (lens + outer) * 0.5, 0.0, TAU, SEGMENTS, BLACK, outer - lens + 2.0)
	draw_arc(centre, lens, 0.0, TAU, SEGMENTS, BLACK, 3.0, true)
	var aim := centre + offset
	draw_line(Vector2(aim.x - lens, aim.y), Vector2(aim.x + lens, aim.y), LINE, 1.0)
	draw_line(Vector2(aim.x, aim.y - lens), Vector2(aim.x, aim.y + lens), LINE, 1.0)
	if radius > 0.0:
		draw_arc(aim, radius, 0.0, TAU, 48, RING, 1.0, true)
