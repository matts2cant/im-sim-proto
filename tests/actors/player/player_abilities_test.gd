extends GdUnitTestSuite
## Integration: the player's augmentations through the real input (F1-F4) and the generic consumers:
## Speed Enhancement (sprint 9 m/s, mantles a 2.3 m ledge), Run Silent (no footstep noise sprinting on
## metal), Combat Strength (60 kg crate), Regeneration, Cloak feedback and the HUD (ADR 0061).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const METAL := "res://tests/actors/player/fixtures/metal_floor.tscn"
const OBSTACLES := "res://tests/actors/player/fixtures/obstacles.tscn"
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver
var _player: Player
var _hud: Hud


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_f_keys_toggle_augmentations_and_the_hud_shows_chips() -> void:
	await _load(METAL)

	await _press(&"aug_1")
	await _press(&"aug_3")
	assert_bool(_player.augmentations.is_active(&"cloak")).is_true()
	assert_bool(_player.augmentations.is_active(&"speed_enhancement")).is_true()
	assert_array(_hud.chip_texts()).is_equal(["F1 Cloak", "F3 Speed Enhancement", "Combat Strength"])

	await _press(&"aug_1")
	assert_bool(_player.augmentations.is_active(&"cloak")).is_false()
	assert_array(_hud.chip_texts()).is_equal(["F3 Speed Enhancement", "Combat Strength"])
	assert_array(EventLog.find(&"augmentation.activated")).has_size(2)
	assert_array(EventLog.find(&"augmentation.deactivated")).has_size(1)


func test_cloak_tints_the_screen_and_makes_the_view_model_translucent() -> void:
	await _load(METAL)
	Items.arm(_player)
	await _press(&"belt_1")
	var material := _view_material()
	assert_int(material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_DISABLED)

	await _press(&"aug_1")
	await _driver.frames(2)

	assert_bool((_player.get_node("Tags") as Tags).has(&"state.cloaked")).is_true()
	assert_bool(_hud.cloak_tint.visible).is_true()
	assert_int(material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_float(material.albedo_color.a).is_less(0.5)

	await _press(&"aug_1")
	await _driver.frames(2)
	assert_bool(_hud.cloak_tint.visible).is_false()
	assert_float(material.albedo_color.a).is_equal(1.0)


func test_toggling_with_no_energy_shows_energy_depleted() -> void:
	await _load(METAL)
	_player.energy.set_current(0.0)

	await _press(&"aug_2")

	assert_bool(_player.augmentations.is_active(&"run_silent")).is_false()
	assert_str(_hud.message_label.text).is_equal("Energy depleted")
	assert_str(_hud.energy_label.text).is_equal("0")


func test_energy_bar_follows_the_drain() -> void:
	await _load(METAL)
	assert_str(_hud.energy_label.text).is_equal("100")

	await _press(&"aug_1")
	await _driver.frames(150)

	# Cloak: 4/s for about 2.5 s.
	assert_float(_player.energy.current()).is_between(88.0, 92.0)
	assert_float(_hud.energy_bar.fraction()).is_between(0.88, 0.92)


func test_speed_enhancement_sprints_at_9_metres_per_second() -> void:
	await _load(METAL)
	await _press(&"aug_3")
	_driver.runner.simulate_action_press(&"sprint")
	_driver.runner.simulate_action_press(&"move_forward")

	await _driver.frames(40)
	var speed := _player.horizontal_speed()
	_driver.runner.simulate_action_release(&"move_forward")
	_driver.runner.simulate_action_release(&"sprint")

	assert_float(speed).is_equal_approx(9.0, 0.05)


func test_run_silent_sprinting_on_metal_makes_no_footstep_noise() -> void:
	await _load(METAL)
	await _sprint(90)
	var loud := EventLog.find(&"actor.footstep").size()
	await _driver.place(Vector3.ZERO)
	StimulusSystem.clear()
	await _press(&"aug_2")
	EventLog.clear()

	await _sprint(90)

	assert_int(loud).is_greater(1)
	assert_array(EventLog.find(&"actor.footstep")).is_empty()
	var noise := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise"
	)
	assert_array(noise).is_empty()


func test_speed_enhancement_mantles_the_2_3_metre_ledge() -> void:
	await _load(OBSTACLES)
	await _driver.place(Vector3(10, 0, -1.4))
	await _press(&"aug_3")

	await _driver.hold(&"jump", 50)
	await _driver.frames(30)

	var mantled := EventLog.find(&"player.mantled")
	assert_array(mantled).has_size(1)
	assert_float(mantled[0].data["height"]).is_equal_approx(2.3, 0.02)
	assert_float(_player.global_position.y).is_equal_approx(2.3, 0.02)


func test_without_speed_the_2_3_metre_ledge_is_refused() -> void:
	await _load(OBSTACLES)
	await _driver.place(Vector3(10, 0, -1.4))

	await _driver.hold(&"jump", 50)
	await _driver.frames(40)

	assert_array(EventLog.find(&"player.mantled")).is_empty()
	assert_float(_player.global_position.y).is_less(0.05)


func test_combat_strength_lifts_the_large_crate_and_is_refused_without_it() -> void:
	await _load(ROOM)
	var crate := Objects.spawn(_driver.runner.scene(), Objects.LARGE_CRATE, Vector3(0, 0.6, -1.6)) as RigidBody3D
	await _driver.frames(20)
	_player.augmentations.set_installed(&"combat_strength", false)

	assert_bool(_player.carry.try_pick_up_body(crate)).is_false()
	assert_array(EventLog.find(&"player.pickup_refused")).has_size(1)
	_player.augmentations.set_installed(&"combat_strength", true)
	assert_bool(_player.carry.try_pick_up_body(crate)).is_true()
	assert_object(_player.carry.held).is_same(crate)
	assert_float(_player.carry.mass_limit()).is_equal_approx(70.0, 0.001)


func test_regeneration_heals_the_player_and_costs_energy() -> void:
	await _load(METAL)
	_player.body.take_damage(&"damage.ballistic", 30.0, &"leg_l")
	var hurt := _player.body.health(&"leg_l")

	await _press(&"aug_4")
	await _driver.frames(75)

	assert_float(_player.body.health(&"leg_l")).is_greater(hurt + 3.5)
	assert_float(_player.energy.current()).is_less(95.0)


func _view_material() -> StandardMaterial3D:
	var view := _player.weapons.view_pivot().get_node("ViewModel") as MeshInstance3D
	return (view.mesh as BoxMesh).material as StandardMaterial3D


func _sprint(frames: int) -> void:
	_driver.runner.simulate_action_press(&"sprint")
	_driver.runner.simulate_action_press(&"move_forward")
	await _driver.frames(frames)
	_driver.runner.simulate_action_release(&"move_forward")
	_driver.runner.simulate_action_release(&"sprint")
	await _driver.frames(10)


func _press(action: StringName) -> void:
	await _driver.hold(action, 2)
	await _driver.frames(1)


func _load(scene: String) -> void:
	_driver = PlayerDriver.new(scene_runner(scene))
	_player = _driver.player
	_hud = _player.get_node("Hud") as Hud
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
