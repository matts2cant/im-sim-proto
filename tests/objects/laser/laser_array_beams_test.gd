extends GdUnitTestSuite
## Integration (ADR 0100): a three-beam laser array is one device. A minimal array built in code
## (Tags, receiver with disable / enable, Powered, Device with a Breakable of 20 health, three
## LaserBeam children and a LaserArray with the shipped config) sits at (0, 0.3, 0) of a root at
## (-500, 0, 500), above a floor, beaming along +Z: Beam1 at 0.3 m, 4 m long; Beam2 at 0.9 m, 4 m;
## Beam3 at 1.5 m, 3 m. It reports to a minimal "controller" device cabled to it. Stand-ins are boxes
## (bottom and top given, 0.6 m square) and a 1.8 m walker. The shipped scene with three beams
## (objects/laser/laser_array.tscn plus two laser_beam.tscn) checks the shared emitter's body.

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const CONFIG: LaserArrayConfig = preload("res://objects/laser/laser_array.tres")
const ARRAY_SCENE: PackedScene = preload("res://objects/laser/laser_array.tscn")
const BEAM_SCENE: PackedScene = preload("res://objects/laser/laser_beam.tscn")
const BASE_HEIGHT := 0.3
## Beam height above the floor and length.
const BEAMS: Array[Vector2] = [Vector2(0.3, 4.0), Vector2(0.9, 4.0), Vector2(1.5, 3.0)]
## A stand-in's spot along the beams (2 m from the emitter) and one 1.5 m to the side of it.
const ON_BEAMS := Vector3(0, 0, 2)
const OFF_BEAMS := Vector3(1.5, 0, 2)

var _root: Node3D
var _entity: Node3D
var _laser: LaserArray
var _incidents: Array[Vector3] = []


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_incidents.clear()
	_root = auto_free(Node3D.new())
	_root.position = Vector3(-500, 0, 500)
	add_child(_root)
	Characters.floor_box(_root)
	var receptrons: Array[Receptron] = [
		Devices.action_receptron(Device.DISABLE), Devices.action_receptron(Device.ENABLE)
	]
	_entity = Devices.device(_root, "Array", Vector3(0, BASE_HEIGHT, 0), receptrons, true, 20.0)
	for index in BEAMS.size():
		var beam := LaserBeam.new()
		beam.name = "Beam%d" % (index + 1)
		beam.position = Vector3(0, BEAMS[index].x - BASE_HEIGHT, 0)
		beam.length = BEAMS[index].y
		_entity.add_child(beam)
	_laser = LaserArray.new()
	_laser.config = CONFIG
	_laser.sound_path = ^""
	_entity.add_child(_laser)
	var incident: Array[Receptron] = [Devices.action_receptron(Device.INCIDENT)]
	var controller := Devices.device(_root, "Recorder", Vector3(3, 1, 0), incident)
	Device.of(controller).action_received.connect(_on_incident)
	Devices.link(_entity, controller)


func after_test() -> void:
	StimulusSystem.clear()


func test_three_beams_are_one_device_with_one_status_and_one_command() -> void:
	assert_int(_laser.beams.size()).is_equal(3)
	assert_array(Device.of(_entity).reached(Device.INCIDENT)).contains_exactly([Device.of(_root.get_node("Recorder"))])
	assert_array(Array(DeviceStatus.of(_entity, true))).contains_exactly(["online", "enabled", "clear"])
	# Each beam keeps its own height and length.
	for index in BEAMS.size():
		var beam := _laser.beams[index]
		var from := _root.to_local(beam.start_point(0.0))
		var to := _root.to_local(beam.end_point(0.0))
		assert_float(from.y).is_equal_approx(BEAMS[index].x, 0.0001)
		assert_float(from.distance_to(to)).is_equal_approx(BEAMS[index].y, 0.0001)
	# One disable turns every beam off, one enable every beam on.
	StimulusSystem.emit(Device.command_stimulus(Device.DISABLE, _entity))
	await _frames(3)
	assert_array(EventLog.find(&"laser.toggled")).has_size(1)
	assert_array(Array(DeviceStatus.of(_entity, true))).contains_exactly(["online", "disabled"])
	_box("Intruder", ON_BEAMS, 0.0, 1.8)
	await _frames(20)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	StimulusSystem.emit(Device.command_stimulus(Device.ENABLE, _entity))
	await _frames(5)
	assert_array(EventLog.find(&"laser.tripped")).has_size(1)


func test_any_beam_trips_it_and_reports_at_that_beam() -> void:
	# Only the top beam (1.5 m): a box from 1.2 to 1.8 m.
	var top := _box("Top", OFF_BEAMS, 1.2, 1.8)
	await _frames(5)
	top.position = ON_BEAMS + Vector3(0, 1.2, 0)
	await _frames(4)
	var tripped := EventLog.find(&"laser.tripped")
	assert_array(tripped).has_size(1)
	assert_str(String(tripped[0].data["beam"])).is_equal("Beam3")
	var point := _root.to_local(tripped[0].data["point"] as Vector3)
	assert_float(point.distance_to(Vector3(0, 1.5, 2))).is_less(0.01)
	await _frames(3)
	assert_int(_incidents.size()).is_equal(1)
	# Clear for 1.5 s (re-arm 1 s), then only the bottom beam (0.3 m): a box from 0 to 0.6 m.
	top.position = OFF_BEAMS + Vector3(0, 1.2, 0)
	await _frames(90)
	assert_bool(_laser.model.tripped).is_false()
	_box("Bottom", ON_BEAMS, 0.0, 0.6)
	await _frames(4)
	tripped = EventLog.find(&"laser.tripped")
	assert_array(tripped).has_size(2)
	assert_str(String(tripped[1].data["beam"])).is_equal("Beam1")


