class_name BodySilhouette
extends Control
## HUD body silhouette: the six parts as blocks coloured by health (HudRules.part_color).

## Part -> rectangle in a 60 x 140 layout (scaled to the control's size).
const LAYOUT: Dictionary[StringName, Rect2] = {
	&"head": Rect2(22, 0, 16, 18),
	&"torso": Rect2(16, 21, 28, 46),
	&"arm_l": Rect2(3, 22, 11, 46),
	&"arm_r": Rect2(46, 22, 11, 46),
	&"leg_l": Rect2(16, 70, 13, 70),
	&"leg_r": Rect2(31, 70, 13, 70),
}
const LAYOUT_SIZE := Vector2(60, 140)
const OUTLINE := Color(0, 0, 0, 0.7)

var body: BodyParts


func _process(_delta: float) -> void:
	queue_redraw()


## Colour shown for `part` now.
func part_color(part: StringName) -> Color:
	if body == null:
		return HudRules.HEALTHY
	return HudRules.part_color(body.model.ratio(part))


func _draw() -> void:
	var scale_factor := size / LAYOUT_SIZE
	for part: StringName in LAYOUT:
		var area := LAYOUT[part]
		var rect := Rect2(area.position * scale_factor, area.size * scale_factor)
		draw_rect(rect, part_color(part))
		draw_rect(rect, OUTLINE, false, 1.0)
