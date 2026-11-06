class_name PlayerProbe
extends RefCounted
## Physics queries for the player: capsule clearance (uncrouch headroom, mantle path) and
## ledge detection. Results feed the pure MantleRules; no decisions are made here.

## Query capsules are this much slimmer than the body so touching walls does not count.
const SKIN: float = 0.02
## Query capsules start this far above the feet so the floor being stood on does not count.
const LIFT: float = 0.03
## How far past the ledge face the top ray samples the ledge surface.
const TOP_INSET: float = 0.1
## Extra distance past the capsule radius where a mantle ends, so the body is fully on top.
const END_INSET: float = 0.05
## Heights above the feet, as fractions of the max mantle height, where the ledge face is searched.
const WALL_RAY_FRACTIONS: Array[float] = [0.08, 0.45, 0.85]

var _body: CharacterBody3D
var _config: PlayerConfig


func _init(body: CharacterBody3D, config: PlayerConfig) -> void:
	_body = body
	_config = config


## True when a capsule of `height` standing at `feet` overlaps nothing.
func is_clear(feet: Vector3, height: float) -> bool:
	var params := _shape_query(feet, height)
	return _space().intersect_shape(params, 1).is_empty()


## True when a capsule of `height` can sweep from `from_feet` to `to_feet` without hitting anything.
func sweep_clear(from_feet: Vector3, to_feet: Vector3, height: float) -> bool:
	var params := _shape_query(from_feet, height)
	params.motion = to_feet - from_feet
	var fractions := _space().cast_motion(params)
	return fractions.is_empty() or fractions[0] >= 1.0


## Looks for a ledge in front of `feet` along horizontal `forward` and checks the mantle path.
## `ground_y` is the height of the ground the player last stood on.
func find_ledge(feet: Vector3, forward: Vector3, ground_y: float) -> MantleRules.Probe:
	var probe := MantleRules.Probe.new()
	var dir := Vector3(forward.x, 0.0, forward.z).normalized()
	if dir.is_zero_approx():
		return probe
	var wall_distance := _nearest_wall(feet, dir)
	if wall_distance < 0.0:
		return probe
	var top_xz := feet + dir * (wall_distance + TOP_INSET)
	var top_hit := _ray(
		top_xz + Vector3.UP * (_config.mantle_max_height + 0.1),
		Vector3(top_xz.x, feet.y + LIFT, top_xz.z),
	)
	if top_hit.is_empty() or not _is_floor_normal(top_hit["normal"]):
		return probe
	var top_y: float = (top_hit["position"] as Vector3).y
	probe.found = true
	probe.height = top_y - feet.y
	probe.rise = top_y - ground_y
	probe.distance = wall_distance
	probe.end_position = feet + dir * (wall_distance + _config.capsule_radius + END_INSET)
	probe.end_position.y = top_y
	if MantleRules.in_range(probe.height, probe.rise, probe.distance, _config):
		probe.standing_clear = _path_clear(feet, probe.end_position, _config.standing_height)
		probe.crouched_clear = probe.standing_clear or _path_clear(feet, probe.end_position, _config.crouched_height)
	return probe


# Rise straight up to the ledge top, slide over onto it, and fit there.
func _path_clear(feet: Vector3, end: Vector3, height: float) -> bool:
	var top := Vector3(feet.x, end.y, feet.z)
	return sweep_clear(feet, top, height) and sweep_clear(top, end, height) and is_clear(end, height)


# Horizontal distance to the nearest ledge face within mantle reach, or -1.
func _nearest_wall(feet: Vector3, dir: Vector3) -> float:
	var nearest := -1.0
	for fraction: float in WALL_RAY_FRACTIONS:
		var from := feet + Vector3.UP * (_config.mantle_max_height * fraction)
		var hit := _ray(from, from + dir * _config.mantle_reach)
		if hit.is_empty() or _is_floor_normal(hit["normal"]):
			continue
		var distance := from.distance_to(hit["position"])
		if nearest < 0.0 or distance < nearest:
			nearest = distance
	return nearest


func _is_floor_normal(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) <= deg_to_rad(_config.max_slope_deg)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, _body.collision_mask, [_body.get_rid()])
	params.hit_back_faces = false
	return _space().intersect_ray(params)


func _shape_query(feet: Vector3, height: float) -> PhysicsShapeQueryParameters3D:
	var shape := CapsuleShape3D.new()
	shape.radius = _config.capsule_radius - SKIN
	shape.height = maxf(height - SKIN, shape.radius * 2.0)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (LIFT + shape.height * 0.5))
	params.collision_mask = _body.collision_mask
	params.exclude = [_body.get_rid()]
	return params


func _space() -> PhysicsDirectSpaceState3D:
	return _body.get_world_3d().direct_space_state
