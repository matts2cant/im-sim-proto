class_name BodyDiscovery
extends Node
## Component (ADR 0071): finds downed allies and wakes the unconscious ones. Sibling of a
## GradedAwareness and a PerceptionSensor; tuning in the awareness config (group "Bodies").
## - Every physics tick it asks the sensor for the bodies it sees (look_for_bodies(): an ally tag
##   and `state.unconscious` or `state.dead`, same cones, light and line of sight as a target) and
##   steps a BodyDiscoveryModel with their gains: about 0.8 s for a lit body 4 m away; a body in the
##   dark only within 2 m (the close-light override). Each body is found once per watcher
##   (remembered and saved) until it stands up again.
## - Found: logged `actor.body_found {actor, body, state, point}`, `body_found` emitted (AlertComms
##   shouts), and the awareness told (GradedAwareness.notice_body): wary at least
##   `body_wary_duration`; unless Alerted (a fight goes on), Searching around the body, first
##   running to `tend_offset` beside it.
## - Unconscious: it stands by (the model's TEND phase); once it has been within `wake_distance`
##   (centre to the body's bounds, horizontal) for `wake_time` it emits a `revive` CONTACT stimulus
##   at the body (logged `actor.wake {actor, body}`): the body's `revive` receptron does the rest.
##   Dead bodies are only searched around. Not guard-specific: any character with these components.
## Saveable (found bodies, progress, the body being woken).

signal body_found(body: Node3D)

const REVIVE: StringName = &"revive"

var entity: Node3D
var awareness: GradedAwareness
var sensor: PerceptionSensor
var model: BodyDiscoveryModel
## The unconscious ally it is going to wake, or null.
var tending: Node3D = null
## Seconds it has been within wake_distance of `tending`.
var tend_time: float = 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_parent() as Node3D
	awareness = GradedAwareness.of_node(entity)
	sensor = PerceptionSensor.of(entity)
	if awareness == null or sensor == null:
		push_warning("BodyDiscovery %s: needs a GradedAwareness and a PerceptionSensor sibling" % get_path())
		set_physics_process(false)
		model = BodyDiscoveryModel.new()
		return
	var config := awareness.config
	model = BodyDiscoveryModel.new(config.body_discovery_threshold, config.body_discovery_decay)


## The BodyDiscovery child of `node`, or null.
static func of(node: Node) -> BodyDiscovery:
	if node == null:
		return null
	for child in node.get_children():
		if child is BodyDiscovery:
			return child as BodyDiscovery
	return null


func _physics_process(delta: float) -> void:
	if not ActorState.can_act(entity):
		tending = null
		tend_time = 0.0
		return
	_forget_standing()
	var seen: Dictionary[String, float] = {}
	var bodies: Dictionary[String, Node3D] = {}
	for sighting in sensor.look_for_bodies(awareness.model.is_wary()):
		var key := key_of(sighting.target)
		seen[key] = sighting.gain
		bodies[key] = sighting.target
	for key in model.step(delta, seen):
		_found(bodies[key])
	_tend(delta)


## The key a body is remembered by: its path from this character.
func key_of(body: Node) -> String:
	return String(entity.get_path_to(body))


func has_found(body: Node) -> bool:
	return model.is_found(key_of(body))


## Global bounds of `body`'s collision shapes (its origin when it has none).
static func body_bounds(body: Node3D) -> AABB:
	var bounds := AABB(body.global_position, Vector3.ZERO)
	var first := true
	for child in body.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node == null or shape_node.disabled or shape_node.shape == null:
			continue
		var box := shape_node.global_transform * shape_node.shape.get_debug_mesh().get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## Horizontal distance from `from` to the nearest point of `bounds` (0 inside).
static func flat_gap(from: Vector3, bounds: AABB) -> float:
	var nearest := _nearest_flat(from, bounds)
	return Vector2(from.x - nearest.x, from.z - nearest.z).length()


## Where to stand to wake `body`: `offset` out from its bounds towards `from`, at its feet's height.
static func approach_point(from: Vector3, body: Node3D, offset: float) -> Vector3:
	var bounds := body_bounds(body)
	var nearest := _nearest_flat(from, bounds)
	var out := Vector3(from.x - nearest.x, 0.0, from.z - nearest.z)
	if out.length() < 0.01:
		var centre := bounds.get_center()
		out = Vector3(from.x - centre.x, 0.0, from.z - centre.z)
	if out.length() < 0.01:
		out = Vector3.BACK
	var point := nearest + out.normalized() * offset
	point.y = body.global_position.y
	return point


func _found(body: Node3D) -> void:
	var unconscious := ActorState.has(body, ActorState.UNCONSCIOUS) and not ActorState.is_dead(body)
	var at := PerceptionSensor.center_of(body)
	var data := {
		"actor": String(entity.name),
		"body": String(body.name),
		"state": "unconscious" if unconscious else "dead",
		"point": at,
	}
	EventLog.record(&"actor.body_found", String(entity.name), String(body.name), data)
	body_found.emit(body)
	var approach := approach_point(entity.global_position, body, awareness.config.tend_offset)
	if awareness.notice_body(at, approach, unconscious) and unconscious:
		tending = body
		tend_time = 0.0


func _tend(delta: float) -> void:
	if tending == null:
		return
	var model_state := awareness.model
	if not model_state.tending or not is_instance_valid(tending) or not tending.is_inside_tree():
		tending = null
		tend_time = 0.0
		return
	if ActorState.can_act(tending) or ActorState.is_dead(tending):
		# Woken by someone else, or dead now: nothing to do here.
		model_state.end_tend()
		tending = null
		return
	if flat_gap(entity.global_position, body_bounds(tending)) > awareness.config.wake_distance:
		tend_time = 0.0
		return
	tend_time += delta
	if tend_time >= awareness.config.wake_time:
		_wake(tending)


func _wake(body: Node3D) -> void:
	var data := {"actor": String(entity.name), "body": String(body.name)}
	EventLog.record(&"actor.wake", String(entity.name), String(body.name), data)
	StimulusSystem.emit(Stimulus.make_contact(REVIVE, 1.0, body, entity))
	tending = null
	tend_time = 0.0
	awareness.model.end_tend()


# Found bodies that stand again (woken) may be found again when they go down later.
func _forget_standing() -> void:
	for key: String in model.found.keys():
		var node := entity.get_node_or_null(NodePath(key))
		if node != null and ActorState.can_act(node):
			model.forget(key)


static func _nearest_flat(from: Vector3, bounds: AABB) -> Vector3:
	var end := bounds.end
	return Vector3(
		clampf(from.x, bounds.position.x, end.x), bounds.get_center().y, clampf(from.z, bounds.position.z, end.z)
	)


func save_state() -> Dictionary:
	var data := model.to_dict()
	data["tending"] = key_of(tending) if is_instance_valid(tending) else ""
	data["tend_time"] = tend_time
	return data


func load_state(data: Dictionary) -> void:
	model.from_dict(data)
	var key := String(data.get("tending", ""))
	tending = entity.get_node_or_null(NodePath(key)) as Node3D if not key.is_empty() else null
	tend_time = float(data.get("tend_time", 0.0))
