extends GdUnitTestSuite
## Integration (ADR 0096, ADR 0100): the laser array behaviour is generic. A minimal one-beam array
## built in code (Tags, receiver with the disable / enable receptrons, Powered, Device, one LaserBeam
## and a LaserArray with the shipped config, no visuals and no body) watches a 4 m beam along its +Z,
## 0.4 m above a floor, and reports
## to a minimal "controller" device cabled to it (it accepts `device.incident`). Stand-ins are boxes
## and walkers moved into the beam. Built at (-500, 0, 300), away from other suites' leftovers.

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const CONFIG: LaserArrayConfig = preload("res://objects/laser/laser_array.tres")
const BEAM_HEIGHT := 0.4
const BEAM_LENGTH := 4.0
## A stand-in's spot in the beam (2 m along it) and one 1.5 m to the side of it.
const ON_BEAM := Vector3(0, 0, 2)
const OFF_BEAM := Vector3(1.5, 0, 2)

var _root: Node3D
var _laser_entity: Node3D
var _laser: LaserArray
var _incidents: Array[Vector3] = []


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_incidents.clear()
	_root = auto_free(Node3D.new())
	_root.position = Vector3(-500, 0, 300)
	add_child(_root)
	Characters.floor_box(_root)
	var receptrons: Array[Receptron] = [
		Devices.action_receptron(Device.DISABLE), Devices.action_receptron(Device.ENABLE)
	]
	_laser_entity = Devices.device(_root, "Tripwire", Vector3(0, BEAM_HEIGHT, 0), receptrons, true)
	var beam := LaserBeam.new()
	beam.name = "Beam1"
	beam.length = BEAM_LENGTH
	_laser_entity.add_child(beam)
	_laser = LaserArray.new()
	_laser.config = CONFIG
	_laser.sound_path = ^""
	_laser_entity.add_child(_laser)
	var incident: Array[Receptron] = [Devices.action_receptron(Device.INCIDENT)]
	var controller := Devices.device(_root, "Recorder", Vector3(3, 1, 0), incident)
	Device.of(controller).action_received.connect(_on_incident)
	Devices.link(_laser_entity, controller)


func after_test() -> void:
	StimulusSystem.clear()


func test_a_body_in_the_beam_reports_one_incident_at_the_break_point() -> void:
	var body := _box("Intruder", OFF_BEAM, PhysicsLayers.PLAYER, [&"actor.player"])
	await _frames(10)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	body.position = ON_BEAM
	await _frames(4)
	var tripped := EventLog.find(&"laser.tripped")
	assert_array(tripped).has_size(1)
	assert_str(String(tripped[0].data["by"])).is_equal("Intruder")
	assert_str(String(tripped[0].data["beam"])).is_equal("Beam1")
	assert_int(int(tripped[0].data["controllers"])).is_equal(1)
	var expected := _root.to_global(Vector3(0, BEAM_HEIGHT, 2))
	assert_float((tripped[0].data["point"] as Vector3).distance_to(expected)).is_less(0.01)
	await _frames(3)
	assert_int(_incidents.size()).is_equal(1)
	assert_float(_incidents[0].distance_to(expected)).is_less(0.01)
	# The beep: a noise at the emitter.
	var beeps := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data.get("type") == &"noise"
	)
	assert_array(beeps).has_size(1)
	assert_float((beeps[0].data["origin"] as Vector3).distance_to(_laser_entity.global_position)).is_less(0.01)
	assert_bool(_laser.model.tripped).is_true()
	# Standing in the beam for a second more: still one incident.
	await _frames(60)
	assert_array(EventLog.find(&"laser.tripped")).has_size(1)
	# Out for 1.5 s (re-arm 1 s), back in: a second crossing.
	body.position = OFF_BEAM
	await _frames(90)
	assert_bool(_laser.model.tripped).is_false()
	body.position = ON_BEAM
	await _frames(4)
	assert_array(EventLog.find(&"laser.tripped")).has_size(2)


func test_a_walker_crossing_trips_it_once() -> void:
	var walker := Characters.character(_root, "Walker", Vector3(-1.5, 0, 2), [])
	Characters.tags_of(walker).add(&"actor.player")
	walker.set(&"drive", Vector3(4, 0, 0))
	await _frames(60)
	assert_float(walker.position.x).is_greater(1.0)
	assert_array(EventLog.find(&"laser.tripped")).has_size(1)


func test_bodies_above_the_beam_or_on_the_world_layer_do_not_trip_it() -> void:
	# Its bottom 0.3 m above the beam.
	_box("Above", ON_BEAM + Vector3(0, BEAM_HEIGHT + 0.3, 0), PhysicsLayers.PLAYER, [&"actor.player"])
	_box("Wall", ON_BEAM + Vector3(0, 0, 0.8), PhysicsLayers.WORLD)
	await _frames(30)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()


func test_a_guard_crossing_is_ignored_but_a_downed_one_trips_it() -> void:
	var guard := Characters.character(_root, "Guard", Vector3(-1.5, 0, 2), [])
	Characters.tags_of(guard).add(&"actor.guard")
	guard.set(&"drive", Vector3(4, 0, 0))
	await _frames(60)
	assert_float(guard.position.x).is_greater(1.0)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	# Knocked out, lying across the beam (the downed layer, like DownedPose).
	var body := _box("Downed", OFF_BEAM, PhysicsLayers.DOWNED, [&"actor.guard", &"state.unconscious"])
	await _frames(3)
	body.position = ON_BEAM
	await _frames(4)
	var tripped := EventLog.find(&"laser.tripped")
	assert_array(tripped).has_size(1)
	assert_str(String(tripped[0].data["by"])).is_equal("Downed")


