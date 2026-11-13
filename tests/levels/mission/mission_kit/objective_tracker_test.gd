extends GdUnitTestSuite
## ObjectiveTracker and the objective kinds (ADR 0087), pure: each completes from what the world
## says (a stand-in ObjectiveContext) or from an EventLog entry, once; main objectives gate
## extraction, optional ones are counted; saved as the ids done.


class FakeWorld:
	extends ObjectiveContext
	var entries: Array[StringName] = []
	var sabotaged_tags: Array[StringName] = []
	var player_tag: StringName = &"actor.player"

	func has_log_entry(entry_id: StringName) -> bool:
		return entries.has(entry_id)

	func is_player(entity: Node) -> bool:
		return ActorState.has(entity, player_tag)

	func sabotaged(tag: StringName) -> bool:
		return sabotaged_tags.has(tag)


const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _world: FakeWorld
var _tracker: ObjectiveTracker
var _player: Node3D
var _guard: Node3D


func before_test() -> void:
	_world = FakeWorld.new()
	_player = auto_free(Fixtures.entity(self, "Hero", Vector3(0, -50, 0), [], [&"actor.player"])) as Node3D
	_guard = auto_free(Fixtures.entity(self, "Player", Vector3(0, -50, 0), [], [&"actor.guard"])) as Node3D
	var read := ReadEntryObjective.new()
	read.id = &"manifest"
	read.title = "Read the manifest"
	read.entry_id = &"site.manifest"
	read.extraction_hint = "Read the manifest first"
	var take := PickUpObjective.new()
	take.id = &"prototype"
	take.title = "Take the prototype"
	take.item_id = &"prototype"
	take.optional = true
	var burn := SabotageObjective.new()
	burn.id = &"shipment"
	burn.title = "Sabotage the shipment"
	burn.tag = &"mission.shipment"
	burn.optional = true
	var objectives: Array[MissionObjective] = [take, read, burn]
	_tracker = ObjectiveTracker.new(objectives)


# An `item.picked_up` entry as the inventory records it (the picker as an entity).
func _picked(source: Node, item: String) -> EventLogEntry:
	var data := {"item": item, "count": 1, "left": 0}
	return EventLogEntry.make(0, EventKinds.ITEM_PICKED_UP, source, "Pickup", data)


func test_reading_the_entry_completes_the_main_objective_once() -> void:
	assert_array(_tracker.update(_world)).is_empty()
	assert_bool(_tracker.main_done()).is_false()

	_world.entries.append(&"site.manifest")
	var first := _tracker.update(_world)
	var second := _tracker.update(_world)

	assert_int(first.size()).is_equal(1)
	assert_str(String(first[0].id)).is_equal("manifest")
	assert_array(second).is_empty()
	assert_bool(_tracker.main_done()).is_true()


func test_picking_up_the_item_counts_only_for_the_player() -> void:
	# The untagged one is named "Player": names never count.
	assert_array(_tracker.observe(_picked(_guard, "prototype"), _world)).is_empty()
	assert_array(_tracker.observe(_picked(_player, "keycard"), _world)).is_empty()

	var done := _tracker.observe(_picked(_player, "prototype"), _world)

	assert_int(done.size()).is_equal(1)
	assert_bool(_tracker.is_done(&"prototype")).is_true()
	assert_int(_tracker.optional_done()).is_equal(1)
	assert_bool(_tracker.main_done()).is_false()


func test_sabotage_completes_from_the_world_state() -> void:
	_world.sabotaged_tags.append(&"mission.shipment")

	var done := _tracker.update(_world)

	assert_int(done.size()).is_equal(1)
	assert_str(String(done[0].id)).is_equal("shipment")
	assert_int(_tracker.optional_done()).is_equal(1)
	assert_int(_tracker.optional_total()).is_equal(2)


func test_first_missing_names_the_main_objective_and_its_hint() -> void:
	var missing := _tracker.first_missing()

	assert_str(String(missing.id)).is_equal("manifest")
	var data := MissionData.new()
	assert_str(MissionRules.extraction_hint(data, missing)).is_equal("Read the manifest first")
	missing.extraction_hint = ""
	assert_str(MissionRules.extraction_hint(data, missing)).is_equal(data.extraction_hint)


func test_round_trip_keeps_what_is_done() -> void:
	_world.entries.append(&"site.manifest")
	_tracker.update(_world)
	_tracker.observe(_picked(_player, "prototype"), _world)
	var loaded := ObjectiveTracker.new(_tracker.objectives)

	loaded.from_dict(_tracker.to_dict())

	assert_bool(loaded.main_done()).is_true()
	assert_int(loaded.optional_done()).is_equal(1)
	# Already done: not reported again.
	assert_array(loaded.update(_world)).is_empty()


func test_rules_texts() -> void:
	assert_str(MissionRules.time_text(754.9)).is_equal("12:34")
	assert_str(MissionRules.time_text(5.0)).is_equal("0:05")
	var lines := MissionRules.objective_lines(_tracker.objectives)
	assert_array(Array(lines)).is_equal(
		["Objective: Read the manifest", "Optional: Take the prototype", "Optional: Sabotage the shipment"]
	)
	assert_str(MissionRules.complete_text(_tracker.objectives[0])).is_equal("Optional complete: Take the prototype")
	var results := {"time": 61.0, "alarms": 1, "kills": 0, "knockouts": 2, "optional_done": 1, "optional_total": 2}
	results["ghost"] = false
	results["pacifist"] = true
	var rows := MissionRules.summary_rows(results)
	assert_array(Array(rows[0])).is_equal(["Time", "1:01"])
	assert_array(Array(rows[4])).is_equal(["Optional objectives", "1 / 2"])
	assert_array(Array(MissionRules.badges(results))).is_equal(["Pacifist"])
