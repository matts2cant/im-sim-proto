extends GdUnitTestSuite
## Scenario (EventLog): alarm devices and guards (ADR 0077) in the alarm yard
## (tests/scenarios/fixtures/alarm_yard.tscn, its root 200 m east of the origin so its floor, freed
## late by the scene runner, never joins a later suite's navmesh; yard-local coordinates): a 30 m
## wall across x -18..12 at z -2 (gap at the west end), devices on its north face: Siren (4, 2.5),
## Switch (6, 1.4), Controller (8, 1.4), PanicButton (10, 1.2), BaseStation (0, 1.5). Cables:
## switch - controller, switch - siren, button - controller, base station - controller (the switch
## is on circuit `yard_net`). Guards: `Near` (-14, 0, 6) about 20 m of path from the siren; `Far`
## (4, 0, -6) behind the wall, 5 m straight but about 45 m of path (no radio); `RadioBehind` (-4,
## 0, -8) behind the wall, about 40 m of path, 8 m straight from the base station. Siren: loudness
## 35, heeded at a margin >= 1 (34 m of path). Base station: 40 m straight, radios only.

const Wait := preload("res://tests/helpers/wait.gd")
const Guards := preload("res://tests/actors/guard/guard_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const YARD := "res://tests/scenarios/fixtures/alarm_yard.tscn"
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
	var map := _guard("Near").get_world_3d().navigation_map
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(map)
	var region := _scene.get_node("LevelNavigation") as LevelNavigation
	await Guards.use_sync_iterations(map, region)
	Guards.isolate_region(map, region)
	region.bake()
	await Wait.frames(get_tree(), 6)
	EventLog.clear()


func after_test() -> void:
	if _scene != null and is_instance_valid(_scene):
		var map := _guard("Near").get_world_3d().navigation_map
		NavigationServer3D.map_set_use_async_iterations(map, _map_was_async)
	StimulusSystem.clear()


func test_the_yard_measures_as_described() -> void:
	# Along the navmesh from the siren to each guard's ears, as the siren travels: far from 34 m.
	var map := _guard("Near").get_world_3d().navigation_map
	var siren := _node("Siren").global_position
	assert_float(_path_length(map, siren, _ears("Near"))).is_between(16.0, 26.0)
	assert_float(_path_length(map, siren, _ears("Far"))).is_greater(42.0)
	assert_float(_path_length(map, siren, _ears("RadioBehind"))).is_greater(38.0)
	var station := _node("BaseStation").global_position
	assert_float(station.distance_to(_ears("RadioBehind"))).is_less(30.0)
	assert_bool(ActorState.has(_guard("Far"), &"equipment.radio")).is_false()


func test_panic_button_to_siren_to_a_guard_who_hears_it_searching_where_it_stands() -> void:
	# The base station off, so only the siren matters here.
	Powered.of(_node("BaseStation")).on = false
	Usable.of(_node("PanicButton")).use(null)
	await Wait.frames(get_tree(), 12)

	var chain: Array[EventLogEntry] = [
		EventLog.find(&"device.panic")[0],
		_first(&"stimulus.emitted", &"device.incident"),
		EventLog.find(&"alarm.raised")[0],
		_first(&"stimulus.emitted", &"command.ring"),
		EventLog.find(&"siren.started")[0],
		_first(&"stimulus.emitted", &"alarm.siren"),
		_heard_siren("Near")[0],
		EventLog.find(&"actor.heard_alarm")[0],
	]
	for index in range(1, chain.size()):
		assert_int(chain[index].tick).override_failure_message(chain[index].kind).is_greater_equal(
			chain[index - 1].tick
		)
	assert_str(String(EventLog.find(&"actor.heard_alarm")[0].data["actor"])).is_equal("Near")
	assert_str(_awareness("Near").state_name()).is_equal("searching")
	assert_str(_awareness("Near").model.reason).is_equal("alarm")
	assert_float(_awareness("Near").model.point.distance_to(_guard("Near").global_position)).is_less(1.0)
	assert_bool(_awareness("Near").model.is_wary()).is_true()
	# Out of earshot behind 40+ m of path: nothing heard, no reaction.
	for guard_name: String in ["Far", "RadioBehind"]:
		assert_array(_heard_siren(guard_name)).override_failure_message(guard_name).is_empty()
		assert_str(_awareness(guard_name).state_name()).override_failure_message(guard_name).is_equal("unaware")


func test_the_base_station_sends_radio_guards_to_the_incident() -> void:
	var button := _node("PanicButton").global_position
	Usable.of(_node("PanicButton")).use(null)
	await Wait.frames(get_tree(), 12)

	assert_array(EventLog.find(&"radio.dispatch")).has_size(1)
	# Near hears the siren too; the dispatch still sends it to the button. RadioBehind hears no
	# siren but has a radio within 40 m of the station.
	for guard_name: String in ["Near", "RadioBehind"]:
		var awareness := _awareness(guard_name)
		assert_str(awareness.state_name()).override_failure_message(guard_name).is_equal("searching")
		assert_str(awareness.model.reason).override_failure_message(guard_name).is_equal("radio")
		assert_float(awareness.model.point.distance_to(button)).override_failure_message(guard_name).is_less(1.0)
	assert_str(_awareness("Far").state_name()).is_equal("unaware")


func test_a_trigger_keeps_hearers_searching_for_45_s_then_the_sirens_stop() -> void:
	StimulusSystem.emit(Device.command_stimulus(AlarmController.TRIGGER, _node("Controller")))
	await Wait.frames(get_tree(), 12)
	assert_str(_awareness("Near").state_name()).is_equal("searching")
	assert_bool(_awareness("Near").model.is_wary()).is_true()
	assert_array(EventLog.find(&"radio.dispatch")).is_empty()

	# The shipped controller rings for 45 s (ADR 0100).
	assert_float(_controller().config.duration).is_equal(45.0)
	# 35 s in (past one 30 s search): still searching, still ringing.
	await _seconds(35.0)
	assert_bool(_controller().is_ringing()).is_true()
	assert_str(_awareness("Near").state_name()).is_equal("searching")
	assert_str(_awareness("Far").state_name()).is_equal("unaware")
	assert_array(EventLog.find(&"alarm.ended")).is_empty()

	# Over after 45 s (checked at 46 s); the siren is silenced.
	await _seconds(11.0)
	assert_bool(_controller().is_ringing()).is_false()
	assert_str(String(EventLog.find(&"alarm.ended")[0].data["reason"])).is_equal("timeout")
	assert_bool(_siren().is_sounding()).is_false()
	assert_str(String(EventLog.find(&"siren.stopped")[0].data["reason"])).is_equal("silenced")


func test_an_alerted_guard_carries_on_when_it_hears_the_siren() -> void:
	_awareness("Near").alert_at(_scene.to_global(Vector3(-14, 0, 10)))
	await Wait.frames(get_tree(), 2)
	StimulusSystem.emit(Device.command_stimulus(AlarmController.TRIGGER, _node("Controller")))
	await Wait.frames(get_tree(), 12)
	assert_array(_heard_siren("Near")).is_not_empty()
	assert_str(_awareness("Near").state_name()).is_equal("alerted")
	assert_bool(_awareness("Near").model.is_wary()).is_true()


func test_cutting_the_switch_power_stops_the_ring_reaching_the_siren() -> void:
	assert_int(Powered.set_circuit(_scene.get_tree(), &"yard_net", false)).is_equal(1)
	Usable.of(_node("PanicButton")).use(null)
	await Wait.frames(get_tree(), 12)

	# The controller still rings (the button is cabled to it) and radios the incident, but the ring
	# never reaches the siren behind the switch.
	assert_bool(_controller().is_ringing()).is_true()
	var rings := EventLog.find(&"device.command").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["command"] == Siren.RING
	)
	assert_array(rings).is_empty()
	assert_array(EventLog.find(&"siren.started")).is_empty()
	assert_array(_heard_siren("Near")).is_empty()
	assert_str(_awareness("Near").model.reason).is_equal("radio")


