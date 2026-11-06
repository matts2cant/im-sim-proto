extends GdUnitTestSuite
## Integration: PerceptionSensor (ADR 0067) on minimal entities built in code: a watcher (a Node3D
## with Tags and a sensor, facing -Z, eyes 1.6 m up) and a target that is not the player, only a
## static capsule (1.8 m, on the actors layer) carrying the tag `actor.player`: the rule is about the
## tag. Walls (world) and props (objects) block the sight rays; light comes from the target's
## LightExposure, frozen at a set level here (the light model itself: guard_light_test.gd).

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const CONFIG: PerceptionConfig = preload("res://actors/guard/guard_perception.tres")

var _root: Node3D
var _watcher: Node3D
var _sensor: PerceptionSensor


func before_test() -> void:
	_root = auto_free(Node3D.new())
	add_child(_root)
	_watcher = Node3D.new()
	_watcher.name = "Watcher"
	var tags := Tags.new()
	tags.name = "Tags"
	tags.initial_tags = [&"actor.guard"]
	_watcher.add_child(tags)
	_sensor = PerceptionSensor.new()
	_sensor.config = CONFIG
	_watcher.add_child(_sensor)
	_root.add_child(_watcher)


func test_sees_a_lit_tagged_entity_in_focus() -> void:
	var target := _target(Vector3(0, 0, -4), [&"actor.player"])
	await _frames(2)

	var seen := _sensor.look()

	assert_object(seen).is_not_null()
	assert_object(seen.target).is_same(target)
	assert_float(seen.gain).is_equal_approx(1.25, 0.0001)
	assert_float(seen.distance).is_equal_approx(4.0, 0.0001)


func test_ignores_entities_without_a_hostile_tag() -> void:
	_target(Vector3(0, 0, -4), [&"actor.dummy"])
	_target(Vector3(1, 0, -4), [&"actor.guard"])
	await _frames(2)

	assert_object(_sensor.look()).is_null()


func test_cloaked_entity_is_not_seen() -> void:
	_target(Vector3(0, 0, -4), [&"actor.player", &"state.cloaked"])
	await _frames(2)

	assert_object(_sensor.look()).is_null()


func test_behind_is_not_seen() -> void:
	_target(Vector3(1.5, 0, 2.6), [&"actor.player"])
	await _frames(2)

	assert_object(_sensor.look()).is_null()


func test_a_wall_blocks_the_view() -> void:
	_target(Vector3(0, 0, -6), [&"actor.player"])
	_box(Vector3(0, 1.5, -3), Vector3(4, 3, 0.2), PhysicsLayers.WORLD)
	await _frames(3)

	assert_object(_sensor.look()).is_null()


func test_a_prop_hides_what_is_behind_it_up_to_its_top() -> void:
	# A 1.2 m crate 1 m in front of the target: the standing target's head (1.62 m) shows over it,
	# a 0.95 m (crouched) one does not.
	var target := _target(Vector3(0, 0, -6), [&"actor.player"])
	_box(Vector3(0, 0.6, -5), Vector3(1.2, 1.2, 1.2), PhysicsLayers.OBJECTS)
	await _frames(3)
	assert_object(_sensor.look()).is_not_null()

	var collision := target.get_node("Collision") as CollisionShape3D
	(collision.shape as CapsuleShape3D).height = 0.95
	collision.position.y = 0.475
	await _frames(2)

	assert_object(_sensor.look()).is_null()


func test_light_level_scales_the_gain() -> void:
	var target := _target(Vector3(0, 0, -4), [&"actor.player"])
	var light := _light(target, 0.25)
	await _frames(2)
	assert_float(_sensor.look().gain).is_equal_approx(0.46875, 0.0001)

	light.level = 0.05
	assert_object(_sensor.look()).is_null()


func test_light_level_of_reads_the_light_exposure() -> void:
	var target := _target(Vector3(0, 0, -4), [&"actor.player"])
	assert_float(PerceptionSensor.light_level_of(target)).is_equal(1.0)
	_light(target, 0.3)
	assert_float(PerceptionSensor.light_level_of(target)).is_equal_approx(0.3, 0.0001)


func test_crouch_tag_and_wariness_change_the_gain() -> void:
	var target := _target(Vector3(0, 0, -8), [&"actor.player"])
	_light(target, 0.25)
	await _frames(2)
	var plain := _sensor.look().gain
	(target.get_node("Tags") as Tags).add(&"stance.crouch")
	assert_float(_sensor.look().gain).is_equal_approx(plain * 0.7, 0.0001)
	assert_float(_sensor.look(true).gain).is_equal_approx(plain * 0.7 * 1.5, 0.0001)


func test_picks_the_target_seen_best() -> void:
	_target(Vector3(0, 0, -15), [&"actor.player"])
	var near := _target(Vector3(1, 0, -4), [&"actor.player"])
	await _frames(2)

	assert_object(_sensor.look().target).is_same(near)


func test_a_watcher_that_cannot_act_sees_nothing() -> void:
	_target(Vector3(0, 0, -4), [&"actor.player"])
	(_watcher.get_node("Tags") as Tags).add(ActorState.UNCONSCIOUS)
	await _frames(2)

	assert_object(_sensor.look()).is_null()


func test_hostile_and_ally_follow_the_tags() -> void:
	var player := _target(Vector3(0, 0, -4), [&"actor.player"])
	var guard := _target(Vector3(2, 0, -4), [&"actor.guard"])
	assert_bool(_sensor.is_hostile(player)).is_true()
	assert_bool(_sensor.is_ally(player)).is_false()
	assert_bool(_sensor.is_ally(guard)).is_true()
	assert_bool(_sensor.is_hostile(guard)).is_false()


func _frames(count: int) -> void:
	await Fixtures.frames(get_tree(), count)


# A static 1.8 m capsule (feet at `feet`, actors layer) with Tags.
func _target(feet: Vector3, tags: Array[StringName]) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Target"
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	var tag_node := Tags.new()
	tag_node.name = "Tags"
	tag_node.initial_tags = tags
	body.add_child(tag_node)
	body.position = feet
	_root.add_child(body)
	return body


func _box(centre: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	_root.add_child(body)
	return body


# A LightExposure that keeps `level` (not updated from the lights).
func _light(target: Node, level: float) -> LightExposure:
	var light := LightExposure.new()
	light.name = "LightExposure"
	target.add_child(light)
	light.process_mode = Node.PROCESS_MODE_DISABLED
	light.level = level
	return light
