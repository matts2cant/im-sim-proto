extends GdUnitTestSuite
## Integration: PerceptionSensor.look_for_bodies() (ADR 0071) on minimal entities built in code: a
## watcher tagged `actor.guard` (facing -Z, eyes 1.6 m up) and static capsules lying flat (as
## DownedPose lays a character down). A body is an ally (`actor.guard`) with `state.unconscious` or
## `state.dead`; the same cones, light and line of sight as for targets, measured to its middle.

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const CONFIG: PerceptionConfig = preload("res://actors/guard/guard_perception.tres")

var _root: Node3D
var _sensor: PerceptionSensor


func before_test() -> void:
	_root = auto_free(Node3D.new())
	add_child(_root)
	var watcher := Node3D.new()
	watcher.name = "Watcher"
	var tags := Tags.new()
	tags.name = "Tags"
	tags.initial_tags = [&"actor.guard"]
	watcher.add_child(tags)
	_sensor = PerceptionSensor.new()
	_sensor.config = CONFIG
	watcher.add_child(_sensor)
	_root.add_child(watcher)


func test_sees_downed_allies_only() -> void:
	var unconscious := _lying(Vector3(0, 0, -4), [&"actor.guard", &"state.unconscious"])
	var dead := _lying(Vector3(2, 0, -6), [&"actor.guard", &"state.dead"])
	_lying(Vector3(-2, 0, -6), [&"actor.guard"])
	_lying(Vector3(-1, 0, -5), [&"actor.player", &"state.unconscious"])
	await Wait.frames(get_tree(), 2)

	var seen := _sensor.look_for_bodies()
	var targets := seen.map(func(sighting: PerceptionSensor.Sighting) -> Node3D: return sighting.target)
	assert_int(targets.size()).is_equal(2)
	assert_bool(targets.has(unconscious)).is_true()
	assert_bool(targets.has(dead)).is_true()
	# Lit (no LightExposure), 4 m to its middle, in focus: 1.25 per second.
	for sighting in seen:
		if sighting.target == unconscious:
			assert_float(sighting.gain).is_equal_approx(1.25, 0.0001)
			assert_float(sighting.distance).is_equal_approx(4.0, 0.0001)


func test_a_dark_body_is_seen_only_within_2_m() -> void:
	var body := _lying(Vector3(0, 0, -4), [&"actor.guard", &"state.unconscious"])
	var exposure := LightExposure.new()
	body.add_child(exposure)
	await Wait.frames(get_tree(), 2)
	exposure.set_physics_process(false)
	exposure.level = 0.04
	assert_array(_sensor.look_for_bodies()).is_empty()
	body.position = Vector3(0, 0, -1.5)
	await Wait.frames(get_tree(), 2)
	assert_array(_sensor.look_for_bodies()).has_size(1)


func test_a_body_behind_a_low_wall_is_hidden_and_sight_aims_at_its_height() -> void:
	var body := _lying(Vector3(0, 0, -6), [&"actor.guard", &"state.dead"])
	# A flat capsule is only 0.7 m high: the sight points stay below 0.7 m.
	for point in PerceptionSensor.target_points(body):
		assert_float(point.y).is_between(0.0, 0.7)
	_wall(Vector3(0, 0.6, -4), Vector3(3, 1.2, 0.2))
	await Wait.frames(get_tree(), 3)
	assert_array(_sensor.look_for_bodies()).is_empty()


# A static capsule lying flat along X (0.35 m radius, 1.8 m long), its middle at `middle` on the
# floor (0.35 m up), with Tags.
func _lying(middle: Vector3, tags: Array[StringName]) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.35, 0))
	body.add_child(shape)
	var tag_node := Tags.new()
	tag_node.name = "Tags"
	tag_node.initial_tags = tags
	body.add_child(tag_node)
	body.position = middle
	_root.add_child(body)
	return body


func _wall(centre: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = centre
	_root.add_child(wall)
