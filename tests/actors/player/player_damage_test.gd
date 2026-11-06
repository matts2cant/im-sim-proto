extends GdUnitTestSuite
## Integration: the player's body parts (hitboxes, leg injuries, explosions, falls, death, medkit).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const MEDKIT := "res://objects/medkit/medkit.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_ray_on_the_head_hitbox_is_a_headshot() -> void:
	await _load()
	await _driver.place(Vector3(2, 0, 2))
	var origin := Vector3(2, 1.64, -2)
	var ray := Stimulus.make_ray(
		&"damage.ballistic", 25.0, origin, Vector3(0, 0, 1), 10.0, null, PhysicsLayers.WEAPON_MASK
	)

	StimulusSystem.emit(ray)
	await _driver.frames(2)

	var hits := Objects.logged(&"actor.damaged", "part", &"head")
	assert_array(hits).has_size(1)
	assert_float(hits[0].data["amount"]).is_equal(50.0)
	assert_float(_player.body.health(&"head")).is_equal(10.0)


func test_crouching_lowers_the_hitboxes() -> void:
	await _load()
	await _driver.place(Vector3.ZERO)
	var head := _player.hitboxes.box(&"head") as Node3D
	assert_float(head.position.y).is_equal_approx(1.64, 0.001)

	_driver.runner.simulate_action_press(&"crouch")
	await _driver.frames(3)
	var crouched_y := head.position.y
	_driver.runner.simulate_action_release(&"crouch")

	assert_float(crouched_y).is_equal_approx(1.64 * CONFIG.crouched_height / CONFIG.standing_height, 0.001)


func test_one_disabled_leg_slows_the_player() -> void:
	await _load()
	await _driver.place(Vector3.ZERO)
	_player.body.take_damage(&"damage.blunt", 100.0, &"leg_l")

	var speed := await _walk_speed(&"move_back", 60)

	assert_float(_player.attributes.value(&"move_speed_mult")).is_equal_approx(0.6, 0.0001)
	assert_float(speed).is_equal_approx(CONFIG.walk_speed * 0.6, 0.01)


func test_both_disabled_legs_force_a_crawl() -> void:
	await _load()
	await _driver.place(Vector3.ZERO)
	_player.body.take_damage(&"damage.blunt", 100.0, &"leg_l")
	_player.body.take_damage(&"damage.blunt", 100.0, &"leg_r")

	_driver.runner.simulate_action_press(&"sprint")
	var speed := await _walk_speed(&"move_back", 60)
	_driver.runner.simulate_action_release(&"sprint")

	assert_bool(_player.crouched).is_true()
	assert_float(speed).is_equal_approx(1.0, 0.01)
	assert_bool((_player.get_node("Tags") as Tags).has(&"state.legs_disabled")).is_true()
	await _driver.frames(10)
	assert_bool(_player.crouched).is_true()


func test_explosion_damages_parts_by_the_distribution() -> void:
	await _load()
	await _driver.place(Vector3.ZERO)
	var barrel := Objects.spawn(_driver.runner.scene(), Objects.EXPLOSIVE_BARREL, Vector3(0, 0.45, -2))
	await _driver.frames(10)
	EventLog.clear()

	Explosive.of(barrel).explode()
	await _driver.frames(3)

	var received := EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool:
			return entry.data["type"] == &"damage.explosive" and entry.target == "Player"
	)
	assert_array(received).has_size(1)
	var perceived: float = received[0].data["perceived"]
	assert_float(perceived).is_greater(40.0)
	var damaged := EventLog.find(&"actor.damaged")
	assert_array(damaged).has_size(6)
	for entry in damaged:
		var share := 0.4 if entry.data["part"] == &"torso" else 0.12
		assert_float(entry.data["amount"]).is_equal_approx(perceived * share, 0.001)
		assert_str(entry.data["type"]).is_equal("damage.explosive")
	assert_float(_player.body.health(&"torso")).is_equal_approx(100.0 - perceived * 0.4, 0.001)


