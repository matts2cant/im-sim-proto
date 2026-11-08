extends GdUnitTestSuite
## Scenario (EventLog): shouts and radio (ADR 0072) in the comms yard
## (tests/scenarios/fixtures/comms_yard.tscn): a 20 m wall across x -10..10 at z 0. `Caller` at
## (0, 0, 3); `Near` 5 m of path behind it (z 8); `BehindWall` (no radio) at z -3, 6 m straight but
## about 21 m of path around the wall end; `RadioNear` 25 m straight (z -22, 35 m of path);
## `RadioFar` 35 m straight (z -32). Shout: loudness 18, heeded at a margin >= 1 (17 m of path).
## Radio: 30 m straight, through walls, radios only. Sirens and the alarm devices (ADR 0077):
## tests/scenarios/alarm_devices_test.gd.

const Guards := preload("res://tests/actors/guard/guard_helpers.gd")
const YARD := "res://tests/scenarios/fixtures/comms_yard.tscn"
const TIME_FACTOR := 9.0

var _scene: Node
var _map_was_async: bool = true


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	await Guards.let_old_scenes_go(get_tree())
	var runner := scene_runner(YARD)
	runner.set_time_factor(TIME_FACTOR)
	_scene = runner.scene()
	var map := _guard("Caller").get_world_3d().navigation_map
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(map)
	NavigationServer3D.map_set_use_async_iterations(map, false)
	var region := _scene.get_node("LevelNavigation") as LevelNavigation
	NavigationServer3D.region_set_use_async_iterations(region.get_rid(), false)
	Guards.isolate_region(map, region)
	region.bake()
	await _frames(6)
	EventLog.clear()


func after_test() -> void:
	if _scene != null and is_instance_valid(_scene):
		var map := _guard("Caller").get_world_3d().navigation_map
		NavigationServer3D.map_set_use_async_iterations(map, _map_was_async)
	StimulusSystem.clear()


func test_a_shout_reaches_an_ally_within_path_range_and_not_one_around_the_wall() -> void:
	# Measured along the navmesh, as the shout travels: well inside / well outside 17 m.
	var map := _guard("Caller").get_world_3d().navigation_map
	var near_path := _path_length(map, _guard("Caller"), _guard("Near"))
	var behind_path := _path_length(map, _guard("Caller"), _guard("BehindWall"))
	assert_float(near_path).is_less(8.0)
	assert_float(behind_path).is_greater(20.0)

	_awareness("Caller").alert_at(Vector3(0, 0, 5))
	await _frames(12)

	var shouts := _entries(&"actor.shout", "Caller")
	assert_array(shouts).has_size(1)
	assert_str(String(shouts[0].data["reason"])).is_equal("alerted")
	assert_str(_awareness("Near").state_name()).is_equal("searching")
	assert_str(_awareness("Near").model.reason).is_equal("shout")
	# Searching at the shouter's position, first at run pace.
	assert_float(_awareness("Near").model.point.distance_to(_guard("Caller").global_position)).is_less(1.0)
	assert_int(_awareness("Near").model.pace).is_equal(AwarenessModel.Pace.RUN)
	assert_str(_awareness("BehindWall").state_name()).is_equal("unaware")
	assert_array(_entries(&"actor.heard_call", "BehindWall")).is_empty()


func test_radio_reaches_a_radio_25_m_away_through_walls_and_not_35_m() -> void:
	_awareness("Caller").alert_at(Vector3(0, 0, 5))
	await _frames(12)

	assert_array(_entries(&"actor.radio", "Caller")).has_size(1)
	assert_str(_awareness("RadioNear").state_name()).is_equal("searching")
	assert_str(_awareness("RadioNear").model.reason).is_equal("radio")
	assert_str(_awareness("RadioFar").state_name()).is_equal("unaware")
	# Searchers neither shout nor radio: the calls do not cascade.
	assert_array(EventLog.find(&"actor.shout")).has_size(1)
	assert_array(EventLog.find(&"actor.radio")).has_size(1)


func test_without_a_radio_tag_no_call_goes_out_and_none_is_heard() -> void:
	ActorState.set_tag(_guard("Caller"), &"equipment.radio", false)
	_awareness("Caller").alert_at(Vector3(0, 0, 5))
	await _frames(12)
	assert_array(EventLog.find(&"actor.radio")).is_empty()
	assert_str(_awareness("RadioNear").state_name()).is_equal("unaware")


func test_a_shout_from_a_non_ally_is_not_heeded() -> void:
	var stranger := Node3D.new()
	stranger.name = "Stranger"
	_scene.add_child(stranger)
	stranger.global_position = Vector3(0, 0, 6)
	StimulusSystem.emit(
		Stimulus.make_radius(&"alert.shout", 18.0, stranger.global_position, 18.0, stranger, Stimulus.Propagation.PATH)
	)
	await _frames(4)
	assert_str(_awareness("Near").state_name()).is_equal("unaware")


func _guard(guard_name: String) -> NavWalker:
	return _scene.get_node(guard_name) as NavWalker


func _awareness(guard_name: String) -> GradedAwareness:
	return GradedAwareness.of_node(_guard(guard_name))


func _entries(kind: StringName, actor: String) -> Array[EventLogEntry]:
	return EventLog.find(kind).filter(func(entry: EventLogEntry) -> bool: return entry.data.get("actor") == actor)


func _path_length(map: RID, from: Node3D, to: Node3D) -> float:
	var path := NavigationServer3D.map_get_path(map, from.global_position, to.global_position, true)
	return StimulusPropagation.polyline_length(path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
