extends GdUnitTestSuite
## Scenario: fire spreads crate to crate by heat accumulation (ADR 0046).
## Fixture: wooden crates A, B, D in a row 0.62 m apart (centres), a metal crate touching A, and a
## wooden crate 1 m behind A on the far side of a wall (world layer).

const Wait := preload("res://tests/helpers/wait.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const FIXTURE := "res://tests/scenarios/fixtures/fire_spread.tscn"
const TICK := 1.0 / 60.0

var _runner: GdUnitSceneRunner


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func test_burning_crate_ignites_neighbour_not_metal_nor_behind_wall() -> void:
	var spark := await _ignite_crate_a()

	await _until_ignited("CrateB", 300)
	var a := _ignited("CrateA")
	var b := _ignited("CrateB")
	assert_int(a.data["by"]).is_equal(spark.id)
	assert_object(b).is_not_null()
	# 0.62 m: 2.0 x (1 - 0.62 / 1.5) = 1.17 per pulse, -0.25 cooling: 7th pulse, 3.0 s after A.
	assert_float((b.tick - a.tick) * TICK).is_between(2.5, 3.5)

	await Wait.frames(get_tree(), 480 - (b.tick - a.tick))
	assert_object(_ignited("MetalCrate")).is_null()
	assert_object(_ignited("CrateBehindWall")).is_null()
	assert_bool(_tags("MetalCrate").has(&"state.burning")).is_false()
	assert_float(Flammable.of(_runner.find_child("CrateBehindWall")).heat()).is_equal(0.0)
	# The metal crate perceives the fire (it is in range) but takes no fire damage.
	var to_metal := EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == "MetalCrate"
	)
	assert_array(to_metal).is_not_empty()
	assert_array(Objects.logged(&"object.damaged", "object", "MetalCrate")).is_empty()


func test_fire_chain_is_traceable_through_cause_id() -> void:
	var spark := await _ignite_crate_a()

	await _until_ignited("CrateD", 600)

	# From the last ignited object back to the spark: object.ignited.by -> the fire pulse that
	# crossed the threshold -> its source (the burning neighbour) and cause_id -> that neighbour's
	# object.ignited.by (the same id) ... -> a stimulus without a cause.
	var chain: Array[String] = []
	var entry := _ignited("CrateD")
	var root_id := 0
	while entry != null and chain.size() < 10:
		chain.append(entry.data["object"])
		var igniter := Objects.emitted(entry.data["by"])
		assert_object(igniter).is_not_null()
		if igniter.data["cause_id"] == 0:
			root_id = igniter.data["id"]
			break
		assert_str(igniter.data["type"]).is_equal("fire")
		assert_int(igniter.data["depth"]).is_equal(0)
		var previous := _ignited(igniter.source)
		assert_int(igniter.data["cause_id"]).is_equal(previous.data["by"])
		entry = previous
	assert_str(chain[0]).is_equal("CrateD")
	assert_str(chain[-1]).is_equal("CrateA")
	assert_int(chain.size()).is_between(2, 3)
	assert_int(root_id).is_equal(spark.id)


func _ignite_crate_a() -> Stimulus:
	_runner = scene_runner(FIXTURE)
	_runner.set_time_factor(6)
	await Wait.frames(get_tree(), 10)
	EventLog.clear()
	var spark := Stimulus.make_contact(&"fire", 100.0, _runner.find_child("CrateA"))
	StimulusSystem.emit(spark)
	await Wait.frames(get_tree(), 2)
	return spark


func _until_ignited(object: String, max_frames: int) -> void:
	for i in max_frames:
		if _ignited(object) != null:
			return
		await get_tree().physics_frame


func _ignited(object: String) -> EventLogEntry:
	var found := Objects.logged(&"object.ignited", "object", object)
	return found[0] if not found.is_empty() else null


func _tags(entity: String) -> TagContainer:
	return (_runner.find_child(entity).get_node("Tags") as Tags).container
