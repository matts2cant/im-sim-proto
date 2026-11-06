extends GdUnitTestSuite
## Scenario: the perception lab's light levels in the hub, read by the player's LightExposure at
## each lane centre (z -8), standing and crouched (crouch held), with the breaker closed and then
## opened with E (prompt "E: switch off lab lights"): dark always <= 0.05; dim 0.2-0.35 standing and
## above 0.15 crouched; lit >= 0.6; with the breaker open, lit and dim read <= 0.05. All values keep
## clear of the guards' thresholds (dark < 0.1, fully visible >= 0.5). Closing it again restores
## the lit lane. A broken lamp and the open breaker survive a save and load of the hub.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const HUB := "res://levels/hub/hub.tscn"
const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")
const LANE_Z := -8.0
const LANES: Dictionary[String, float] = {"dark": -2.5, "dim": 2.5, "lit": 7.5}
## Standing in front of the breaker (room-local), 1.2 m from the wall face, looking at the lever.
const BREAKER_SPOT := Vector3(-4.3, 0, -2)
const BREAKER_LOOK := Vector3(-5.4, 1.25, -2)

var _driver: PlayerDriver
var _room: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func _load_hub() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_driver.player.reload_on_reset = false
	_room = _driver.runner.find_child("PerceptionLab") as Node3D
	await _driver.settle()


## Light level standing and crouched at each lane centre: {"dark": [standing, crouched], ...}.
func _measure() -> Dictionary:
	var exposure := LightExposure.of(_driver.player)
	var values := {}
	for lane: String in LANES:
		await _driver.place(_room.to_global(Vector3(LANES[lane], 0, LANE_Z)))
		var standing := exposure.update_now()
		_driver.runner.simulate_action_press(&"crouch")
		await _driver.frames(10)
		assert_bool(ActorState.has(_driver.player, ActorState.CROUCHING)).is_true()
		var crouched := exposure.update_now()
		_driver.runner.simulate_action_release(&"crouch")
		await _driver.frames(10)
		values[lane] = [standing, crouched]
	return values


func _use_breaker() -> void:
	var state := Objects.aiming_state(_driver.player, _room.to_global(BREAKER_SPOT), _room.to_global(BREAKER_LOOK))
	_driver.player.load_state(state)
	await _driver.frames(3)
	assert_str(_driver.player.interactor.prompt).contains("lab lights")
	await _driver.hold(&"use", 2)
	await _driver.frames(2)


func test_lane_levels_with_the_breaker_closed_open_and_closed_again() -> void:
	await _load_hub()

	var on := await _measure()
	print("Perception lab light (standing, crouched), breaker closed: ", on)
	assert_float(on["dark"][0]).is_less_equal(0.05)
	assert_float(on["dark"][1]).is_less_equal(0.05)
	assert_float(on["dim"][0]).is_between(0.2, 0.35)
	assert_float(on["dim"][1]).is_between(0.15, 0.35)
	assert_float(on["lit"][0]).is_greater_equal(0.6)
	assert_float(on["lit"][1]).is_greater_equal(0.6)

	await _use_breaker()
	assert_array(Objects.logged(CircuitBreaker.LOG_KIND, "on", false)).has_size(1)
	var off := await _measure()
	print("Perception lab light (standing, crouched), breaker open: ", off)
	for lane: String in LANES:
		assert_float(off[lane][0]).override_failure_message(lane).is_less_equal(0.05)
		assert_float(off[lane][1]).override_failure_message(lane).is_less_equal(0.05)

	await _use_breaker()
	assert_array(Objects.logged(CircuitBreaker.LOG_KIND, "on", true)).has_size(1)
	await _driver.place(_room.to_global(Vector3(LANES["lit"], 0, LANE_Z)))
	assert_float(LightExposure.of(_driver.player).update_now()).is_greater_equal(0.6)


func test_the_apron_lamps_stay_on_with_the_breaker_open() -> void:
	await _load_hub()

	await _use_breaker()

	for lamp: String in ["ApronLamp", "BreakerLamp"]:
		assert_bool(Powered.of(_room.get_node("Lamps/" + lamp)).on).override_failure_message(lamp).is_true()
	# Standing at the breaker it is still lit enough to find it.
	assert_float(LightExposure.of(_driver.player).update_now()).is_greater(0.3)


func test_broken_lamp_and_open_breaker_survive_save_and_load() -> void:
	var hub: Node3D = HUB_SCENE.instantiate()
	hub.get_node("Player").free()
	add_child(hub)
	await Objects.frames(get_tree(), 5)
	var room := hub.get_node("PerceptionLab") as Node3D
	var lamp := room.get_node("Lamps/LitLamp1") as Node3D
	var from := room.to_global(Vector3(7.5, 1.6, -3))
	var at := lamp.global_position + Vector3(0, -0.25, 0)
	StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 25.0, from, at - from, 20.0))
	(Usable.of(room.get_node("Breaker")) as CircuitBreaker).set_closed(false)
	await Objects.frames(get_tree(), 4)
	assert_bool(is_instance_valid(lamp)).is_false()

	var snapshot := LevelSnapshot.capture(hub)
	hub.free()
	StimulusSystem.clear()
	var fresh: Node3D = HUB_SCENE.instantiate()
	fresh.get_node("Player").free()
	add_child(fresh)
	auto_free(fresh)
	await Objects.frames(get_tree(), 2)
	LevelSnapshot.apply(fresh, snapshot)

	assert_array(snapshot["removed"] as Array).contains(["PerceptionLab/Lamps/LitLamp1"])
	assert_object(fresh.get_node_or_null("PerceptionLab/Lamps/LitLamp1")).is_null()
	assert_bool((Usable.of(fresh.get_node("PerceptionLab/Breaker")) as CircuitBreaker).closed).is_false()
	for lamp_name: String in ["LitLamp2", "DimLamp"]:
		var light := fresh.get_node("PerceptionLab/Lamps/%s/Light" % lamp_name) as Light3D
		assert_bool(light.is_visible_in_tree()).override_failure_message(lamp_name).is_false()
	assert_bool((fresh.get_node("PerceptionLab/Lamps/ApronLamp/Light") as Light3D).visible).is_true()