func test_a_walker_crossing_all_three_beams_is_one_incident() -> void:
	var walker := Characters.character(_root, "Walker", Vector3(-1.5, 0, 2), [])
	Characters.tags_of(walker).add(&"actor.player")
	walker.set(&"drive", Vector3(4, 0, 0))
	await _frames(60)
	assert_float(walker.position.x).is_greater(1.0)
	assert_array(EventLog.find(&"laser.tripped")).has_size(1)
	await _frames(3)
	assert_int(_incidents.size()).is_equal(1)


func test_it_re_arms_only_once_every_beam_is_clear() -> void:
	var low := _box("Low", ON_BEAMS, 0.0, 0.6)
	await _frames(4)
	assert_array(EventLog.find(&"laser.tripped")).has_size(1)
	# Moved up into the middle beam only: still the same incident, for as long as it stays.
	low.position = ON_BEAMS + Vector3(0, 0.6, 0)
	await _frames(90)
	assert_bool(_laser.model.tripped).is_true()
	assert_array(EventLog.find(&"laser.tripped")).has_size(1)
	# Out of every beam for 1.5 s: re-armed; back into the middle one: a second incident.
	low.position = OFF_BEAMS
	await _frames(90)
	assert_bool(_laser.model.tripped).is_false()
	low.position = ON_BEAMS + Vector3(0, 0.6, 0)
	await _frames(4)
	var tripped := EventLog.find(&"laser.tripped")
	assert_array(tripped).has_size(2)
	assert_str(String(tripped[1].data["beam"])).is_equal("Beam2")


func test_broken_every_beam_stops_and_status_is_offline() -> void:
	Breakable.of(_entity).take_damage(&"damage.ballistic", 25.0)
	await _frames(2)
	assert_bool(ActorState.has(_entity, Device.BROKEN)).is_true()
	assert_bool(_laser.is_watching()).is_false()
	_box("Intruder", ON_BEAMS, 0.0, 1.8)
	await _frames(20)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()


func test_the_shipped_array_with_three_beams_shares_one_emitter_body() -> void:
	var array := ARRAY_SCENE.instantiate() as Node3D
	array.name = "Shipped"
	array.position = Vector3(-1.5, BASE_HEIGHT, -3)
	array.basis = Basis(Vector3.UP, PI * 0.5)
	(array.get_node("Beam1") as LaserBeam).length = 3.0
	for index: int in [1, 2]:
		var beam := BEAM_SCENE.instantiate() as LaserBeam
		beam.name = "Beam%d" % (index + 1)
		beam.position = Vector3(0, BEAMS[index].x - BASE_HEIGHT, 0)
		beam.length = 3.0
		array.add_child(beam)
	_root.add_child(array)
	var laser := LaserArray.of(array)
	await _frames(3)
	assert_int(laser.beams.size()).is_equal(3)
	# One emitter: the three heads, the mast between them and the three receivers are shapes of the
	# array's one body (a weapon ray at any of them hits the array).
	var space := array.get_world_3d().direct_space_state
	var targets: Array[Vector3] = []
	for beam in laser.beams:
		targets.append(beam.start_point(0.04))
		targets.append(beam.end_point(0.04))
	targets.append(array.to_global(Vector3(0, 0.3, 0.025)))
	targets.append(array.to_global(Vector3(0, 0.9, 0.025)))
	for target in targets:
		var query := PhysicsRayQueryParameters3D.create(
			target + Vector3(0, 0, -2), target + Vector3(0, 0, 2), PhysicsLayers.WEAPON_MASK
		)
		var hit := space.intersect_ray(query)
		assert_object(hit.get("collider")).override_failure_message(str(_root.to_local(target))).is_same(array)
	# Every ray shows; one pistol round on the emitter breaks the device: every beam goes dark.
	for beam in laser.beams:
		assert_bool(beam.ray_visible()).is_true()
		assert_bool((beam.get_node("Head/Lens") as Node3D).visible).is_true()
	Breakable.of(array).take_damage(&"damage.ballistic", 25.0)
	await _frames(2)
	assert_bool(laser.is_watching()).is_false()
	for beam in laser.beams:
		assert_bool(beam.ray_visible()).override_failure_message(String(beam.name)).is_false()
		assert_bool((beam.get_node("Head/Lens") as Node3D).visible).is_false()
	_box("Intruder", Vector3(0, 0, -3), 0.0, 1.8)
	await _frames(20)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()


func test_an_array_feeds_at_most_four_beams() -> void:
	var entity := Devices.device(_root, "Five", Vector3(0, BASE_HEIGHT, -6), [], true)
	for index in 5:
		var beam := LaserBeam.new()
		beam.name = "Beam%d" % (index + 1)
		beam.position = Vector3(0, index * 0.2, 0)
		entity.add_child(beam)
	var laser := LaserArray.new()
	laser.config = CONFIG
	laser.sound_path = ^""
	entity.add_child(laser)
	assert_int(laser.beams.size()).is_equal(CONFIG.max_beams)
	assert_str(String(laser.beams[3].name)).is_equal("Beam4")


# A static box stand-in (0.6 m square, from `bottom` to `top` above `feet`) on the player layer with
# the player's tag.
func _box(box_name: String, feet: Vector3, bottom: float, top: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.PLAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, top - bottom, 0.6)
	shape.shape = box
	shape.position.y = (top - bottom) * 0.5
	body.add_child(shape)
	var tags: Array[StringName] = [&"actor.player"]
	return Fixtures.compose(body, _root, box_name, feet + Vector3(0, bottom, 0), [], tags) as StaticBody3D


func _on_incident(action: StringName, stimulus: Stimulus) -> void:
	if action == Device.INCIDENT:
		_incidents.append(stimulus.origin)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
