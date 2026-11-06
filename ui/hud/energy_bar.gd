class_name EnergyBar
extends Control
## HUD energy bar beside the body silhouette: a vertical bar filled to the entity's Energy fraction.

const FILL := Color(0.3, 0.75, 1.0)
const EMPTY := Color(0.05, 0.08, 0.12, 0.6)
const OUTLINE := Color(0, 0, 0, 0.7)

var energy: Energy


func _process(_delta: float) -> void:
	queue_redraw()


func fraction() -> float:
	return energy.fraction() if energy != null else 0.0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, EMPTY)
	var filled := size.y * fraction()
	draw_rect(Rect2(0, size.y - filled, size.x, filled), FILL)
	draw_rect(rect, OUTLINE, false, 1.0)
