extends GdUnitTestSuite
## Unit/integration (ADR 0101): WeaponHolder.view_shift_deg lowers (and moves right) every weapon's
## first-person view model by one screen angle, whatever its depth; recoil and the baton's swing run
## from the shifted rest pose. The player's holder sets a downward shift; guards keep zero (the gun
## they hold does not move).

const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const SHOTGUN: WeaponData = preload("res://items/weapons/shotgun/shotgun.tres")
const SNIPER: WeaponData = preload("res://items/weapons/sniper_rifle/sniper_rifle.tres")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const SHIFT := Vector2(3.0, 9.0)

var _holder: WeaponHolder


func before_test() -> void:
	_holder = auto_free(WeaponHolder.new())
	_holder.aim_config = AimConfig.new()
	_holder.weapons = [BATON, PISTOL, SHOTGUN, SNIPER, RIFLE] as Array[WeaponData]
	_holder.view_shift_deg = SHIFT
	add_child(_holder)
	_holder.setup(null, null)


func test_every_weapon_moves_by_the_same_screen_angle() -> void:
	for index in _holder.weapons.size():
		_holder.equip(index)
		var data := _holder.weapon()
		var pivot := _holder.view_pivot().position
		var depth := -data.view_offset.z
		# Screen coordinates (x / depth, y / depth): every pivot moves by tan(shift).
		var moved := Vector2(pivot.x - data.view_offset.x, data.view_offset.y - pivot.y) / depth
		var expected := Vector2(tan(deg_to_rad(SHIFT.x)), tan(deg_to_rad(SHIFT.y)))
		assert_vector(moved).override_failure_message(String(data.id)).is_equal_approx(expected, Vector2.ONE * 0.0001)
		assert_float(pivot.z).is_equal_approx(data.view_offset.z, 0.0001)


func test_recoil_and_the_swing_run_from_the_shifted_pose() -> void:
	_holder.equip(1)
	var rest := _holder.view_pivot().position
	_holder.view_pivot().kick()
	_holder.view_pivot().step(0.0, false)
	# The kick pushes the gun back (+Z) from the shifted rest, then it returns there.
	assert_float(_holder.view_pivot().position.z).is_greater(rest.z + 0.01)
	_holder.view_pivot().step(1.0, false)
	assert_vector(_holder.view_pivot().position).is_equal_approx(rest, Vector3.ONE * 0.0001)

	_holder.equip(0)
	var grip := _holder.view_pivot().position
	var rest_basis := _holder.view_pivot().basis
	_holder.view_pivot().preview_swing(0.3)
	# The chop turns about the shifted grip.
	assert_vector(_holder.view_pivot().position).is_equal_approx(grip, Vector3.ONE * 0.0001)
	assert_bool(_holder.view_pivot().basis.is_equal_approx(rest_basis)).is_false()


func test_changing_the_shift_moves_the_drawn_weapon_at_once() -> void:
	_holder.equip(1)
	_holder.view_shift_deg = Vector2.ZERO
	assert_vector(_holder.view_pivot().position).is_equal_approx(PISTOL.view_offset, Vector3.ONE * 0.0001)


func test_the_player_lowers_its_view_models_and_guards_keep_theirs() -> void:
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate()
	var player_holder := player.get_node("Head/Camera/WeaponHolder") as WeaponHolder
	assert_float(player_holder.view_shift_deg.y).is_greater(0.0)
	assert_float(player_holder.view_shift_deg.x).is_greater_equal(0.0)
	player.free()
	for path: String in ["res://actors/guard/guard_pistol.tscn", "res://actors/guard/guard_rifle.tscn"]:
		var guard := (load(path) as PackedScene).instantiate()
		var holder := guard.get_node("Aim/WeaponHolder") as WeaponHolder
		assert_vector(holder.view_shift_deg).override_failure_message(path).is_equal(Vector2.ZERO)
		guard.free()
