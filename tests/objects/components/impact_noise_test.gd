extends GdUnitTestSuite
## Integration: physics impacts make noise of the expected loudness and deal blunt damage.

const Wait := preload("res://tests/helpers/wait.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const FLOOR := "res://tests/objects/fixtures/object_floor.tscn"
const SETTINGS: ImpactSettings = preload("res://objects/components/impact_settings.tres")

var _floor: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_floor = auto_free(load(FLOOR).instantiate())
	add_child(_floor)
	# CSG collision is built a few frames after load.
	await Wait.frames(get_tree(), 5)


func test_dropped_crate_makes_noise_of_expected_loudness() -> void:
	# Bottom 2 m above the floor: hits at sqrt(2 g h) = 6.26 m/s (the step before contact ~6.2).
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 2.3, 0))
	await Wait.frames(get_tree(), 60)

	var impacts := Objects.logged(&"object.impact", "object", "SmallCrate")
	assert_array(impacts).is_not_empty()
	var speed: float = impacts[0].data["speed"]
	var expected := ImpactRules.loudness(speed, 10.0, 1.0, SETTINGS)
	assert_float(speed).is_between(5.8, 6.5)
	assert_float(impacts[0].data["loudness"]).is_equal_approx(expected, 0.0001)
	assert_str(impacts[0].data["other"]).is_equal("Floor")
	var noises := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise" and entry.source == "SmallCrate"
	)
	assert_float(noises[0].data["intensity"]).is_equal_approx(expected, 0.0001)
	var damaged := Objects.logged(&"object.damaged", "object", "SmallCrate")
	assert_float(damaged[0].data["amount"]).is_equal_approx(ImpactRules.damage(speed, 10.0, SETTINGS), 0.0001)
	assert_str(damaged[0].data["type"]).is_equal("damage.blunt")
	assert_bool(is_instance_valid(crate)).is_true()


func test_metal_impact_is_louder() -> void:
	Objects.spawn(_floor, Objects.METAL_CRATE, Vector3(0, 2.4, 0))
	await Wait.frames(get_tree(), 60)

	var impact: EventLogEntry = Objects.logged(&"object.impact", "object", "MetalCrate")[0]
	var speed: float = impact.data["speed"]
	assert_float(impact.data["loudness"]).is_equal_approx(ImpactRules.loudness(speed, 25.0, 1.4, SETTINGS), 0.0001)


func test_resting_object_is_silent() -> void:
	Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, 0))
	await Wait.frames(get_tree(), 30)

	assert_array(EventLog.find(&"object.impact")).is_empty()


func test_impacts_are_throttled() -> void:
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, 0))
	var impact := crate.get_node("ImpactNoise") as ImpactNoise
	impact.impact(5.0, null)
	await Wait.frames(get_tree(), 2)

	# A real hit right after a reported one is swallowed by the 0.15 s throttle.
	(crate as RigidBody3D).linear_velocity = Vector3(0, -6, 0)
	crate.global_position.y = 0.45
	await Wait.frames(get_tree(), 4)

	assert_array(EventLog.find(&"object.impact")).has_size(1)
