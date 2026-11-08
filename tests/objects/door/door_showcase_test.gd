extends GdUnitTestSuite
## Integration (ADR 0078): the door showcase (tests/objects/fixtures/showcase/door_showcase.tscn):
## one door per lock type, the locked ones saying what opens them, no coplanar faces of different
## materials, and the breaker on the electronic door's circuit unlocking it (fail-safe) when switched
## off: CircuitBreaker -> Powered -> ElectronicLock -> Lockable.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SHOWCASE := "res://tests/objects/fixtures/showcase/door_showcase.tscn"

var _scene: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_scene = auto_free(load(SHOWCASE).instantiate())
	# Far from the origin: its navmesh, if freed late, never joins another suite's.
	_scene.position = Vector3(-200, 0, 400)
	add_child(_scene)
	for i in 5:
		await get_tree().physics_frame


func test_each_door_says_what_opens_it() -> void:
	var expected: Dictionary[String, String] = {
		"DoorPlain": "E: open",
		"DoorKeypad": "Locked: keypad",
		"DoorMechanical": "Locked: lockpick",
		"DoorKeycard": "Locked: keycard",
		"DoorElectronic": "Locked: electronic",
		"DoorBreakable": "Locked",
	}
	for door_name: String in expected:
		var door := Door.of(_scene.get_node(door_name))
		assert_str(door.prompt(null)).override_failure_message(door_name).is_equal(expected[door_name])


func test_no_coplanar_faces_of_different_materials() -> void:
	assert_array(KitGeometry.coplanar_material_overlaps(_scene)).is_empty()


func test_breaker_off_unlocks_the_fail_safe_door() -> void:
	var breaker := _scene.get_node("Breaker/CircuitBreaker") as CircuitBreaker
	var door := Door.of(_scene.get_node("DoorElectronic"))
	assert_bool(door.is_locked()).is_true()

	breaker.set_closed(false)

	assert_bool(door.is_locked()).is_false()
	assert_bool(door.is_open()).is_false()
	# The other locked doors do not care.
	assert_bool(Door.of(_scene.get_node("DoorKeycard")).is_locked()).is_true()
