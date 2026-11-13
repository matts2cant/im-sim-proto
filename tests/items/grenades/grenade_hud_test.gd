extends GdUnitTestSuite
## Integration (ADR 0131): the player with frag grenades in the grenade room (a wall face 1.0 m
## ahead along -Z, another 3.0 m behind along +Z, open floor along -X). The HUD shows how many are
## left and a throw (LMB) takes one; the ghost shows near the wall and not at 3 m; the fuse readout
## shows at Demolition Master only; an armed mine within 8 m is highlighted from Advanced, and the
## frame names it with "Armed".

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/items/grenades/fixtures/grenade_room.tscn"
const FRAG: ItemData = preload("res://items/grenades/frag/frag_grenade_item.tres")

var _driver: PlayerDriver
var _player: Player
var _hud: Hud


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_hud_counts_grenades_and_each_throw_takes_one() -> void:
	await _load(PI * 0.5)
	_player.inventory.give(FRAG, 3)
	await _press(&"belt_1")
	_hud.refresh_weapon()
	assert_str(_hud.weapon_label.text).is_equal("Frag grenade")
	assert_str(_hud.ammo_label.text).is_equal("x3")

	await _press(&"fire")
	_hud.refresh_weapon()

	assert_str(_hud.ammo_label.text).is_equal("x2")
	assert_str(_player.weapons.weapon().id).is_equal("frag_grenade")
	await _driver.frames(50)
	await _press(&"fire")
	await _driver.frames(50)
	await _press(&"fire")
	# The last one thrown: empty hands, none left.
	assert_bool(_player.weapons.is_armed()).is_false()
	assert_int(EventLog.find(&"thrower.thrown").size()).is_equal(3)
	for stack in _player.inventory.inventory.stacks:
		assert_object(stack.item).is_not_same(FRAG)


func test_ghost_shows_near_a_wall_and_not_three_metres_away() -> void:
	await _load(0.0)
	_player.inventory.give(FRAG, 1)
	await _press(&"belt_1")
	var thrower := Thrower.of(_player)

	assert_bool(thrower.ghost_visible()).is_true()
	assert_float(thrower._ghost.global_position.z).is_equal_approx(-1.0 + 0.053, 0.01)

	_player.load_state(PlayerDriver.state(Vector3.ZERO, PI))
	await _driver.frames(2)
	assert_bool(thrower.ghost_visible()).is_false()


func test_fuse_readout_shows_at_master_only() -> void:
	await _load(PI * 0.5)
	_player.inventory.give(FRAG, 2)
	await _press(&"belt_1")
	await _press(&"fire")
	_hud.refresh_fuse()
	assert_bool(_hud.fuse_label.visible).is_false()

	_player.skills.set_tier(&"demolition", SkillTable.MASTER)
	_hud.refresh_fuse()

	assert_bool(_hud.fuse_label.visible).is_true()
	var left := Thrower.of(_player).fuse_left()
	assert_float(left).is_between(1.5, 2.5)
	assert_str(_hud.fuse_label.text).is_equal(HudRules.fuse_text(left))


func test_advanced_highlights_an_armed_mine_and_the_frame_says_armed() -> void:
	await _load(0.0)
	_player.inventory.give(FRAG, 1)
	await _press(&"belt_1")
	await _press(&"fire")
	var mine := _mine()
	assert_bool(Sticky.of(mine).is_stuck).is_true()
	# Crouch and back off to 1.6 m (centre to wall face) before it arms, looking at it.
	_driver.runner.simulate_action_press(&"crouch")
	var eye := Vector3(0, _player.config.crouched_eye_height, 0.6)
	var to := mine.global_position - eye
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	_player.load_state({"position": Vector3(0, 0, 0.6), "yaw": 0.0, "pitch": pitch, "crouched": true})
	await _driver.frames(130)
	var trigger := ProximityTrigger.of(mine)
	assert_bool(trigger.is_armed).is_true()
	var sense := _player.get_node("MineSense") as MineSense
	sense.refresh()
	assert_bool(trigger.is_highlighted()).is_false()

	_player.skills.set_tier(&"demolition", 2)
	sense.refresh()

	assert_bool(trigger.is_highlighted()).is_true()
	_hud.target_frame.refresh(_player)
	assert_str(_hud.target_frame.name_text()).is_equal("Frag grenade")
	assert_str(_hud.target_frame.status_text()).is_equal("Armed")
	_driver.runner.simulate_action_release(&"crouch")


func _mine() -> RigidBody3D:
	for child in _driver.runner.scene().get_children():
		if child is RigidBody3D and Sticky.of(child) != null:
			return child as RigidBody3D
	return null


func _press(action: StringName) -> void:
	await _driver.hold(action, 2)
	await _driver.frames(1)


func _load(yaw: float) -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_hud = _player.get_node("Hud") as Hud
	await _driver.settle()
	await _driver.place(Vector3.ZERO, yaw)
