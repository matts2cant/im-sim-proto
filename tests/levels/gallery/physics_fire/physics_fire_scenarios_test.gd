extends GdUnitTestSuite
## Scenarios in the real physics and fire room scene (stations A and C, the side room crate),
## asserted on the EventLog. Time factor only speeds up the run: physics keeps its 1/60 s step.

const Wait := preload("res://tests/helpers/wait.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://levels/gallery/physics_fire/physics_fire_room.tscn"
const TICK := 1.0 / 60.0
const ROW: Array[String] = ["FireCrate1", "FireCrate2", "FireCrate3", "FireCrate4", "FireCrate5"]
const NEVER: Array[String] = ["FireCrate6", "FireCrate7", "FireCrateBehindWall"]

var _runner: GdUnitSceneRunner
var _capacity: int = 0


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	# A 45 s fire logs far more than the default 2000 entries.
	_capacity = EventLog.capacity
	EventLog.capacity = 200000


func after_test() -> void:
	EventLog.clear()
	EventLog.capacity = _capacity


func test_fire_row_burns_up_to_the_metal_crate_and_no_further() -> void:
	await _load()
	var never_heat := {}
	for name: String in NEVER:
		never_heat[name] = 0.0
	var spark := Stimulus.make_contact(&"fire", 100.0, _runner.find_child("FireCrate1"))

	StimulusSystem.emit(spark)
	# 45 s simulated: the row takes about 20 s, the last crate burns out at about 40 s.
	for i in 45 * 60:
		await get_tree().physics_frame
		for name: String in NEVER:
			never_heat[name] = maxf(never_heat[name], Flammable.of(_runner.find_child(name)).heat())

	var previous: EventLogEntry = null
	for name: String in ROW:
		var ignited := Objects.logged(&"object.ignited", "object", name)
		assert_array(ignited).override_failure_message(name + " never ignited").has_size(1)
		if previous != null:
			# 0.9 m centres: 2.0 x (1 - 0.9 / 1.5) = 0.8 per pulse, -0.25 cooling: about 5 s.
			var step := (ignited[0].tick - previous.tick) * TICK
			assert_float(step).override_failure_message("%s after %.2f s" % [name, step]).is_between(3.5, 7.0)
		previous = ignited[0]
	for name: String in NEVER + ["FireMetalCrate"]:
		assert_array(Objects.logged(&"object.ignited", "object", name)).override_failure_message(name).is_empty()
	# 2.6 m from the last burning crate and walled off: no heat ever arrives.
	for name: String in NEVER:
		assert_float(never_heat[name]).override_failure_message(name).is_equal(0.0)
	assert_array(Objects.logged(&"object.damaged", "object", "FireMetalCrate")).is_empty()
	assert_array(Objects.logged(&"object.burnt_out", "object", "FireCrate5")).has_size(1)
	assert_int(Objects.logged(&"object.ignited", "object", "FireCrate1")[0].data["by"]).is_equal(spark.id)


func test_damaged_barrel_chains_into_the_second_and_lights_the_stack() -> void:
	await _load()
	var spark := Stimulus.make_contact(&"damage.blunt", 60.0, _runner.find_child("Barrel1"))

	StimulusSystem.emit(spark)
	await Wait.frames(get_tree(), 6 * 60)

	var first := Objects.logged(&"object.exploded", "object", "Barrel1")
	assert_array(first).has_size(1)
	assert_int(first[0].data["by"]).is_equal(spark.id)
	var second := Objects.logged(&"object.exploded", "object", "Barrel2")
	assert_array(second).has_size(1)
	assert_int(second[0].tick).is_equal(first[0].tick + 1)
	# Barrel 1's fire burst lights the two lower crates on the next tick (1.8 m: 8.0 >= 6). The top
	# crate (2.08 m: 6.1 >= 6) is on the edge: since the blast push became a `force.blast` stimulus
	# delivered on the same tick as the fire burst (ADR 0057) it catches at once too; before, the
	# push landed a tick earlier and moved it just out of reach. Either way it burns within 6 s.
	for name: String in ["StackCrate1", "StackCrate2"]:
		var ignited := Objects.logged(&"object.ignited", "object", name)
		assert_array(ignited).override_failure_message(name).has_size(1)
		assert_int(ignited[0].tick).override_failure_message(name).is_equal(first[0].tick + 1)
		assert_str(Objects.emitted(ignited[0].data["by"]).source).is_equal("Barrel1")
	var top := Objects.logged(&"object.ignited", "object", "StackCrate3")
	assert_array(top).has_size(1)
	assert_float((top[0].tick - first[0].tick) * TICK).is_less(6.0)
	# Nothing outside the alley is touched by either blast.
	for entry: EventLogEntry in EventLog.find(&"object.damaged") + EventLog.find(&"object.ignited"):
		var object: String = entry.data["object"]
		(
			assert_bool(object.begins_with("Stack") or object.begins_with("Barrel"))
			. override_failure_message(object)
			. is_true()
		)
	# The blown-off burning crates land out of reach of the fire row (station A).
	for name: String in ["StackCrate1", "StackCrate2", "StackCrate3"]:
		var crate := _runner.find_child(name) as Node3D
		if crate == null:
			continue
		for row_crate: String in ["FireCrate5", "FireCrate6", "FireCrate7"]:
			var distance := crate.global_position.distance_to((_runner.find_child(row_crate) as Node3D).global_position)
			assert_float(distance).override_failure_message("%s near %s" % [name, row_crate]).is_greater(1.6)


func test_side_room_crate_breaks_into_two_bottles() -> void:
	await _load()
	var crate := _runner.find_child("SideRoomCrate") as Node3D
	var centre := crate.global_position

	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 100.0, crate))
	await Wait.frames(get_tree(), 90)

	var broken := Objects.logged(&"object.broken", "object", "SideRoomCrate")
	assert_array(broken).has_size(1)
	var spawned: Array = broken[0].data["contents"]
	assert_int(spawned.size()).is_equal(2)
	var bottles := _runner.scene().find_children("GlassBottle*", "RigidBody3D", true, false)
	assert_int(bottles.size()).is_equal(2)
	for bottle: Node in bottles:
		# Still whole, resting on the floor where the crate was.
		var position := (bottle as Node3D).global_position
		assert_float(position.y).is_less(0.3)
		assert_float(Vector2(position.x - centre.x, position.z - centre.z).length()).is_less(1.0)
	assert_array(Objects.logged(&"object.broken", "reason", &"impact")).is_empty()


func _load() -> void:
	_runner = scene_runner(ROOM)
	_runner.set_time_factor(8)
	await Wait.frames(get_tree(), 10)
	EventLog.clear()
