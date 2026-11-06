extends GdUnitTestSuite
## Scenario across the light and perception contract (ADR 0065, ADR 0067): a real LightExposure on
## a stand-in target drives the guard's sight as the vision model predicts. Built in code: a floor,
## one OmniLight3D (energy 3, range 10) at (-3, 2.5, -5) and a 3 m wall at x 0.5 (z -6..-4) that
## shadows the light from the right side without hiding that side from the guard. The guard stands
## at the origin facing -Z, no navmesh (it walks straight). Lit spot (-2.5, 0, -5): 5.6 m, 26.6°
## in focus; dark spot (2.5, 0, -5): the same distance and angle, in the wall's shadow.

const GUARD := "res://actors/guard/guard.tscn"
const PERCEPTION: PerceptionConfig = preload("res://actors/guard/guard_perception.tres")
const LIT_SPOT := Vector3(-2.5, 0, -5)
const DARK_SPOT := Vector3(2.5, 0, -5)

var _root: Node3D
var _guard: NavWalker
var _awareness: GradedAwareness


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_box(Vector3(0, -0.5, 0), Vector3(30, 1, 30))
	_box(Vector3(0.5, 1.5, -5), Vector3(0.4, 3, 2))
	var lamp := OmniLight3D.new()
	lamp.light_energy = 3.0
	lamp.omni_range = 10.0
	lamp.position = Vector3(-3, 2.5, -5)
	_root.add_child(lamp)
	_guard = load(GUARD).instantiate() as NavWalker
	_root.add_child(_guard)
	(_guard.get_node("Behaviour") as AwarenessBehaviour).route = null
	_awareness = GradedAwareness.of_node(_guard)


func after_test() -> void:
	StimulusSystem.clear()


func test_target_in_the_light_is_seen_as_predicted() -> void:
	var target := _target(LIT_SPOT)
	await _frames(12)
	var level := LightExposure.of(target).level
	assert_float(level).is_greater(0.5)
	var angle := VisionRules.angle_off(Vector3.FORWARD, Vector3(0, 1.6, 0), LIT_SPOT)
	var distance := VisionRules.flat_distance(Vector3.ZERO, LIT_SPOT)
	var predicted := VisionRules.gain(angle, distance, level, false, false, PERCEPTION)
	assert_float(predicted).is_greater(1.0)

	var alerted_after := -1.0
	for tick in 180:
		await _frames(1)
		if _awareness.state() == AwarenessModel.State.ALERTED:
			alerted_after = (tick + 1) / 60.0
			break
	# 1 / gain seconds of sight (about 0.8 s), give or take the light's 0.1 s update.
	assert_float(alerted_after).is_between(1.0 / predicted - 0.15, 1.0 / predicted + 0.15)
	assert_float(PerceptionSensor.light_level_of(target)).is_equal(level)


func test_target_in_the_walls_shadow_is_never_seen() -> void:
	var target := _target(DARK_SPOT)
	await _frames(12)
	var level := LightExposure.of(target).level
	assert_float(level).is_less(0.1)
	# The guard has a clear view of it: only the light keeps it hidden.
	var sensor := PerceptionSensor.of(_guard)
	assert_bool(sensor.has_line_of_sight(sensor.eye_position(), target)).is_true()

	await _frames(300)

	assert_int(_awareness.state()).is_equal(AwarenessModel.State.UNAWARE)
	assert_float(_awareness.model.meter).is_equal(0.0)


func test_the_guard_itself_has_a_light_level() -> void:
	await _frames(12)
	assert_object(LightExposure.of(_guard)).is_not_null()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# A static 1.8 m capsule tagged `actor.player` with a real LightExposure.
func _target(feet: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Target"
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	var tags := Tags.new()
	tags.name = "Tags"
	tags.initial_tags = [&"actor.player"]
	body.add_child(tags)
	var light := LightExposure.new()
	light.name = "LightExposure"
	body.add_child(light)
	body.position = feet
	_root.add_child(body)
	return body


func _box(centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	_root.add_child(body)
