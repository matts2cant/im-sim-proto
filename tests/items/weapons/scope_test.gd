extends GdUnitTestSuite
## Integration (ADR 0085): the sniper rifle's scope on the player. RMB (`alt_fire`) toggles it: the
## camera zooms 80 -> 15 degrees over about 0.15 s, the HUD scope overlay replaces the reticle, the
## view model hides, mouse look turns 15/80 as far per pixel; RMB again scopes out. It also scopes
## out on reload, switching weapon, putting it away and when the player cannot act, and RMB does
## nothing with a weapon that has no scope. The game keeps running (no pause).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")
const SNIPER: ItemData = preload("res://items/weapons/sniper_rifle/sniper_rifle_item.tres")
const SNIPER_AMMO: ItemData = preload("res://items/sniper_rounds/sniper_rounds.tres")

var _driver: PlayerDriver
var _player: Player
var _hud: Hud
var _camera: Camera3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_rmb_toggles_the_scope_zoom_overlay_and_view_model() -> void:
	await _load()

	await _driver.press(&"alt_fire")
	assert_bool(_player.weapons.scope.scoped).is_true()
	assert_bool(get_tree().paused).is_false()
	await _driver.frames(10)
	assert_float(_camera.fov).is_equal_approx(15.0, 0.01)
	_hud.refresh_reticle()
	assert_bool(_hud.scope_overlay.visible).is_true()
	assert_bool(_hud.reticle.visible).is_false()
	assert_bool(_player.weapons.view_pivot().visible).is_false()
	assert_float(_player.weapons.aim.config.base_min_deg).is_equal(0.2)

	await _driver.press(&"alt_fire")
	assert_bool(_player.weapons.scope.scoped).is_false()
	await _driver.frames(10)
	assert_float(_camera.fov).is_equal_approx(80.0, 0.01)
	_hud.refresh_reticle()
	assert_bool(_hud.scope_overlay.visible).is_false()
	assert_bool(_hud.reticle.visible).is_true()
	assert_bool(_player.weapons.view_pivot().visible).is_true()
	assert_float(_player.weapons.aim.config.base_min_deg).is_equal(6.0)


func test_zoom_takes_about_0_15_s() -> void:
	await _load()
	await _driver.press(&"alt_fire")
	# The press tick plus the next: 3 of the 9 zoom ticks done, the FOV part way.
	assert_float(_camera.fov).is_between(15.5, 79.0)


func test_mouse_look_scales_with_the_zoom() -> void:
	await _load()
	var yaw := _player.rotation.y
	_player.look(Vector2(100, 0))
	var hip_turn := absf(_player.rotation.y - yaw)
	await _driver.press(&"alt_fire")
	await _driver.frames(10)
	yaw = _player.rotation.y
	_player.look(Vector2(100, 0))
	assert_float(absf(_player.rotation.y - yaw)).is_equal_approx(hip_turn * 15.0 / 80.0, 0.0001)


func test_reload_switch_and_holster_scope_out() -> void:
	await _load()
	_player.inventory.give(PISTOL, 1)

	await _scope_in()
	_player.weapons.state().magazine = 2
	await _driver.press(&"reload")
	assert_bool(_player.weapons.scope.scoped).is_false()
	# RMB during the reload is refused.
	await _driver.press(&"alt_fire")
	assert_bool(_player.weapons.scope.scoped).is_false()
	await _driver.frames(ceili(SNIPER.weapon.reload_time * 60.0) + 2)

	await _scope_in()
	await _driver.press(&"belt_2")
	assert_str(_player.weapons.weapon().id).is_equal("pistol")
	assert_bool(_player.weapons.scope.scoped).is_false()
	await _driver.frames(1)
	assert_float(_camera.fov).is_equal(80.0)

	await _driver.press(&"belt_1")
	await _scope_in()
	await _driver.press(&"holster")
	assert_bool(_player.weapons.scope.scoped).is_false()
	assert_float(_camera.fov).is_equal(80.0)


func test_scopes_out_when_the_player_cannot_act() -> void:
	await _load()
	await _scope_in()

	(_player.get_node("Tags") as Tags).add(ActorState.UNCONSCIOUS)
	await _driver.frames(2)

	assert_bool(_player.weapons.scope.scoped).is_false()
	(
		assert_array(
			EventLog.find(&"weapon.scoped").filter(func(e: EventLogEntry) -> bool: return e.data["reason"] == "auto")
		)
		. has_size(1)
	)


func test_rmb_does_nothing_with_a_weapon_without_a_scope() -> void:
	await _load()
	_player.inventory.give(PISTOL, 1)
	await _driver.press(&"belt_2")

	await _driver.press(&"alt_fire")

	assert_bool(_player.weapons.scope.scoped).is_false()
	assert_float(_camera.fov).is_equal(80.0)


func _scope_in() -> void:
	await _driver.press(&"alt_fire")
	await _driver.frames(10)
	assert_bool(_player.weapons.scope.scoped).is_true()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_hud = _player.get_node("Hud") as Hud
	_camera = _player.get_node("Head/Camera") as Camera3D
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
	_player.inventory.give(SNIPER, 1)
	_player.inventory.give(SNIPER_AMMO, 20)
	await _driver.press(&"belt_1")
	EventLog.clear()
