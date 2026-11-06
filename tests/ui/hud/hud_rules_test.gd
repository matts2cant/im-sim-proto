extends GdUnitTestSuite
## Unit: HudRules (part colours, ammo text).

const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")


func test_part_colors_green_yellow_red_black() -> void:
	assert_object(HudRules.part_color(1.0)).is_equal(HudRules.HEALTHY)
	assert_object(HudRules.part_color(0.5)).is_equal(HudRules.HURT)
	assert_object(HudRules.part_color(0.0)).is_equal(HudRules.DISABLED)
	var low := HudRules.part_color(0.05)
	assert_float(low.r).is_greater(0.85)
	assert_float(low.g).is_less(0.3)


func test_a_graze_is_not_pure_green() -> void:
	var graze := HudRules.part_color(0.95)

	assert_object(graze).is_not_equal(HudRules.HEALTHY)
	assert_float(graze.r).is_greater(0.5)
	assert_object(HudRules.part_color(0.999)).is_not_equal(HudRules.HEALTHY)


func test_ammo_text() -> void:
	var state := WeaponState.new(PISTOL)
	assert_str(HudRules.ammo_text(state)).is_equal("10 / 30")
	state.try_fire()
	assert_str(HudRules.ammo_text(state)).is_equal("9 / 30")
	state.start_reload()
	assert_str(HudRules.ammo_text(state)).is_equal("reloading  / 30")
	assert_str(HudRules.ammo_text(WeaponState.new(BATON))).is_equal("")
	assert_str(HudRules.ammo_text(null)).is_equal("")