func test_a_carried_ghost_body_trips_it() -> void:
	# Layer 0 like a held body: no physics query finds it, only the carried group.
	var crate := Fixtures.rigid_entity(_root, "Crate", ON_BEAM + Vector3(0, BEAM_HEIGHT, 0), [], [], 0.4, 2.0, 0.0)
	crate.freeze = true
	crate.collision_layer = 0
	crate.collision_mask = 0
	var carryable := Carryable.new()
	crate.add_child(carryable)
	await _frames(10)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	carryable.set_carrier(_root)
	await _frames(3)
	assert_array(EventLog.find(&"laser.tripped")).has_size(1)
	assert_str(String(EventLog.find(&"laser.tripped")[0].data["by"])).is_equal("Crate")
	carryable.set_carrier(null)
	assert_bool(carryable.is_in_group(Carryable.CARRIED_GROUP)).is_false()


func test_disabled_it_neither_checks_nor_reports_until_enabled() -> void:
	StimulusSystem.emit(Device.command_stimulus(Device.DISABLE, _laser_entity))
	await _frames(3)
	assert_bool(_laser.is_watching()).is_false()
	assert_array(EventLog.find(&"laser.toggled")).has_size(1)
	_box("Intruder", ON_BEAM, PhysicsLayers.PLAYER, [&"actor.player"])
	await _frames(30)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	StimulusSystem.emit(Device.command_stimulus(Device.ENABLE, _laser_entity))
	await _frames(5)
	assert_array(EventLog.find(&"laser.tripped")).has_size(1)


func test_unpowered_it_does_not_trip_and_ignores_commands() -> void:
	Powered.of(_laser_entity).on = false
	_box("Intruder", ON_BEAM, PhysicsLayers.PLAYER, [&"actor.player"])
	await _frames(30)
	assert_bool(_laser.is_watching()).is_false()
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	Powered.of(_laser_entity).on = true
	await _frames(3)
	assert_array(EventLog.find(&"laser.tripped")).has_size(1)


func test_broken_it_does_not_trip() -> void:
	Device.of(_laser_entity).load_state({"broken": true})
	_box("Intruder", ON_BEAM, PhysicsLayers.PLAYER, [&"actor.player"])
	await _frames(30)
	assert_bool(_laser.is_watching()).is_false()
	assert_array(EventLog.find(&"laser.tripped")).is_empty()


func test_status_words() -> void:
	assert_array(Array(DeviceStatus.of(_laser_entity, true))).contains_exactly(["online", "enabled", "clear"])
	assert_bool(DeviceStatus.is_disabled(_laser_entity)).is_false()
	var body := _box("Intruder", ON_BEAM, PhysicsLayers.PLAYER, [&"actor.player"])
	await _frames(3)
	assert_array(Array(DeviceStatus.of(_laser_entity, true))).contains_exactly(["online", "enabled", "tripped"])
	body.position = OFF_BEAM
	await _frames(90)
	assert_array(Array(_laser.device_status())).contains_exactly(["enabled", "clear"])
	StimulusSystem.emit(Device.command_stimulus(Device.DISABLE, _laser_entity))
	await _frames(3)
	assert_array(Array(DeviceStatus.of(_laser_entity, true))).contains_exactly(["online", "disabled"])
	assert_bool(DeviceStatus.is_disabled(_laser_entity)).is_true()
	assert_bool(DeviceStatus.has_view(_laser_entity)).is_false()


func test_save_and_load() -> void:
	_box("Intruder", ON_BEAM, PhysicsLayers.PLAYER, [&"actor.player"])
	await _frames(3)
	StimulusSystem.emit(Device.command_stimulus(Device.DISABLE, _laser_entity))
	await _frames(3)
	var saved := _laser.save_state()
	StimulusSystem.emit(Device.command_stimulus(Device.ENABLE, _laser_entity))
	await _frames(3)
	assert_bool(_laser.disabled).is_false()
	_laser.load_state(saved)
	assert_bool(_laser.disabled).is_true()
	assert_bool(_laser.is_watching()).is_false()
	# A tripped beam loads tripped: the body still in it is the same crossing.
	_laser.load_state({"disabled": false, "trip": {"tripped": true, "clear_time": 0.0}})
	EventLog.clear()
	await _frames(10)
	assert_bool(_laser.model.tripped).is_true()
	assert_array(EventLog.find(&"laser.tripped")).is_empty()


# A static box stand-in (0.6 x 1.8 x 0.6 m, bottom at `feet`) on `layer` with Tags.
func _box(box_name: String, feet: Vector3, layer: int, tags: Array[StringName] = []) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.8, 0.6)
	shape.shape = box
	shape.position.y = 0.9
	body.add_child(shape)
	return Fixtures.compose(body, _root, box_name, feet, [], tags) as StaticBody3D


func _on_incident(action: StringName, stimulus: Stimulus) -> void:
	if action == Device.INCIDENT:
		_incidents.append(stimulus.origin)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
