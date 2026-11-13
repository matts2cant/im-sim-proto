class_name ImpactSensor
extends Node
## Component of a character body that physics props pass through: its collision layer is not in the
## props' mask (PhysicsLayers.OBJECT_MASK; the player since ADR 0054). Props do not collide with
## such a body, so their ImpactNoise never reports hitting it; this sensor does. Every physics tick
## it overlaps the body's own collision shape with the props (layer 4). A prop that starts
## overlapping it (not seen overlapping within the last ImpactSettings.throttle seconds: the body's
## own move_and_slide recovers out of a passing prop, so the overlap flickers), moving towards the
## body's axis at ImpactSettings.min_speed or more and not carried, deals `damage.blunt` CONTACT =
## ImpactRules.damage(speed, mass) to the body, source = the prop: the numbers ImpactNoise gives a
## body it hits. The body's own velocity does not count (walking into a crate is not an impact).
## On bodies that props do collide with (the training dummy) it stays off: their contacts reach
## ImpactNoise, so nothing is counted twice (ADR 0056).

@export var settings: ImpactSettings

var entity: CollisionObject3D
## True when props pass through the entity and this sensor reports their hits.
var active: bool = false

# Prop instance id -> time (s) it was last seen overlapping.
var _last_seen: Dictionary[int, float] = {}
var _time: float = 0.0


func _ready() -> void:
	entity = Entities.of_component(self) as CollisionObject3D
	active = entity != null and props_pass_through(entity.collision_layer)
	set_physics_process(active)


## True when bodies on `layer` are not in the props' collision mask.
static func props_pass_through(layer: int) -> bool:
	return (layer & PhysicsLayers.OBJECT_MASK) == 0


func _physics_process(delta: float) -> void:
	_time += delta
	var shape_node := _shape_node()
	if shape_node == null or shape_node.shape == null:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = PhysicsLayers.OBJECTS
	var own: Array[RID] = [entity.get_rid()]
	query.exclude = own
	for hit in entity.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var prop := hit["collider"] as RigidBody3D
		if prop == null:
			continue
		var id := prop.get_instance_id()
		if not _last_seen.has(id) or _time - _last_seen[id] > settings.throttle:
			_struck_by(prop, shape_node)
		_last_seen[id] = _time
	for id: int in _last_seen.keys():
		if _time - _last_seen[id] > settings.throttle:
			_last_seen.erase(id)


## Speed (m/s) at which a prop at `position` moving at `velocity` closes on the axis of `shape_node`
## (capsule or cylinder: its segment; other shapes: its centre).
static func approach_speed(position: Vector3, velocity: Vector3, shape_node: CollisionShape3D) -> float:
	var frame := shape_node.global_transform
	var up := frame.basis.y.normalized()
	var half := 0.0
	if shape_node.shape is CapsuleShape3D:
		var capsule := shape_node.shape as CapsuleShape3D
		half = maxf(capsule.height * 0.5 - capsule.radius, 0.0)
	elif shape_node.shape is CylinderShape3D:
		half = (shape_node.shape as CylinderShape3D).height * 0.5
	var along := clampf((position - frame.origin).dot(up), -half, half)
	var to_axis := frame.origin + up * along - position
	if to_axis.length() < 0.001:
		return velocity.length()
	return velocity.dot(to_axis.normalized())


func _struck_by(prop: RigidBody3D, shape_node: CollisionShape3D) -> void:
	var carryable := Carryable.of(prop)
	if carryable != null and carryable.is_carried():
		return
	var speed := approach_speed(prop.global_position, prop.linear_velocity, shape_node)
	if speed < settings.min_speed:
		return
	var damage := ImpactRules.damage(speed, prop.mass, settings)
	var data := {"actor": String(entity.name), "object": String(prop.name), "speed": speed, "damage": damage}
	EventLog.record(EventKinds.ACTOR_STRUCK, String(prop.name), String(entity.name), data)
	if damage > 0.0:
		StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", damage, entity, prop))


# The entity's first enabled collision shape (the player's capsule, resized when crouching).
func _shape_node() -> CollisionShape3D:
	for child in entity.get_children():
		if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
			return child as CollisionShape3D
	return null