func test_a_plain_tagged_entity_with_the_right_receptrons_acts_as_a_siren() -> void:
	Powered.set_circuit(_scene.get_tree(), &"yard_net", false)
	# No Siren component: `command.ring` emits an `alarm.siren` of loudness 35 along the navmesh.
	var ring := Devices.command_receptron(
		Siren.RING, [Fixtures.emit_radius(&"alarm.siren", 35.0, Stimulus.Propagation.PATH)]
	)
	var horn := Devices.device(_scene, "PlainHorn", Vector3(-8, 2, 4), [ring])
	Devices.link(horn, _node("Controller"))
	StimulusSystem.emit(Device.command_stimulus(AlarmController.TRIGGER, _node("Controller")))
	await Wait.frames(get_tree(), 12)

	assert_array(EventLog.find(&"siren.started")).is_empty()
	var heard := _heard_siren("Near")
	assert_array(heard).is_not_empty()
	assert_str(heard[0].source).is_equal("PlainHorn")
	assert_str(_awareness("Near").state_name()).is_equal("searching")
	assert_str(_awareness("Near").model.reason).is_equal("alarm")


func _node(node_name: String) -> Node3D:
	return _scene.get_node(node_name) as Node3D


func _controller() -> AlarmController:
	return _scene.get_node("Controller/AlarmControllerBehaviour") as AlarmController


func _siren() -> Siren:
	return _scene.get_node("Siren/SirenBehaviour") as Siren


func _guard(guard_name: String) -> NavWalker:
	return _scene.get_node(guard_name) as NavWalker


func _ears(guard_name: String) -> Vector3:
	return (_guard(guard_name).get_node("Ears") as Node3D).global_position


func _awareness(guard_name: String) -> GradedAwareness:
	return GradedAwareness.of_node(_guard(guard_name))


## `receptron.fired` entries of `heard_siren` on `guard_name`.
func _heard_siren(guard_name: String) -> Array[EventLogEntry]:
	return EventLog.find(&"receptron.fired").filter(
		func(entry: EventLogEntry) -> bool:
			return entry.target == guard_name and entry.data["receptron"] == "heard_siren"
	)


func _first(kind: StringName, type: StringName) -> EventLogEntry:
	for entry in EventLog.find(kind):
		if entry.data.get("type") == type:
			return entry
	return null


func _path_length(map: RID, from: Vector3, to: Vector3) -> float:
	var points := PackedVector3Array([from])
	points.append_array(NavigationServer3D.map_get_path(map, from, to, true))
	points.append(to)
	return StimulusPropagation.polyline_length(points)


func _seconds(value: float) -> void:
	await Wait.frames(get_tree(), roundi(value * 60.0))
