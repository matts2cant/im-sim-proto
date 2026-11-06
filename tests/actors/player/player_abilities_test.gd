extends GdUnitTestSuite
## Integration: the player's augmentations through the real input (F1-F5) and the generic
## consumers: Speed Enhancement (sprint 9 m/s, mantles a 2.3 m ledge), Run Silent (no footstep noise
## sprinting on metal), Combat Strength (F5: 60 kg crate while on, dropped when it goes off),
## Regeneration, Cloak feedback and the HUD (ADR 0061).

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

	assert_array(_hud.chip_texts()).is_empty()
	await _press(&"aug_1")
	await _press(&"aug_3")
	await _press(&"aug_5")
	assert_bool(_player.augmentations.is_active(&"cloak")).is_true()
	assert_bool(_player.augmentations.is_active(&"speed_enhancement")).is_true()
	assert_bool(_player.augmentations.is_active(&"combat_strength")).is_true()
	assert_array(_hud.chip_texts()).is_equal(["F1 Cloak", "F3 Speed Enhancement", "F5 Combat Strength"])

	await _press(&"aug_1")
	assert_bool(_player.augmentations.is_active(&"cloak")).is_false()
	assert_array(_hud.chip_texts()).is_equal(["F3 Speed Enhancement", "F5 Combat Strength"])
	assert_array(EventLog.find(&"augmentation.activated")).has_size(3)
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


func test_f6_combat_strength_lifts_the_large_crate_only_while_on() -> void:
	await _load(ROOM)
	var crate := _spawn(Objects.LARGE_CRATE, Vector3(0, 0.6, -1.6))
	await _driver.frames(20)
	assert_float(_player.carry.mass_limit()).is_equal_approx(20.0, 0.001)

	assert_bool(_player.carry.try_pick_up_body(crate)).is_false()
	assert_array(EventLog.find(&"player.pickup_refused")).has_size(1)
	await _press(&"aug_5")
	assert_float(_player.carry.mass_limit()).is_equal_approx(70.0, 0.001)
	assert_bool(_player.carry.try_pick_up_body(crate)).is_true()
	assert_object(_player.carry.held).is_same(crate)


func test_combat_strength_drains_1_energy_per_second() -> void:
	await _load(METAL)
	await _press(&"aug_5")
	await _driver.frames(120)

	# About 2 s at 1/s (plus the press frames): 98 give or take a few ticks, nowhere near 97 or 99.
	assert_float(_player.energy.current()).is_between(97.6, 98.2)


func test_switching_combat_strength_off_drops_a_heavy_crate_with_a_message() -> void:
	await _load(ROOM)
	var crate := _spawn(Objects.LARGE_CRATE, Vector3(0, 0.6, -1.6))
	await _driver.frames(20)
	await _press(&"aug_5")
	assert_bool(_player.carry.try_pick_up_body(crate)).is_true()
	await _driver.frames(10)

	await _press(&"aug_5")

	assert_bool(_player.carry.is_carrying()).is_false()
	assert_str(_hud.message_label.text).is_equal(PlayerCarry.TOO_HEAVY)
	var dropped := EventLog.find(&"player.dropped")
	assert_array(dropped).has_size(1)
	assert_str(String(dropped[0].data["how"])).is_equal("too_heavy")
	assert_int(crate.collision_layer).is_not_equal(0)


func test_running_out_of_energy_drops_a_heavy_crate_but_keeps_a_light_one() -> void:
	await _load(ROOM)
	var crate := _spawn(Objects.LARGE_CRATE, Vector3(0, 0.6, -1.6))
	await _driver.frames(20)
	_player.energy.set_current(0.5)
	await _press(&"aug_5")
	assert_bool(_player.carry.try_pick_up_body(crate)).is_true()

	# 0.5 energy at 1/s: empty after 30 ticks.
	await _driver.frames(45)

	assert_bool(_player.augmentations.is_active(&"combat_strength")).is_false()
	assert_bool(_player.carry.is_carrying()).is_false()
	assert_str(String(EventLog.find(&"player.dropped")[0].data["how"])).is_equal("too_heavy")

	# A 20 kg-or-lighter object stays held when Combat Strength goes off.
	_player.energy.set_current(50.0)
	var small := _spawn(Objects.SMALL_CRATE, Vector3(1.5, 0.3, -1.6))
	await _driver.frames(20)
	await _press(&"aug_5")
	assert_bool(_player.carry.try_pick_up_body(small)).is_true()
	await _press(&"aug_5")
	await _driver.frames(5)
	assert_object(_player.carry.held).is_same(small)


func test_regeneration_heals_the_player_and_costs_energy() -> void:
	await _load(METAL)
	_player.body.take_damage(&"damage.ballistic", 30.0, &"leg_l")
	var hurt := _player.body.health(&"leg_l")

	await _press(&"aug_4")
	await _driver.frames(75)

	assert_float(_player.body.health(&"leg_l")).is_greater(hurt + 3.5)
	assert_float(_player.energy.current()).is_less(95.0)


func _spawn(path: String, position: Vector3) -> RigidBody3D:
	return Objects.spawn(_driver.runner.scene(), path, position) as RigidBody3D


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
