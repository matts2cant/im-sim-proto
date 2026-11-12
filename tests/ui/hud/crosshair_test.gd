extends GdUnitTestSuite
## The HUD crosshair (Deus Ex style, user request 2026-11-12, ADR 0123):
## - Unit: each arm's inner end sits on the cone radius it is given and moves with the offset; the
##   arms keep their length (scaled with the viewport height); thin arms (1 px at 1080 p, never
##   under 1 px); a cone of 0 keeps the arms at the minimum gap (playtest 2026-11-12); melee or
##   holstered: the dot only. The pistol at Master standing still keeps its four arms.
## - Integration (tests/items/weapons/fixtures/weapon_range.tscn: the player, a training dummy and a
##   long floor; centre to centre from the player's feet): the arms get their caps when the aim is
##   on the dummy within the weapon's range (pistol at 10 m), not on the plain floor, nor on the
##   dummy past the weapon's range (the submachine gun's 40 m, dummy at 50 m).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const RANGE := "res://tests/items/weapons/fixtures/weapon_range.tscn"
const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")
const SMG: ItemData = preload("res://items/weapons/smg/smg_item.tres")

var _driver: PlayerDriver
var _player: Player
var _hud: Hud
var _target: TrainingDummy


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_arm_inner_ends_follow_the_cone_radius() -> void:
	var reticle := auto_free(Reticle.new()) as Reticle
	reticle.size = Vector2(1920, 1080)
	assert_array(reticle.arm_segments()).is_empty()
	for radius: float in [8.0, 37.0]:
		reticle.show_cone(radius, Vector2(4, -3), true)
		# The aim point is the moved centre on its pixel's centre.
		assert_vector(reticle.aim_point()).is_equal(Vector2(964.5, 537.5))
		var arms := reticle.arm_segments()
		assert_int(arms.size()).is_equal(4)
		for arm in arms:
			assert_float(arm[0].distance_to(reticle.aim_point())).is_equal_approx(radius, 0.001)
			assert_float(arm[0].distance_to(arm[1])).is_equal_approx(Reticle.ARM_LENGTH_1080, 0.001)
	# Half the height: half the arm length.
	reticle.size = Vector2(960, 540)
	assert_float(reticle.arm_length()).is_equal_approx(Reticle.ARM_LENGTH_1080 * 0.5, 0.001)


func test_thin_arms_scale_with_the_height_but_never_under_1_px() -> void:
	# Playtest 2026-11-12: 1 px arms at 1080 p (were 2 px) with a 0.5 px edge (was 1 px).
	assert_float(Reticle.arm_width_for(1080.0)).is_equal_approx(1.0, 0.001)
	assert_float(Reticle.arm_width_for(2160.0)).is_equal_approx(2.0, 0.001)
	assert_float(Reticle.arm_width_for(648.0)).is_equal_approx(1.0, 0.001)
	assert_float(Reticle.OUTLINE).is_equal_approx(0.5, 0.001)
	assert_float(Reticle.SHADOW.a).is_less_equal(0.5)


func test_a_cone_of_0_keeps_the_arms_at_the_minimum_gap() -> void:
	# A Master standing still: radius 0; the arms stay, clear of the dot (5 px at 1080 p, 3 px at 648).
	var reticle := auto_free(Reticle.new()) as Reticle
	reticle.size = Vector2(1920, 1080)
	reticle.show_cone(0.0, Vector2.ZERO, true)
	var arms := reticle.arm_segments()
	assert_int(arms.size()).is_equal(4)
	for arm in arms:
		assert_float(arm[0].distance_to(reticle.aim_point())).is_equal_approx(5.0, 0.001)
		assert_float(arm[0].distance_to(arm[1])).is_equal_approx(Reticle.ARM_LENGTH_1080, 0.001)
	assert_float(Reticle.inner_radius(0.0, 648.0)).is_equal_approx(3.0, 0.001)
	# The gap is wider than the dot and its edge.
	assert_float(Reticle.inner_radius(0.0, 648.0)).is_greater(Reticle.MIN_DOT_RADIUS + Reticle.OUTLINE + 1.0)
	# A cone wider than the gap: the arms on the cone.
	reticle.show_cone(2.0, Vector2.ZERO, true)
	assert_float(reticle.arm_segments()[0][0].distance_to(reticle.aim_point())).is_equal_approx(5.0, 0.001)


func test_melee_or_holstered_shows_the_dot_only() -> void:
	var reticle := auto_free(Reticle.new()) as Reticle
	reticle.size = Vector2(1920, 1080)
	reticle.show_cone(0.0, Vector2.ZERO, false)
	assert_array(reticle.arm_segments()).is_empty()


func test_master_standing_still_keeps_the_crosshair() -> void:
	# The user's case: the pistol at Master, standing still: a cone of exactly 0, four arms.
	await _load(PISTOL)
	_player.skills.set_tier(&"pistols", 3)
	await _aim_at(Vector3(0, 0, -5))
	assert_float(_hud.reticle.radius).is_equal(0.0)
	assert_bool(_hud.reticle.ranged).is_true()
	assert_int(_hud.reticle.arm_segments().size()).is_equal(4)


func test_caps_on_a_damageable_target_in_range_only() -> void:
	await _load(PISTOL)
	await _place_target(10.0)
	await _aim_at(_target.hitboxes.box(&"torso").global_position)
	assert_bool(_hud.reticle.on_target).is_true()
	# The plain floor 5 m ahead: not something a weapon damages.
	await _aim_at(Vector3(0, 0, -5))
	assert_bool(_hud.reticle.on_target).is_false()


func test_no_caps_past_the_weapon_range() -> void:
	await _load(SMG)
	await _place_target(50.0)
	await _aim_at(_target.hitboxes.box(&"torso").global_position)
	assert_bool(_hud.reticle.on_target).is_false()
	await _place_target(30.0)
	await _aim_at(_target.hitboxes.box(&"torso").global_position)
	assert_bool(_hud.reticle.on_target).is_true()


func test_damageable_means_a_hitbox_body_parts_or_breakable() -> void:
	await _load(PISTOL)
	assert_bool(Reticle.is_target(_target.hitboxes.box(&"torso"))).is_true()
	assert_bool(Reticle.is_target(_target)).is_true()
	assert_bool(Reticle.is_target(_driver.runner.find_child("Floor"))).is_false()
	assert_bool(Reticle.is_target(null)).is_false()


func _place_target(distance: float) -> void:
	_target.reset()
	_target.position = Vector3(0, 0, -distance)
	await _driver.frames(3)


func _aim_at(point: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, point))
	await _driver.frames(5)
	_player.weapons.settle()
	_hud.refresh_reticle()


func _load(item: ItemData) -> void:
	_driver = PlayerDriver.new(scene_runner(RANGE))
	_player = _driver.player
	_hud = _player.get_node("Hud") as Hud
	_target = _driver.runner.find_child("Target") as TrainingDummy
	await _driver.settle()
	var inventory := _player.inventory
	inventory.give(item, 1)
	inventory.give(inventory.catalog.find(item.weapon.ammo_item), 30)
	inventory.select_slot(0)
	await _driver.frames(2)
