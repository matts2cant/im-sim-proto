class_name LightGauge
extends Control
## HUD light gauge above the body silhouette and energy bar (ADR 0065): a gem whose glow and a
## bar whose fill follow the entity's LightExposure level, coloured by band so dark / dim / lit
## read at a glance. The shown value eases towards the level (display only).

## Upper edges of the dark and dim bands of the colour (display only, not perception rules).
const DARK_BELOW: float = 0.12
const LIT_FROM: float = 0.45
const DARK := Color(0.2, 0.3, 0.55)
const DIM := Color(0.85, 0.6, 0.2)
const LIT := Color(1.0, 0.95, 0.55)
const BACK := Color(0.04, 0.05, 0.08, 0.65)
const OUTLINE := Color(0, 0, 0, 0.75)
## How fast the shown value follows the level (per second).
const EASE_RATE: float = 8.0

var exposure: LightExposure
## The value drawn, easing towards the exposure's level.
var shown: float = 0.0


## Colour of the gauge for `value`: the dark, dim or lit band colour.
static func band_color(value: float) -> Color:
	if value < DARK_BELOW:
		return DARK
	if value < LIT_FROM:
		return DIM
	return LIT


func level() -> float:
	return exposure.level if is_instance_valid(exposure) else 0.0


func _process(delta: float) -> void:
	shown = lerpf(shown, level(), minf(EASE_RATE * delta, 1.0))
	queue_redraw()


func _draw() -> void:
	var gem_radius := size.y * 0.5
	var gem_centre := Vector2(gem_radius, gem_radius)
	var color := band_color(level())
	draw_circle(gem_centre, gem_radius, BACK)
	draw_circle(gem_centre, gem_radius * (0.35 + 0.6 * shown), color.darkened(0.6 * (1.0 - shown)))
	draw_arc(gem_centre, gem_radius, 0.0, TAU, 24, OUTLINE, 1.5)
	var bar := Rect2(
		Vector2(gem_radius * 2.0 + 6.0, size.y * 0.3), Vector2(size.x - gem_radius * 2.0 - 6.0, size.y * 0.4)
	)
	draw_rect(bar, BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(shown, 0.0, 1.0), bar.size.y)), color)
	draw_rect(bar, OUTLINE, false, 1.0)