func test_fall_from_5_m_damages_both_legs() -> void:
	await _load()
	_player.load_state(PlayerDriver.state(Vector3(3, 5, 3), 0.0))

	await _driver.frames(60)

	var landed := EventLog.find(&"player.landed")
	assert_array(landed).has_size(1)
	var impact: float = landed[0].data["impact_speed"]
	assert_float(impact).is_equal_approx(14.0, 0.4)
	var expected := (impact - 10.0) * 8.0
	for leg: StringName in [&"leg_l", &"leg_r"]:
		var hits := Objects.logged(&"actor.damaged", "part", leg)
		assert_array(hits).has_size(1)
		assert_str(hits[0].data["type"]).is_equal("damage.fall")
		assert_float(_player.body.health(leg)).is_equal_approx(70.0 - expected, 0.001)
	assert_float(expected).is_equal_approx(32.0, 3.5)


func test_short_fall_does_not_hurt() -> void:
	await _load()
	_player.load_state(PlayerDriver.state(Vector3(3, 2, 3), 0.0))

	await _driver.frames(40)

	assert_array(EventLog.find(&"player.landed")).has_size(1)
	assert_array(EventLog.find(&"actor.damaged")).is_empty()


func test_death_disables_input_and_shows_the_overlay() -> void:
	await _load()
	await _driver.place(Vector3.ZERO)
	var hud := _player.get_node("Hud") as Hud
	assert_bool(hud.death_overlay.visible).is_false()
	await _driver.hold(&"belt_1", 2)

	_player.body.take_damage(&"damage.ballistic", 30.0, &"head")
	await _driver.frames(1)

	assert_bool(_player.is_dead()).is_true()
	assert_array(EventLog.find(&"actor.died")).has_size(1)
	assert_bool(hud.death_overlay.visible).is_true()
	assert_bool(_player.weapons.is_armed()).is_false()
	await _driver.hold(&"move_forward", 30)
	assert_float(_player.global_position.distance_to(Vector3.ZERO)).is_less(0.01)
	await _driver.hold(&"belt_1", 2)
	assert_bool(_player.weapons.is_armed()).is_false()

	_player.reload_on_reset = false
	var resets: Array[int] = [0]
	_player.reset_requested.connect(func() -> void: resets[0] += 1)
	await _driver.hold(&"use", 2)
	assert_int(resets[0]).is_equal(1)


func test_medkit_heals_and_frees_itself() -> void:
	await _load()
	var medkit := Objects.spawn(_driver.runner.scene(), MEDKIT, Vector3(0, 0.06, -1.2))
	await _driver.frames(10)
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, medkit.global_position))
	await _driver.frames(5)
	_player.body.take_damage(&"damage.blunt", 40.0, &"torso")
	_player.body.take_damage(&"damage.blunt", 4.0, &"head")
	EventLog.clear()

	await _driver.hold(&"use", 2)
	await _driver.frames(1)

	assert_bool(is_instance_valid(medkit)).is_false()
	assert_bool(_player.carry.is_carrying()).is_false()
	var healed := EventLog.find(&"actor.healed")
	assert_array(healed).has_size(1)
	assert_float(healed[0].data["amount"]).is_equal_approx(30.0, 0.001)
	assert_float(_player.body.health(&"head")).is_equal_approx(60.0, 0.001)
	assert_float(_player.body.health(&"torso")).is_equal_approx(86.0, 0.001)


func test_medkit_is_kept_at_full_health() -> void:
	await _load()
	var medkit := Objects.spawn(_driver.runner.scene(), MEDKIT, Vector3(0, 0.06, -1.2))
	await _driver.frames(10)
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, medkit.global_position))
	await _driver.frames(5)
	EventLog.clear()

	await _driver.hold(&"use", 2)
	await _driver.frames(1)

	assert_bool(is_instance_valid(medkit)).is_true()
	assert_array(EventLog.find(&"item.use_refused")).has_size(1)
	assert_array(EventLog.find(&"player.picked_up")).is_empty()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()


func _walk_speed(action: StringName, count: int) -> float:
	_driver.runner.simulate_action_press(action)
	await _driver.frames(count)
	var speed := _player.horizontal_speed()
	_driver.runner.simulate_action_release(action)
	return speed
