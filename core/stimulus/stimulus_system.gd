extends Node
## Autoload: queues, propagates and delivers stimuli on the fixed physics tick.
## emit() queues; the queue is processed FIFO in _physics_process. Stimuli emitted while processing
## (by effects) wait for the next tick: no recursion, chain depth capped at MAX_DEPTH.
## The queue is transient and not saved. See design/game/stimulus-response.md.

## After a stimulus is delivered, with the propagation polylines computed for it (PATH propagation
## and ray hits). Debug overlays listen to this; gameplay must not.
signal stimulus_processed(stimulus: Stimulus, paths: Array[PackedVector3Array])

const MAX_DEPTH: int = 16
## PATH stimuli (noise) follow the navmesh on every navigation layer: they pass doorways characters
## may not path through (a locked door's link is off their layer, ADR 0078).
const PATH_NAVIGATION_LAYERS: int = 0xFFFFFFFF
## A gap this short between a PATH stimulus's end and the navmesh path is taken as open air (a point
## beside its polygon, at most the bake's agent radius and height offset away); longer gaps are
## checked with rays (ADR 0094).
const PATH_GAP_FREE: float = 0.6
## Gap rays run this far above both ends, clear of the surface each rests on...
const PATH_GAP_LIFT: float = 0.25
## ...and stop this short of each end, clear of a wall a noise was made on.
const PATH_GAP_SKIN: float = 0.1

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
	if _prepare(stimulus, parent):
		_queue.append(stimulus)


## Delivers `stimulus` right away when called outside stimulus processing: a deliberate act from
## input or UI (using an item, possibly while the game is paused and no tick runs; ADR 0057). Called
## during processing (from an effect) it queues like emit(), so there is still no recursion.
## Stimuli its effects emit are queued for the next tick as its children.
func emit_now(stimulus: Stimulus) -> void:
	if _current != null:
		emit(stimulus)
		return
	if _prepare(stimulus, null):
		_process_stimulus(stimulus)
		_current = null


# Assigns id, depth and cause_id and applies the source's scale (Stimulus.scale_attribute); false
# (and logged) when beyond MAX_DEPTH.
func _prepare(stimulus: Stimulus, parent: Stimulus) -> bool:
	stimulus.source_label = stimulus.source_name()
	stimulus.scale = stimulus.source_scale()
	stimulus.intensity *= stimulus.scale
	stimulus.id = _next_id
	_next_id += 1
	var cause := parent if parent != null else _current
	stimulus.depth = cause.depth + 1 if cause != null else 0
	if stimulus.cause_id == 0 and cause != null:
		stimulus.cause_id = cause.id
	if stimulus.depth > MAX_DEPTH:
		var data := {"id": stimulus.id, "type": stimulus.type, "depth": stimulus.depth}
		EventLog.record(&"stimulus.dropped", stimulus.source_name(), "", data)
		return false
	return true


## Drops every queued stimulus (level change, quickload).
func clear() -> void:
	_queue.clear()


## The id the last emitted stimulus got (0: none yet). Saves record it (QuickSave).
func last_id() -> int:
	return _next_id - 1


## New stimuli get ids above `id` from now on (a loaded save whose components and mission tallies
## keep stimulus ids from the session it was saved in: a burning fire's ignition, a turret's
## command): an old id never names a new stimulus. Never lowers the next id.
func reserve_ids(id: int) -> void:
	_next_id = maxi(_next_id, id + 1)


func pending_count() -> int:
	return _queue.size()


func register(receiver: StimulusReceiver) -> void:
	if not _receivers.has(receiver):
		_receivers.append(receiver)


func unregister(receiver: StimulusReceiver) -> void:
	_receivers.erase(receiver)


func receivers() -> Array[StimulusReceiver]:
	return _receivers.duplicate()


