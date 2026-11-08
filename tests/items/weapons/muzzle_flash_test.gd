extends GdUnitTestSuite
## Unit/integration: MuzzleFlash (ADR 0070): shown for a moment on a shot of a weapon with a flash
## size (the guards' pistol, the player's pistol), never for a weapon without one, a silenced shot
## (size 0 through the silencer, ADR 0085) or a melee weapon; hold()
## keeps it for screenshots; it carries a real light.

const LOUD: WeaponData = preload("res://items/weapons/pistol/pistol_unsilenced.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")

var _flash: MuzzleFlash


func before_test() -> void:
	_flash = auto_free(MuzzleFlash.new())
	add_child(_flash)


func test_a_loud_shot_flashes_briefly_at_the_front_of_the_gun() -> void:
	_flash.fire(LOUD)
	assert_bool(_flash.visible).is_true()
	assert_float(_flash.position.z).is_less(-LOUD.view_size.z * 0.5)
	assert_object(_flash.light).is_not_null()
	_flash.step(MuzzleFlash.TIME * 0.5)
	assert_bool(_flash.visible).is_true()
	_flash.step(MuzzleFlash.TIME)
	assert_bool(_flash.visible).is_false()


func test_quiet_silenced_and_melee_weapons_do_not_flash() -> void:
	var quiet := WeaponData.new()
	_flash.fire(quiet)
	assert_bool(_flash.visible).is_false()
	# A silenced pistol: the silencer's modifier makes the flash size 0.
	_flash.fire(PISTOL, 0.0)
	assert_bool(_flash.visible).is_false()
	_flash.fire(BATON)
	assert_bool(_flash.visible).is_false()


func test_hold_keeps_it_until_cleared() -> void:
	_flash.hold(LOUD)
	_flash.step(1.0)
	assert_bool(_flash.visible).is_true()
	_flash.clear()
	assert_bool(_flash.visible).is_false()
