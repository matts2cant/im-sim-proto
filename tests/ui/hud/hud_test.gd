extends GdUnitTestSuite
## Integration: the player's HUD (reticle = aim cone, ammo and weapon name, silhouette, damage flash,
## "ALARM" while the player hears a siren).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Weapons := preload("res://tests/items/weapons/weapon_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const WALL_POINT := Vector3(0, 1.5, -5.8)
const SIREN_SCENE: PackedScene = preload("res://objects/alarm/siren.tscn")

var _driver: PlayerDriver
var _weapons: Weapons
var _player: Player
var _hud: Hud


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_reticle_is_the_cone_at_rest_and_while_sprinting() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)
	var height := _hud.get_viewport().get_visible_rect().size.y

	await _driver.frames(2)
	assert_float(_hud.reticle.radius).is_equal_approx(AimModel.reticle_radius(0.5, 80.0, height), 0.01)

	_driver.runner.simulate_action_press(&"sprint")
	_driver.runner.simulate_action_press(&"move_back")
	_driver.runner.simulate_action_press(&"move_forward")
	_driver.runner.simulate_action_release(&"move_back")
	await _driver.frames(20)
	var sprinting := _hud.reticle.radius
	_driver.runner.simulate_action_release(&"move_forward")
	_driver.runner.simulate_action_release(&"sprint")

	assert_int(_player.aim_stance()).is_equal(AimModel.Stance.SPRINT)
	assert_float(sprinting).is_equal_approx(AimModel.reticle_radius(6.5, 80.0, height), 0.01)


func test_no_cone_holstered_or_with_the_baton() -> void:
	await _load()
	await _driver.frames(2)
	assert_float(_hud.reticle.radius).is_equal(0.0)

	await _weapons.equip(2)
	await _driver.frames(2)
	assert_float(_hud.reticle.radius).is_equal(0.0)
	assert_str(_hud.weapon_label.text).is_equal("Stun baton")
	assert_str(_hud.ammo_label.text).is_equal("")


func test_ammo_and_weapon_name() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)
	await _driver.frames(1)
	assert_str(_hud.weapon_label.text).is_equal("Pistol")
	assert_str(_hud.ammo_label.text).is_equal("10 / 30")

	await _weapons.fire()

	assert_str(_hud.ammo_label.text).is_equal("9 / 30")


func test_damage_flashes_and_colours_the_silhouette() -> void:
	await _load()
	assert_float(_hud.flash_alpha()).is_equal(0.0)
	assert_object(_hud.silhouette.part_color(&"leg_l")).is_equal(HudRules.HEALTHY)

	_player.body.take_damage(&"damage.blunt", 35.0, &"leg_l")
	await _driver.frames(1)

	assert_float(_hud.flash_alpha()).is_greater(0.2)
	assert_object(_hud.silhouette.part_color(&"leg_l")).is_equal(HudRules.HURT)
	_player.body.take_damage(&"damage.blunt", 35.0, &"leg_l")
	assert_object(_hud.silhouette.part_color(&"leg_l")).is_equal(HudRules.DISABLED)
	await _driver.frames(40)
	assert_float(_hud.flash_alpha()).is_equal(0.0)


func test_alarm_shows_while_the_player_hears_a_siren() -> void:
	await _load()
	await _driver.frames(2)
	assert_bool(_hud.alarm_label.visible).is_false()
	var siren := SIREN_SCENE.instantiate() as Node3D
	siren.name = "TestSiren"
	_player.get_parent().add_child(siren)
	siren.global_position = _player.global_position + Vector3(0, 2, -3)
	# Heard through the player's own receiver (`heard_siren`), like any guard.
	StimulusSystem.emit(Device.command_stimulus(Device.TEST, siren))
	await _driver.frames(10)
	assert_bool(AlarmHearing.of(_player).is_hearing()).is_true()
	assert_bool(_hud.alarm_label.visible).is_true()

	# A test rings 3 s (pulses at 0, 1, 2 s); hearing lasts 1.5 s after the last pulse.
	await _driver.frames(250)
	assert_bool(AlarmHearing.of(_player).is_hearing()).is_false()
	assert_bool(_hud.alarm_label.visible).is_false()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_weapons = Weapons.new(_driver)
	_player = _driver.player
	_hud = _player.get_node("Hud") as Hud
	await _driver.settle()
