class_name Reticle
extends Control
## HUD crosshair (Deus Ex style; user request 2026-11-12, ADR 0123): a centre dot and, with a ranged
## weapon, four arms (up, down, left, right) whose inner ends sit exactly on the aim cone's radius
## (AimModel.reticle_radius), so the crosshair opens and closes with the accuracy; the whole
## crosshair moves with the aim offset (sway, the recoil the camera does not follow). When the aim is
## on something the weapon can damage within its range (show_target()), each arm gets a short cap
## across its outer end (a "T"). Melee and holstered: the dot only. Fills the screen; draws at its
## centre.

const COLOR := Color(1, 1, 1, 0.9)
const SHADOW := Color(0, 0, 0, 0.6)
const DOT_RADIUS: float = 2.0
const MIN_DOT_RADIUS: float = 0.8
## Arm length and cap length (pixels at a 1080 px tall viewport; they scale with its height).
const ARM_LENGTH_1080: float = 11.0
const CAP_LENGTH_1080: float = 7.0
## Arm thickness (pixels) and the dark outline around it.
const ARM_WIDTH: float = 2.0
const OUTLINE: float = 1.0
const REFERENCE_HEIGHT: float = 1080.0

## Cone radius in pixels (the arms' inner ends); 0 = dot only.
var radius: float = 0.0
## Offset of the aim point from the screen centre in pixels.
var offset: Vector2 = Vector2.ZERO
## The aim is on a target in range: the arms get their caps.
var on_target: bool = false
## Colour of the arms and caps on a target. The hook for colouring by hostility (factions, later):
## the HUD passes it to show_target(); white for now.
var target_color: Color = COLOR


func show_cone(p_radius: float, p_offset: Vector2) -> void:
	if is_equal_approx(p_radius, radius) and p_offset.is_equal_approx(offset):
		return
	radius = p_radius
	offset = p_offset
	queue_redraw()


## Caps on the arms while the aim is on a target (`color`: the target's colour hook).
func show_target(p_on_target: bool, color: Color = COLOR) -> void:
	if p_on_target == on_target and color == target_color:
		return
	on_target = p_on_target
	target_color = color
	queue_redraw()


## Length of an arm in pixels at the current height.
func arm_length() -> float:
	return ARM_LENGTH_1080 * _scale()


## Inner and outer end of each arm, from the aim point (pixels): up, down, left, right. Empty
## without a cone (dot only).
func arm_segments() -> Array[PackedVector2Array]:
	var arms: Array[PackedVector2Array] = []
	if radius <= 0.0:
		return arms
	var aim := size * 0.5 + offset
	var length := arm_length()
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		arms.append(PackedVector2Array([aim + direction * radius, aim + direction * (radius + length)]))
	return arms


## Whether `collider` is something a weapon can damage: a character's hitbox, or an entity with
## BodyParts or Breakable (components, never names).
static func is_target(collider: Node) -> bool:
	if collider == null:
		return false
	if not Hitboxes.part_of(collider).is_empty():
		return true
	return BodyParts.of(collider) != null or Breakable.of(collider) != null


func _draw() -> void:
	var centre := size * 0.5 + offset
	# The dot shrinks with a tight cone so it does not swallow the arms' inner ends.
	var dot := DOT_RADIUS if radius <= 0.0 else clampf(radius * 0.3, MIN_DOT_RADIUS, DOT_RADIUS)
	draw_circle(centre, dot + 1.0, SHADOW)
	draw_circle(centre, dot, COLOR)
	var arms := arm_segments()
	if arms.is_empty():
		return
	var color := target_color if on_target else COLOR
	var cap := CAP_LENGTH_1080 * _scale() * 0.5
	for pass_index in 2:
		var outline := pass_index == 0
		for arm in arms:
			var along := (arm[1] - arm[0]).normalized()
			_bar(arm[0], arm[1], outline, color)
			if on_target:
				var across := Vector2(-along.y, along.x) * cap
				_bar(arm[1] - across, arm[1] + across, outline, color)


# A 2 px bar from `from` to `to`; the outline pass draws it 1 px larger in the shadow colour.
func _bar(from: Vector2, to: Vector2, outline: bool, color: Color) -> void:
	var along := (to - from).normalized()
	var grow := OUTLINE if outline else 0.0
	draw_line(from - along * grow, to + along * grow, SHADOW if outline else color, ARM_WIDTH + grow * 2.0)


func _scale() -> float:
	return maxf(size.y, 1.0) / REFERENCE_HEIGHT