## Dry run of a CONTACT stimulus: true when delivering it now would run at least one effect that
## can apply (StimulusReceiver.would_react()). Nothing is queued or logged. Other shapes: true.
## Lets a deliberate act be refused when it would do nothing (using a medkit when unhurt).
func would_affect(stimulus: Stimulus) -> bool:
	if stimulus.shape != Stimulus.Shape.CONTACT:
		return true
	if not is_instance_valid(stimulus.target):
		return false
	var data := {"distance": 0.0, "collider": stimulus.target}
	var perceived := stimulus.intensity * stimulus.source_scale()
	for receiver in _receivers_of(stimulus.target):
		if receiver.wants(stimulus) and receiver.would_react(stimulus, perceived, data):
			return true
	return false


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
		"cause_id": stimulus.cause_id,
	}
	if not stimulus.scale_attribute.is_empty():
		emitted["scale_attribute"] = stimulus.scale_attribute
		emitted["scale"] = stimulus.scale
	EventLog.record(&"stimulus.emitted", stimulus.source_name(), target, emitted)
	var paths: Array[PackedVector3Array] = []
	match stimulus.shape:
		Stimulus.Shape.RADIUS:
			_deliver_radius(stimulus, paths)
		Stimulus.Shape.CONTACT:
			if is_instance_valid(stimulus.target):
				_deliver_to_node(stimulus, stimulus.target, {"distance": 0.0, "collider": stimulus.target})
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
		if reach == null:
			continue
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
	var to := stimulus.origin + direction * stimulus.length
	var exclude: Array[RID] = stimulus.exclude.duplicate()
	if is_instance_valid(stimulus.source) and stimulus.source is CollisionObject3D:
		exclude.append((stimulus.source as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(stimulus.origin, to, stimulus.collision_mask, exclude)
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		paths.append(PackedVector3Array([query.from, query.to]))
		return
	var point: Vector3 = hit["position"]
	paths.append(PackedVector3Array([stimulus.origin, point]))
	var collider := hit["collider"] as Node
	var data := {
		"distance": stimulus.origin.distance_to(point),
		"collider": collider,
		"position": point,
		"normal": hit["normal"],
	}
	_deliver_to_node(stimulus, collider, data)


## Delivers to the receivers of `node`, or of its nearest ancestor that has receivers
## (a hitbox inside an entity delivers to the entity's receivers). `data` reaches the receivers'
## effects (EffectContext.data): `distance` and `collider` (the node actually touched or hit, so
## BodyParts can tell which hitbox), plus `position` and `normal` for rays.
func _deliver_to_node(stimulus: Stimulus, node: Node, data: Dictionary) -> void:
	for receiver in _receivers_of(node):
		if receiver.wants(stimulus):
			receiver.receive(stimulus, stimulus.intensity, data)


## The receivers of `node`, or of its nearest ancestor that has receivers; empty when none has.
func _receivers_of(node: Node) -> Array[StimulusReceiver]:
	while node != null:
		var owned: Array[StimulusReceiver] = _receivers.filter(
			func(receiver: StimulusReceiver) -> bool: return _deliverable(receiver) and receiver.entity == node
		)
		if not owned.is_empty():
			return owned
		node = node.get_parent()
	return []


func _deliverable(receiver: StimulusReceiver) -> bool:
	return is_instance_valid(receiver) and receiver.is_inside_tree()


## How far the stimulus travels to the receiver, or null when it cannot reach it (line of sight
## blocked by world geometry; a PATH whose navmesh path stops short behind walls both ways).
func _reach(stimulus: Stimulus, receiver: StimulusReceiver) -> Reach:
	var to := receiver.global_position
	var straight := PackedVector3Array([stimulus.origin, to])
	if stimulus.propagation == Stimulus.Propagation.STRAIGHT:
		return Reach.new(stimulus.origin.distance_to(to), straight, "straight")
	if stimulus.propagation == Stimulus.Propagation.LINE_OF_SIGHT:
		if not _line_of_sight(stimulus, receiver):
			return null
		return Reach.new(stimulus.origin.distance_to(to), straight, "line_of_sight")
	var map := receiver.get_world_3d().navigation_map
	var nav := PackedVector3Array()
	if NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty():
		nav = NavigationServer3D.map_get_path(map, stimulus.origin, to, true, PATH_NAVIGATION_LAYERS)
	if nav.is_empty():
		var fallback := stimulus.origin.distance_to(to) + _attenuation(straight)
		return Reach.new(fallback, straight, "straight_fallback")
	var points := _path_points(stimulus, receiver, map, nav)
	if points.is_empty():
		return null
	return Reach.new(StimulusPropagation.polyline_length(points) + _attenuation(points), points, "path")


## The polyline from the origin along the navmesh to the receiver, or empty when it cannot get there.
## A path from a navmesh island (a cabinet top) or to an unreachable listener stops short: its open
## ends are bridged in a straight line only through open air (_bridged()). Otherwise the way is
## searched from the listener back towards the source; when both are blocked it is not heard
## (ADR 0094).
func _path_points(
	stimulus: Stimulus, receiver: StimulusReceiver, map: RID, nav: PackedVector3Array
) -> PackedVector3Array:
	var to := receiver.global_position
	var space := receiver.get_world_3d().direct_space_state
	var exclude := _bodies_of(stimulus, receiver)
	var points := _bridged(space, stimulus.origin, nav, to, exclude)
	if not points.is_empty():
		return points
	var back := NavigationServer3D.map_get_path(map, to, stimulus.origin, true, PATH_NAVIGATION_LAYERS)
	if back.is_empty():
		return back
	points = _bridged(space, to, back, stimulus.origin, exclude)
	points.reverse()
	return points


## `from`, the navmesh path `nav` and `to` as one polyline, or empty when a gap at either end (the
## straight line between a point and the path) is longer than PATH_GAP_FREE and blocked by world
## geometry both straight and around one corner (_open_air()).
func _bridged(
	space: PhysicsDirectSpaceState3D, from: Vector3, nav: PackedVector3Array, to: Vector3, exclude: Array[RID]
) -> PackedVector3Array:
	if not _open_air(space, from, nav[0], exclude) or not _open_air(space, nav[nav.size() - 1], to, exclude):
		return PackedVector3Array()
	var points := PackedVector3Array([from])
	points.append_array(nav)
	points.append(to)
	return points


## True when sound crosses the gap from `a` to `b` through open air: the gap is at most
## PATH_GAP_FREE (a point beside its navmesh polygon), or, with both ends PATH_GAP_LIFT above the
## surfaces they rest on, the straight line or one of the two L-shaped routes (level first, or
## vertical first) between them hits no world geometry (over a cabinet's edge, off a table top).
func _open_air(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, exclude: Array[RID]) -> bool:
	if a.distance_to(b) <= PATH_GAP_FREE:
		return true
	var from := a + Vector3.UP * PATH_GAP_LIFT
	var to := b + Vector3.UP * PATH_GAP_LIFT
	if _segment_open(space, from, to, exclude):
		return true
	for corner: Vector3 in [Vector3(from.x, to.y, from.z), Vector3(to.x, from.y, to.z)]:
		if _segment_open(space, from, corner, exclude) and _segment_open(space, corner, to, exclude):
			return true
	return false


# True when the segment, less PATH_GAP_SKIN at each end, hits no world geometry: a noise made on a
# surface (a bullet's impact on a wall) is not blocked by that surface.
func _segment_open(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, exclude: Array[RID]) -> bool:
	var length := a.distance_to(b)
	if length <= 2.0 * PATH_GAP_SKIN:
		return true
	var step := (b - a) / length * PATH_GAP_SKIN
	return PhysicsLayers.segment_clear(space, a + step, b - step, PhysicsLayers.WORLD, exclude)


## The source's and the receiver entity's own bodies: they never block a stimulus aimed at them.
func _bodies_of(stimulus: Stimulus, receiver: StimulusReceiver) -> Array[RID]:
	var exclude: Array[RID] = []
	# The source is often freed by now (an exploded barrel): check before touching it.
	if is_instance_valid(stimulus.source) and stimulus.source is CollisionObject3D:
		exclude.append((stimulus.source as CollisionObject3D).get_rid())
	if is_instance_valid(receiver.entity) and receiver.entity is CollisionObject3D:
		exclude.append((receiver.entity as CollisionObject3D).get_rid())
	return exclude


## True when a ray from the origin to the receiver hits nothing on the world layer. The source's and
## the receiver entity's own bodies never block (a barricade on the world layer still gets the fire
## aimed at its centre); physics objects (layer 4) are not on the mask.
func _line_of_sight(stimulus: Stimulus, receiver: StimulusReceiver) -> bool:
	var exclude := _bodies_of(stimulus, receiver)
	var space := receiver.get_world_3d().direct_space_state
	return PhysicsLayers.segment_clear(space, stimulus.origin, receiver.global_position, PhysicsLayers.WORLD, exclude)


## Sum of extra_metres of every enabled SoundAttenuator the polyline passes through (each once).
func _attenuation(points: PackedVector3Array) -> float:
	var extra := 0.0
	for node in get_tree().get_nodes_in_group(SoundAttenuator.GROUP):
		var attenuator := node as SoundAttenuator
		if attenuator != null and attenuator.enabled and attenuator.crosses(points):
			extra += attenuator.extra_metres
	return extra
