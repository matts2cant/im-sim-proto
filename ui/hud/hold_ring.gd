class_name HoldRing
extends Control
## HUD ring around the crosshair while E is held on a target with a hold action (ADR 0142: holding
## E on a downed body carries it instead of looting it): it fills clockwise from the top as the hold
## goes on (Interactor.hold_progress(), 0..1 over InteractorConfig.hold_time) and hides when no hold
## is in progress. Fills the screen and draws at its centre plus `offset` (the HUD passes the
## reticle's aim offset). Look from the HUD theme (type variation `HudHoldRing`: colours `fill` and
## `track`, constants `radius` and `width`, in pixels at 1080 high, scaled with the screen).

const REFERENCE_HEIGHT: float = 1080.0
const POINTS: int = 48

## 0..1 of the hold; 0 hides the ring.
var progress: float = 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if value == progress:
			return
		progress = value
		visible = progress > 0.0
		queue_redraw()
## Offset of the aim point from the screen centre (pixels).
var offset: Vector2 = Vector2.ZERO:
	set(value):
		if value == offset:
			return
		offset = value
		if visible:
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = progress > 0.0


## Radius of the ring on this screen (pixels).
func radius() -> float:
	return get_theme_constant(&"radius") * _scale()


func _scale() -> float:
	return maxf(size.y, 1.0) / REFERENCE_HEIGHT


func _draw() -> void:
	if progress <= 0.0:
		return
	var centre := size * 0.5 + offset
	var ring := radius()
	var width := maxf(get_theme_constant(&"width") * _scale(), 1.5)
	draw_arc(centre, ring, 0.0, TAU, POINTS, get_theme_color(&"track"), width, true)
	var start := -PI * 0.5
	draw_arc(centre, ring, start, start + TAU * progress, POINTS, get_theme_color(&"fill"), width, true)
