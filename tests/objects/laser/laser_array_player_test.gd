extends GdUnitTestSuite
## Integration (ADR 0096, ADR 0100): the real player against the shipped laser array scene
## (objects/laser/laser_array.tscn, extra beams from laser_beam.tscn) on a flat floor. Each beam is
## 3 m long, across the player's
## path (emitter at x -1.5, beam along +X) at z -3; the player starts at z 1.5 facing -Z and walks
## (4 m/s). Heights (design/levels/metrics.md): low beam 0.4 m (jump apex 1.0 m: the feet are above
## 0.4 m from 0.07 s to 0.57 s of the 0.64 s airtime, so a walking take-off 0.64-1.92 m before the
## beam clears it; the test takes off 1.3 m before), high beam 1.3 m (crouched height 0.95 m: 0.35 m
## below it). A two-beam array (0.4 m + 1.3 m) stops both.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const FLOOR := "res://tests/actors/player/fixtures/flat_floor.tscn"
const LASER: PackedScene = preload("res://objects/laser/laser_array.tscn")
const BEAM: PackedScene = preload("res://objects/laser/laser_beam.tscn")
const BEAM_Z := -3.0
const LOW := 0.4
const HIGH := 1.3
const START := Vector3(0, 0, 1.5)
## Take-off this far before the beam (centre to beam), mid-window of 0.64-1.92 m.
const TAKE_OFF := 1.3

var _driver: PlayerDriver
var _player: Player
var _scene: Node


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_walking_across_the_low_beam_trips_it() -> void:
	await _load([["Low", [LOW]]])
	await _walk_past()
	assert_array(_tripped("Low")).has_size(1)
	assert_str(String(_tripped("Low")[0].data["by"])).is_equal("Player")


func test_jumping_the_low_beam_does_not_trip_it() -> void:
	await _load([["Low", [LOW]]])
	await _walk_past(true)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()


func test_walking_upright_under_the_high_beam_trips_it() -> void:
	await _load([["High", [HIGH]]])
	await _walk_past()
	assert_array(_tripped("High")).has_size(1)


func test_crouching_under_the_high_beam_does_not_trip_it() -> void:
	await _load([["High", [HIGH]]])
	await _walk_past(false, true)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()


func test_the_two_beam_array_stops_a_jump_and_a_crouch() -> void:
	await _load([["Pair", [LOW, HIGH]]])
	await _walk_past(true)
	assert_array(_tripped("Pair")).has_size(1)
	assert_str(String(_tripped("Pair")[0].data["beam"])).is_equal("Beam2")
	await _driver.place(START)
	await _walk_past(false, true)
	assert_array(_tripped("Pair")).has_size(1)
	assert_str(String(_tripped("Pair")[0].data["beam"])).is_equal("Beam1")


func test_a_thrown_crate_trips_it() -> void:
	await _load([["Low", [LOW]]])
	await _driver.place(Vector3(0, 0, 0))
	var crate := Objects.spawn(_scene, Objects.SMALL_CRATE, Vector3(0, 0.3, -1.0), "Crate") as RigidBody3D
	await _driver.frames(5)
	_player.carry.pick_up(crate)
	await _driver.frames(20)
	assert_bool(_player.carry.is_carrying()).is_true()
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	assert_bool(_player.carry.throw()).is_true()
	await _driver.frames(60)
	var tripped := _tripped("Low")
	assert_array(tripped).has_size(1)
	assert_str(String(tripped[0].data["by"])).is_equal("Crate")
	assert_float(_player.global_position.z).is_greater(-0.5)


func test_one_pistol_round_breaks_the_emitter() -> void:
	await _load([["Low", [LOW]]])
	var laser := _scene.get_node("Low") as Node3D
	Breakable.of(laser).take_damage(&"damage.ballistic", 25.0)
	assert_bool(ActorState.has(laser, Device.BROKEN)).is_true()
	await _driver.frames(2)
	assert_bool((laser.get_node("Beam1") as LaserBeam).ray_visible()).is_false()
	await _walk_past()
	assert_array(EventLog.find(&"laser.tripped")).is_empty()


# Loads the floor with a laser array per [name, [beam heights]] across the path at BEAM_Z (the array
# at the first beam's height, the others added above it), and places the player.
func _load(lasers: Array) -> void:
	var runner := scene_runner(FLOOR)
	_driver = PlayerDriver.new(runner)
	_player = _driver.player
	_scene = runner.scene()
	for spec: Array in lasers:
		var laser := LASER.instantiate() as Node3D
		laser.name = String(spec[0])
		var heights: Array = spec[1]
		laser.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-1.5, float(heights[0]), BEAM_Z))
		(laser.get_node("Beam1") as LaserBeam).length = 3.0
		for index in range(1, heights.size()):
			var beam := BEAM.instantiate() as LaserBeam
			beam.name = "Beam%d" % (index + 1)
			beam.position = Vector3(0, float(heights[index]) - float(heights[0]), 0)
			beam.length = 3.0
			laser.add_child(beam)
		_scene.add_child(laser)
	await _driver.settle()
	await _driver.place(START)


# Walks forward from START until 2 m past the beam; `jump`: takes off TAKE_OFF before the beam;
# `crouch`: crouched all the way (held from the start).
func _walk_past(jump: bool = false, crouch: bool = false) -> void:
	var runner := _driver.runner
	if crouch:
		runner.simulate_action_press(&"crouch")
		await _driver.frames(10)
		assert_bool(_player.crouched).is_true()
	runner.simulate_action_press(&"move_forward")
	var jumped := false
	for i in 300:
		var z := _player.global_position.z
		if z < BEAM_Z - 2.0:
			break
		if jump and not jumped and z <= BEAM_Z + TAKE_OFF:
			jumped = true
			runner.simulate_action_press(&"jump")
		await _driver.frames(1)
		if jumped:
			runner.simulate_action_release(&"jump")
	runner.simulate_action_release(&"move_forward")
	if crouch:
		runner.simulate_action_release(&"crouch")
	await _driver.frames(5)
	assert_float(_player.global_position.z).is_less(BEAM_Z - 1.0)


func _tripped(laser_name: String) -> Array[EventLogEntry]:
	return Objects.logged(&"laser.tripped", "laser", laser_name)
