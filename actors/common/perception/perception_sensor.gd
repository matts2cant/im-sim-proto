class_name PerceptionSensor
extends Node
## Component: a character's eyes (ADR 0067). look() finds the hostile entity it sees best: any
## entity whose Tags have one of `config.hostile_tags` and none of `config.hidden_tags` (Cloak),
## inside the focus or peripheral cone of the parent's facing (-Z), with a clear line of sight from
## the eyes (`eye_height` above the parent's origin, the feet) to the target's head, chest or feet
## (rays on `view_mask`: world and props block). The gain (suspicion per second) comes from
## VisionRules with the target's light level (light_level_of()) and stance tag. Targets are found
## by tags only (group Tags.GROUP), never by class or name. A character that cannot act
## (ActorState) sees nothing. GradedAwareness calls look() once per tick. look_for_bodies() finds
## downed allies (an ally tag and a `body_tags` tag: unconscious, dead) with the same cones, light
## and line of sight, measured to the middle of the body (ADR 0071); BodyDiscovery calls it.

## Fractions of the target's height the sight rays aim at: head, chest, feet.
const POINT_FRACTIONS: Array[float] = [0.9, 0.6, 0.1]
## Height assumed for a target without a collision shape (m), its origin at the feet.
const FALLBACK_HEIGHT: float = 1.8

@export var config: PerceptionConfig

var entity: Node3D
## The result of the last look() (null: nothing seen).
var last_sighting: Sighting


## One seen target.
class Sighting:
	extends RefCounted
	var target: Node3D
	## The target's origin (its feet for characters).
	var position: Vector3
	## Suspicion per second (VisionRules.gain()).
	var gain: float
	## Horizontal distance from the eyes and angle off the facing (degrees).
	var distance: float
	var angle: float
	var light: float

	func _init(p_target: Node3D, p_gain: float, p_distance: float, p_angle: float, p_light: float) -> void:
		target = p_target
		position = p_target.global_position
		gain = p_gain
		distance = p_distance
		angle = p_angle
		light = p_light


func _ready() -> void:
	entity = get_parent() as Node3D
	if entity == null:
		push_warning("PerceptionSensor %s: the parent is not a Node3D" % get_path())


## The PerceptionSensor child of `node`, or null.
static func of(node: Node) -> PerceptionSensor:
	if node == null:
		return null
	for child in node.get_children():
		if child is PerceptionSensor:
			return child as PerceptionSensor
	return null


## Light level (0 dark .. 1 lit) of `target`: its LightExposure's `level` (ADR 0065), or 1.0
## (fully lit) without one. The one place that reads the light system.
static func light_level_of(target: Node) -> float:
	var exposure := LightExposure.of(target)
	return clampf(exposure.level, 0.0, 1.0) if exposure != null else 1.0


func eye_position() -> Vector3:
	return entity.global_position + Vector3.UP * config.eye_height


## Horizontal facing (-Z of the parent).
func facing() -> Vector3:
	var forward := -entity.global_basis.z
	forward.y = 0.0
	return forward.normalized() if not forward.is_zero_approx() else Vector3.FORWARD


## True when an entity with these tags counts as hostile / ally / unseen.
func is_hostile(node: Node) -> bool:
	return _has_any(node, config.hostile_tags)


func is_ally(node: Node) -> bool:
	return _has_any(node, config.ally_tags)


## Every downed ally seen now (an ally tag, a body tag, no hidden tag), with its gain (as for a
## standing target; distance and angle to the middle of its collision shape). `wary` raises it.
func look_for_bodies(wary: bool = false) -> Array[Sighting]:
	var found: Array[Sighting] = []
	if entity == null or not ActorState.can_act(entity) or config.body_tags.is_empty():
		return found
	var eye := eye_position()
	var forward := facing()
	for node in get_tree().get_nodes_in_group(Tags.GROUP):
		var tags := node as Tags
		var target := node.get_parent() as Node3D
		if tags == null or target == null or target == entity or not target.is_inside_tree():
			continue
		var container := tags.container
		if not container.has_any(config.ally_tags) or not container.has_any(config.body_tags):
			continue
		if container.has_any(config.hidden_tags):
			continue
		var middle := center_of(target)
		var distance := VisionRules.flat_distance(eye, middle)
		var angle := VisionRules.angle_off(forward, eye, middle)
		var light := light_level_of(target)
		var gain := VisionRules.gain(angle, distance, light, false, wary, config)
		if gain > 0.0 and has_line_of_sight(eye, target):
			found.append(Sighting.new(target, gain, distance, angle, light))
	return found


