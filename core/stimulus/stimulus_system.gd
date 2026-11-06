extends Node
## Autoload: queues, propagates and delivers stimuli on the fixed physics tick.
## emit() queues; the queue is processed FIFO in _physics_process. Stimuli emitted while processing
## (by effects) wait for the next tick: no recursion, chain depth capped at MAX_DEPTH.
## The queue is transient and not saved. See design/game/stimulus-response.md.

## After a stimulus is delivered, with the propagation polylines computed for it (PATH propagation
## and ray hits). Debug overlays listen to this; gameplay must not.
signal stimulus_processed(stimulus: Stimulus, paths: Array[PackedVector3Array])

const MAX_DEPTH: int = 16

var _queue: Array[Stimulus] = []
# Registration order is delivery order (deterministic).
var _receivers: Array[StimulusReceiver] = []
var _next_id: int = 1
# The stimulus being delivered; effects that emit during delivery become its children.
var _current: Stimulus = null


class Reach:
	extends RefCounted
	var distance: float
	var points: PackedVector3Array
	## "straight", "path" or "straight_fallback".
	var mode: String

	func _init(p_distance: float, p_points: PackedVector3Array, p_mode: String) -> void:
		distance = p_distance
		points = p_points
		mode = p_mode


func _physics_process(_delta: float) -> void:
	if _queue.is_empty():
		return
	var batch := _queue
	_queue = []
	for stimulus in batch:
		_process_stimulus(stimulus)
	_current = null


## Queues `stimulus` for the next tick and assigns its id and depth. Depth is the depth of the
## stimulus being delivered (or of `parent`) + 1, else 0. Beyond MAX_DEPTH it is dropped and logged.
func emit(stimulus: Stimulus, parent: Stimulus = null) -> void:
	stimulus.id = _next_id
	_next_id += 1
	var cause := parent if parent != null else _current
	stimulus.depth = cause.depth + 1 if cause != null else 0
	if stimulus.depth > MAX_DEPTH:
		var data := {"id": stimulus.id, "type": stimulus.type, "depth": stimulus.depth}
		EventLog.record(&"stimulus.dropped", stimulus.source_name(), "", data)
		return
	_queue.append(stimulus)


## Drops every queued stimulus (level change, quickload).
func clear() -> void:
	_queue.clear()


func pending_count() -> int:
	return _queue.size()


func register(receiver: StimulusReceiver) -> void:
	if not _receivers.has(receiver):
		_receivers.append(receiver)


func unregister(receiver: StimulusReceiver) -> void:
	_receivers.erase(receiver)


func receivers() -> Array[StimulusReceiver]:
	return _receivers.duplicate()


func _process_stimulus(stimulus: Stimulus) -> void:
	_current = stimulus
	var target := String(stimulus.target.name) if is_instance_valid(stimulus.target) else ""
	var emitted := {
		"id": stimulus.id,
		"type": stimulus.type,
		"intensity": stimulus.intensity,
		"origin": stimulus.origin,
		"depth": stimulus.depth,
		"source": stimulus.source_name(),
		"shape": Stimulus.shape_name(stimulus.shape),
	}
	EventLog.record(&"stimulus.emitted", stimulus.source_name(), target, emitted)
	var paths: Array[PackedVector3Array] = []
	match stimulus.shape:
		Stimulus.Shape.RADIUS:
			_deliver_radius(stimulus, paths)
		Stimulus.Shape.CONTACT:
			if is_instance_valid(stimulus.target):
				_deliver_to_node(stimulus, stimulus.target, 0.0)
		Stimulus.Shape.RAY:
			_deliver_ray(stimulus, paths)
	stimulus_processed.emit(stimulus, paths)


func _deliver_radius(stimulus: Stimulus, paths: Array[PackedVector3Array]) -> void:
	for receiver: StimulusReceiver in _receivers.duplicate():
		if not _deliverable(receiver) or not receiver.wants(stimulus):
			continue
		var to := receiver.global_position
		# Paths are never shorter than the straight line, so this skips most path queries.
		if stimulus.origin.distance_to(to) > stimulus.radius:
			continue
		var reach := _reach(stimulus, receiver)
		if stimulus.propagation == Stimulus.Propagation.PATH:
			paths.append(reach.points)
		var perceived := stimulus.perceived_at(reach.distance)
		if perceived < 0.0:
			continue
		receiver.receive(stimulus, perceived, {"distance": reach.distance, "propagation": reach.mode})


func _deliver_ray(stimulus: Stimulus, paths: Array[PackedVector3Array]) -> void:
	var direction := stimulus.direction.normalized()
	if direction.is_zero_approx() or stimulus.length <= 0.0:
		return
	var query := PhysicsRayQueryParameters3D.create(stimulus.origin, stimulus.origin + direction * stimulus.length)
	if stimulus.source is CollisionObject3D and is_instance_valid(stimulus.source):
		query.exclude = [(stimulus.source as CollisionObject3D).get_rid()]
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		paths.append(PackedVector3Array([query.from, query.to]))
		return
	var point: Vector3 = hit["position"]
	paths.append(PackedVector3Array([stimulus.origin, point]))
	_deliver_to_node(stimulus, hit["collider"] as Node, stimulus.origin.distance_to(point))


## Delivers to the receivers of `node`, or of its nearest ancestor that has receivers
## (a hitbox inside an entity delivers to the entity's receivers).
func _deliver_to_node(stimulus: Stimulus, node: Node, distance: float) -> void:
	while node != null:
		var owned: Array[StimulusReceiver] = _receivers.filter(
			func(receiver: StimulusReceiver) -> bool: return _deliverable(receiver) and receiver.entity == node
		)
		if not owned.is_empty():
			for receiver in owned:
				if receiver.wants(stimulus):
					receiver.receive(stimulus, stimulus.intensity, {"distance": distance})
			return
		node = node.get_parent()


func _deliverable(receiver: StimulusReceiver) -> bool:
	return is_instance_valid(receiver) and receiver.is_inside_tree()


func _reach(stimulus: Stimulus, receiver: StimulusReceiver) -> Reach:
	var to := receiver.global_position
	var straight := PackedVector3Array([stimulus.origin, to])
	if stimulus.propagation == Stimulus.Propagation.STRAIGHT:
		return Reach.new(stimulus.origin.distance_to(to), straight, "straight")
	var map := receiver.get_world_3d().navigation_map
	var nav := PackedVector3Array()
	if NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty():
		nav = NavigationServer3D.map_get_path(map, stimulus.origin, to, true)
	if nav.is_empty():
		var fallback := stimulus.origin.distance_to(to) + _attenuation(straight)
		return Reach.new(fallback, straight, "straight_fallback")
	var points := PackedVector3Array([stimulus.origin])
	points.append_array(nav)
	points.append(to)
	return Reach.new(StimulusPropagation.polyline_length(points) + _attenuation(points), points, "path")


## Sum of extra_metres of every enabled SoundAttenuator the polyline passes through (each once).
func _attenuation(points: PackedVector3Array) -> float:
	var extra := 0.0
	for node in get_tree().get_nodes_in_group(SoundAttenuator.GROUP):
		var attenuator := node as SoundAttenuator
		if attenuator != null and attenuator.enabled and attenuator.crosses(points):
			extra += attenuator.extra_metres
	return extra
