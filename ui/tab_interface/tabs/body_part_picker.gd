class_name BodyPartPicker
extends Control
## The Health page's body silhouette: the six parts (BodySilhouette's layout) coloured by health,
## the selected one outlined in amber; clicking a part selects it.

signal part_clicked(part: StringName)

const OUTLINE := Color(0, 0, 0, 0.75)

var body: BodyParts
var selected: StringName = &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


## The part under `point` (local coordinates), or "".
func part_at(point: Vector2) -> StringName:
	for part: StringName in BodySilhouette.LAYOUT:
		if part_rect(part).grow(2.0).has_point(point):
			return part
	return &""


## Where `part` is drawn, in local coordinates (the layout scaled to fit, centred).
func part_rect(part: StringName) -> Rect2:
	var factor := minf(size.x / BodySilhouette.LAYOUT_SIZE.x, size.y / BodySilhouette.LAYOUT_SIZE.y)
	var offset := (size - BodySilhouette.LAYOUT_SIZE * factor) * 0.5
	var area: Rect2 = BodySilhouette.LAYOUT.get(part, Rect2())
	return Rect2(offset + area.position * factor, area.size * factor)


func part_color(part: StringName) -> Color:
	if body == null:
		return HudRules.HEALTHY
	return HudRules.part_color(body.model.ratio(part))


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var part := part_at(click.position)
	if not part.is_empty():
		part_clicked.emit(part)
		accept_event()


func _draw() -> void:
	for part: StringName in BodySilhouette.LAYOUT:
		var rect := part_rect(part)
		draw_rect(rect, part_color(part))
		draw_rect(rect, OUTLINE, false, 2.0)
	if not selected.is_empty():
		draw_rect(part_rect(selected).grow(1.0), CharacterTabStyle.AMBER, false, 3.0)