## The middle of `target`'s first enabled collision shape (a body lying down: its torso), else its
## origin.
static func center_of(target: Node3D) -> Vector3:
	for child in target.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and not shape_node.disabled and shape_node.shape != null:
			return shape_node.global_position
	return target.global_position


## The hostile target seen best (highest gain) now, or null. `wary` raises the gain.
func look(wary: bool = false) -> Sighting:
	last_sighting = null
	if entity == null or not ActorState.can_act(entity):
		return null
	var eye := eye_position()
	var forward := facing()
	for node in get_tree().get_nodes_in_group(Tags.GROUP):
		var tags := node as Tags
		var target := node.get_parent() as Node3D
		if tags == null or target == null or target == entity or not target.is_inside_tree():
			continue
		if not tags.container.has_any(config.hostile_tags) or tags.container.has_any(config.hidden_tags):
			continue
		var distance := VisionRules.flat_distance(eye, target.global_position)
		var angle := VisionRules.angle_off(forward, eye, target.global_position)
		if VisionRules.zone_factor(angle, distance, config) <= 0.0:
			continue
		var light := light_level_of(target)
		var gain := VisionRules.gain(angle, distance, light, tags.has(config.crouch_tag), wary, config)
		if gain <= 0.0 or (last_sighting != null and gain <= last_sighting.gain):
			continue
		if has_line_of_sight(eye, target):
			last_sighting = Sighting.new(target, gain, distance, angle, light)
	return last_sighting


## True when any ray from `eye` to the target's head, chest or feet hits nothing on `view_mask`
## (the watcher's and the target's own bodies never block).
func has_line_of_sight(eye: Vector3, target: Node3D) -> bool:
	var exclude: Array[RID] = []
	if entity is CollisionObject3D:
		exclude.append((entity as CollisionObject3D).get_rid())
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	var space := entity.get_world_3d().direct_space_state
	for point in target_points(target):
		if PhysicsLayers.segment_clear(space, eye, point, config.view_mask, exclude):
			return true
	return false


## The points sight rays aim at: 0.9, 0.6 and 0.1 of the height of the target's first enabled
## collision shape (capsule, cylinder, box or sphere; it shrinks when a character crouches; a
## capsule laid flat is as high as its diameter) above its bottom, on its middle; or of a 1.8 m
## figure standing on its origin.
static func target_points(target: Node3D) -> PackedVector3Array:
	var base := target.global_position
	var height := FALLBACK_HEIGHT
	for child in target.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node == null or shape_node.disabled or shape_node.shape == null:
			continue
		var shape_height := _vertical_extent(shape_node.shape, shape_node.global_basis)
		if shape_height > 0.0:
			height = shape_height
			base = shape_node.global_position - Vector3.UP * height * 0.5
		break
	var points := PackedVector3Array()
	for fraction in POINT_FRACTIONS:
		points.append(base + Vector3.UP * height * fraction)
	return points


# World-space height of `shape` turned by `basis` (upright: its own height).
static func _vertical_extent(shape: Shape3D, basis: Basis) -> float:
	var axis := basis.orthonormalized().y
	var up := absf(axis.y)
	var across := sqrt(maxf(1.0 - up * up, 0.0))
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return (capsule.height - capsule.radius * 2.0) * up + capsule.radius * 2.0
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return cylinder.height * up + cylinder.radius * 2.0 * across
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		var b := basis.orthonormalized()
		return absf(b.x.y) * size.x + absf(b.y.y) * size.y + absf(b.z.y) * size.z
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius * 2.0
	return 0.0


static func _has_any(node: Node, queries: Array[StringName]) -> bool:
	var tags := ActorState.tags_of(node)
	return tags != null and tags.container.has_any(queries)
