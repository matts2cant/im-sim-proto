class_name AwarenessBehaviour
extends Node
## Component: carries out what the character's GradedAwareness (sibling) wants with its NavWalker
## (the parent), ADR 0068. Routine (Unaware): follow `patrol_route` (a PatrolRoute, looped, waiting
## at each point), or without one hold the post (where it spawned, facing its spawn direction) and
## glance `glance_angle` left or right every `glance_interval`. LOOK: stop and face the point.
## MOVE: walk to the destination (snapped to the navmesh) at the phase's pace and report arrival.
## LOOK_AROUND: stop and sweep the view. CHASE: run to the last known position; within
## `face_distance` of a seen target, stop and face it (attacks: next wave). A character that cannot
## act stops. Paces map to the walker's speeds (walk, investigate, run). Saveable (patrol index,
## wait, post).

## Period (s) of the look-around sweep.
const SWEEP_PERIOD: float = 4.0

@export var patrol_route: NodePath

var body: NavWalker
var awareness: GradedAwareness
var route: PatrolRoute
var patrol_index: int = 0
## Seconds left waiting at the current patrol point (0: walking).
var patrol_wait: float = 0.0
## Where it holds its post without a route, and the post's facing (yaw).
var post: Vector3 = Vector3.ZERO
var post_yaw: float = 0.0

var _glance_time: float = 0.0
var _phase: int = -1
var _sweep_yaw: float = 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	body = get_parent() as NavWalker
	if body == null:
		push_warning("AwarenessBehaviour %s: the parent is not a NavWalker" % get_path())
		set_physics_process(false)
		return
	awareness = GradedAwareness.of_node(body)
	if not patrol_route.is_empty():
		route = get_node_or_null(patrol_route) as PatrolRoute
	post = body.global_position
	post_yaw = body.rotation.y


func _physics_process(delta: float) -> void:
	if awareness == null or not ActorState.can_act(body):
		body.stop()
		return
	var model := awareness.model
	if model.phase != _phase:
		_phase = model.phase
		_sweep_yaw = body.rotation.y
	match model.phase:
		AwarenessModel.Phase.ROUTINE:
			_routine(delta)
		AwarenessModel.Phase.LOOK:
			body.stop()
			body.face_towards(model.point)
		AwarenessModel.Phase.MOVE:
			if _go(model.destination, _pace_speed(model.pace)):
				model.arrived()
		AwarenessModel.Phase.LOOK_AROUND:
			body.stop()
			var swing := deg_to_rad(awareness.config.look_around_angle) * sin(model.phase_time * TAU / SWEEP_PERIOD)
			body.face_direction(_yaw_direction(_sweep_yaw + swing))
		AwarenessModel.Phase.CHASE:
			_chase(model)


## Speed (m/s) of an AwarenessModel pace.
func _pace_speed(pace: AwarenessModel.Pace) -> float:
	match pace:
		AwarenessModel.Pace.RUN:
			return body.config.run_speed
		AwarenessModel.Pace.INVESTIGATE:
			return body.config.investigate_speed
	return body.config.walk_speed


func _chase(model: AwarenessModel) -> void:
	# Stops early enough to come to rest at face_distance, not run into the target.
	var reach := awareness.config.face_distance + body.braking_distance()
	var near := model.target_seen and VisionRules.flat_distance(body.global_position, model.target_position) <= reach
	if near:
		body.stop()
		body.face_towards(model.target_position)
		return
	_go(model.destination, body.config.run_speed)


func _routine(delta: float) -> void:
	if route != null and route.size() > 0:
		_patrol(delta)
		return
	if VisionRules.flat_distance(body.global_position, post) > body.config.arrive_distance + 0.1:
		_go(post, body.config.walk_speed)
		return
	body.stop()
	_glance_time += delta
	var interval := maxf(awareness.config.glance_interval, 0.1)
	var cycle := int(_glance_time / interval)
	var into := fmod(_glance_time, interval)
	var yaw := post_yaw
	if into >= interval - awareness.config.glance_hold:
		var side := 1.0 if cycle % 2 == 0 else -1.0
		yaw += deg_to_rad(awareness.config.glance_angle) * side
	body.face_direction(_yaw_direction(yaw))


func _patrol(delta: float) -> void:
	if patrol_wait > 0.0:
		body.stop()
		patrol_wait -= delta
		if patrol_wait <= 0.0:
			patrol_wait = 0.0
			patrol_index = posmod(patrol_index + 1, route.size())
		return
	if _go(route.point(patrol_index), body.config.walk_speed):
		patrol_wait = maxf(route.wait_at(patrol_index, awareness.config.patrol_wait), 0.001)


# Walks to `point` (snapped to the navmesh); true once there.
func _go(point: Vector3, speed: float) -> bool:
	body.move_to(_on_navmesh(point), speed)
	return body.is_arrived()


func _on_navmesh(point: Vector3) -> Vector3:
	var map := body.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_regions(map).is_empty():
		return point
	# A map without polygons yet (a region still being synced) answers the origin: keep the point.
	if not NavigationServer3D.map_get_closest_point_owner(map, point).is_valid():
		return point
	return NavigationServer3D.map_get_closest_point(map, point)


static func _yaw_direction(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func save_state() -> Dictionary:
	return {"patrol_index": patrol_index, "patrol_wait": patrol_wait, "post": post, "post_yaw": post_yaw}


func load_state(data: Dictionary) -> void:
	patrol_index = int(data.get("patrol_index", patrol_index))
	patrol_wait = float(data.get("patrol_wait", patrol_wait))
	post = data.get("post", post)
	post_yaw = float(data.get("post_yaw", post_yaw))
	_phase = -1
