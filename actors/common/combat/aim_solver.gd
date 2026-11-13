class_name AimSolver
extends RefCounted
## Where an armed shooter aims at a target (audit Q9), one rule for every shooter (CombatBehaviour,
## Turret): the first of the target's aim points (its hitboxes: torso, head, arms, legs; without
## hitboxes the chest, head and feet of its collision shape) whose line of fire is clear, i.e. the
## first thing a weapon ray (PhysicsLayers.WEAPON_MASK) meets on the way belongs to the target; the
## torso, unclear, when none is. look_at() points the aiming node at it.

## Aim at the target's hitboxes in this order (the torso first).
const AIM_PARTS: Array[StringName] = [
	BodyDamageModel.TORSO,
	BodyDamageModel.HEAD,
	BodyDamageModel.ARM_L,
	BodyDamageModel.ARM_R,
	BodyDamageModel.LEG_L,
	BodyDamageModel.LEG_R,
]


## The point chosen on a target and whether the line of fire to it is clear.
class Choice:
	extends RefCounted
	var point: Vector3
	var clear: bool

	func _init(p_point: Vector3, p_clear: bool) -> void:
		point = p_point
		clear = p_clear


## The first of `target`'s aim points with a clear line of fire from `from` (the shooter's own
## colliders, `exclude`, left out: OwnBody.rids()); the first aim point, unclear, when none is.
static func choose(space: PhysicsDirectSpaceState3D, from: Vector3, target: Node3D, exclude: Array[RID]) -> Choice:
	var points := aim_points(target)
	for point in points:
		if line_of_fire_clear(space, from, point, target, exclude):
			return Choice.new(point, true)
	return Choice.new(points[0] if not points.is_empty() else target.global_position, false)


## Points to aim at on `entity`: its hitboxes (torso, head, arms, legs), or chest, head and feet of
## its collision shape (PerceptionSensor.target_points) without hitboxes.
static func aim_points(entity: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	var boxes := Hitboxes.of(entity)
	if boxes != null:
		for part in AIM_PARTS:
			var box := boxes.box(part)
			if box != null:
				points.append(box.global_position)
	if points.is_empty():
		var shape_points := PerceptionSensor.target_points(entity)
		points = PackedVector3Array([shape_points[1], shape_points[0], shape_points[2]])
	return points


## True when the first thing a weapon ray (PhysicsLayers.WEAPON_MASK) meets from `from` to `point`
## belongs to `entity` (one of its hitboxes): not an ally, a wall or a prop in between.
static func line_of_fire_clear(
	space: PhysicsDirectSpaceState3D, from: Vector3, point: Vector3, entity: Node, exclude: Array[RID]
) -> bool:
	var beyond := from + (point - from) * 1.05
	var query := PhysicsRayQueryParameters3D.create(from, beyond, PhysicsLayers.WEAPON_MASK, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider := hit["collider"] as Node
	return collider == entity or entity.is_ancestor_of(collider)


## Turns `node` so its -Z points at `point` (Y up); leaves it as it is when the point is on it or
## straight above or below it, where look_at() fails.
static func look_at(node: Node3D, point: Vector3) -> void:
	var to_point := point - node.global_position
	if to_point.length() > 0.01 and to_point.normalized().cross(Vector3.UP).length() > 0.01:
		node.look_at(point, Vector3.UP)
