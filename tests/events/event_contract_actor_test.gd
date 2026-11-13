extends GdUnitTestSuite
## Contract (ADR 0136): the EventLog kinds gameplay consumers read (MissionTally, HitMarkerRules,
## the Mission) are recorded by the real emitters with the entities and data keys EventKinds
## documents. Characters, stimuli, alarms and awareness here; objects, devices and power in
## event_contract_object_test.gd. Each test drives the component itself on a minimal entity and
## reads the entry as consumers do (EventLog.entry_added, EventLogEntry.entity()).

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const ALARM: PackedScene = preload("res://objects/alarm/alarm_controller.tscn")
const GUARD_AWARENESS: AwarenessConfig = preload("res://actors/guard/guard_awareness.tres")
const ORIGIN := Vector3(920, 0, -920)

var _root: Node3D
var _seen: Array[EventLogEntry] = []


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_seen.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	EventLog.entry_added.connect(_on_entry)


func after_test() -> void:
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)
	StimulusSystem.clear()


func _on_entry(entry: EventLogEntry) -> void:
	_seen.append(entry)


func _last(kind: StringName) -> EventLogEntry:
	for i in range(_seen.size() - 1, -1, -1):
		if _seen[i].kind == kind:
			return _seen[i]
	return null


func _character(character_name: String, offset: Vector3) -> CharacterBody3D:
	var body := Characters.character(_root, character_name, ORIGIN + offset, [] as Array[StringName])
	Characters.floor_box(_root, 0.0).position = ORIGIN + offset
	return body


func test_stimulus_emitted_names_its_source_and_target_entities() -> void:
	var source := Fixtures.entity(_root, "Source", ORIGIN, [])
	var target := Fixtures.entity(_root, "Target", ORIGIN + Vector3(1, 0, 0), [])
	var parent := Stimulus.make_contact(&"damage.ballistic", 5.0, target, source)
	StimulusSystem.emit(parent)
	var child := Stimulus.make_contact(&"damage.fire", 5.0, target, null)
	StimulusSystem.emit(child, parent)
	await Wait.frames(get_tree(), 2)

	var entries := _seen.filter(func(e: EventLogEntry) -> bool: return e.kind == EventKinds.STIMULUS_EMITTED)
	assert_int(entries.size()).is_equal(2)
	var first := entries[0] as EventLogEntry
	assert_object(first.source_entity()).is_same(source)
	assert_object(first.target_entity()).is_same(target)
	assert_int(first.data["id"] as int).is_equal(parent.id)
	assert_bool(first.data["type"] is StringName).is_true()
	assert_bool(first.data["cause_id"] is int).is_true()
	var second := entries[1] as EventLogEntry
	assert_object(second.source_entity()).is_null()
	assert_int(second.data["cause_id"] as int).is_equal(parent.id)


func test_damage_and_death_name_the_character_and_the_stimulus() -> void:
	var body := _character("Victim", Vector3.ZERO)
	await Wait.frames(get_tree(), 2)
	var hit := Stimulus.make_contact(&"damage.ballistic", 500.0, body, null)
	StimulusSystem.emit(hit)
	await Wait.frames(get_tree(), 3)

	var damaged := _last(EventKinds.ACTOR_DAMAGED)
	assert_object(damaged).is_not_null()
	assert_object(damaged.target_entity()).is_same(body)
	assert_bool(damaged.data["amount"] is float).is_true()
	assert_bool(damaged.data.has("part")).is_true()
	assert_int(damaged.data["by"] as int).is_equal(hit.id)
	var died := _last(EventKinds.ACTOR_DIED)
	assert_object(died).is_not_null()
	assert_object(died.target_entity()).is_same(body)
	assert_int(died.data["by"] as int).is_equal(hit.id)


func test_stun_and_knockout_name_the_character_and_the_stimulus() -> void:
	var body := _character("Sleeper", Vector3(3, 0, 0))
	await Wait.frames(get_tree(), 2)
	var blow := Stimulus.make_contact(&"damage.stun", 500.0, body, null)
	StimulusSystem.emit(blow)
	await Wait.frames(get_tree(), 3)

	var stunned := _last(EventKinds.ACTOR_STUNNED)
	assert_object(stunned).is_not_null()
	assert_object(stunned.target_entity()).is_same(body)
	assert_int(stunned.data["by"] as int).is_equal(blow.id)
	var knocked := _last(EventKinds.ACTOR_KNOCKED_OUT)
	assert_object(knocked).is_not_null()
	assert_object(knocked.target_entity()).is_same(body)
	assert_int(knocked.data["by"] as int).is_equal(blow.id)


func test_alarm_raised_says_again_and_where() -> void:
	var controller := ALARM.instantiate() as Node3D
	_root.add_child(controller)
	controller.global_position = ORIGIN + Vector3(0, 1, 6)
	await Wait.frames(get_tree(), 2)
	var alarm := AlarmController.of(controller)
	var at := ORIGIN + Vector3(2, 0, 2)

	alarm.raise(at, "test")
	var first := _last(EventKinds.ALARM_RAISED)
	alarm.raise(at, "test")
	var second := _last(EventKinds.ALARM_RAISED)

	assert_bool(first.data["again"] as bool).is_false()
	assert_vector(first.data["point"] as Vector3).is_equal(at)
	assert_bool(second.data["again"] as bool).is_true()


func test_awareness_changes_name_the_character_and_the_new_state() -> void:
	var watcher := Fixtures.entity(_root, "Watcher", ORIGIN + Vector3(-3, 0, 0), [])
	var awareness := GradedAwareness.new()
	awareness.name = "Awareness"
	awareness.config = GUARD_AWARENESS
	watcher.add_child(awareness)

	awareness.alert_at(ORIGIN)

	var changed := _last(EventKinds.ACTOR_AWARENESS)
	assert_object(changed).is_not_null()
	assert_object(changed.source_entity()).is_same(watcher)
	assert_str(changed.data["to"] as String).is_equal(MissionTally.ALERTED)
