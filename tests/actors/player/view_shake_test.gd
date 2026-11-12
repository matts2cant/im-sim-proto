extends GdUnitTestSuite
## Unit (ADR 0128): ViewShake, the camera shake of a shot, and the weapons' shake tuning.
## - A shake jumps to its amplitude, wobbles and is gone after its time; a weaker shake does not
##   cut a stronger one short.
## - Per weapon (WeaponMotionConfig.shake_deg): the shotgun and the sniper rifle shake hardest; the
##   pistol, SMG and assault rifle slightly; the baton not at all.

const DT := 1.0 / 60.0
const SHAKES: Dictionary[String, String] = {
	"pistol": "res://items/weapons/pistol/pistol.tres",
	"smg": "res://items/weapons/smg/smg.tres",
	"rifle": "res://items/weapons/assault_rifle/assault_rifle.tres",
	"shotgun": "res://items/weapons/shotgun/shotgun.tres",
	"sniper": "res://items/weapons/sniper_rifle/sniper_rifle.tres",
	"baton": "res://items/weapons/baton/baton.tres",
}


func test_a_shake_peaks_at_its_amplitude_and_dies_out() -> void:
	var shake := ViewShake.new(3)
	shake.add(0.8, 0.25)
	assert_float(shake.offset().length()).is_equal_approx(0.8, 0.0001)
	# Mostly upwards.
	assert_float(shake.offset().y).is_greater(0.4)
	var largest_late := 0.0
	var elapsed := 0.0
	while elapsed < 0.3:
		shake.step(DT)
		elapsed += DT
		if elapsed > 0.15 and elapsed < 0.25:
			largest_late = maxf(largest_late, shake.offset().length())
	assert_float(largest_late).is_less(0.8 * 0.25)
	assert_vector(shake.offset()).is_equal(Vector3.ZERO)
	assert_float(shake.remaining()).is_equal(0.0)


func test_a_weaker_shake_keeps_the_stronger_one() -> void:
	var shake := ViewShake.new(3)
	shake.add(0.9, 0.3)
	shake.step(DT)
	var strong := shake.remaining()
	shake.add(0.15, 0.08)
	assert_float(shake.remaining()).is_equal(strong)
	shake.add(1.5, 0.2)
	assert_float(shake.remaining()).is_equal(1.5)


func test_the_shotgun_and_the_sniper_shake_hardest() -> void:
	var amplitude: Dictionary[String, float] = {}
	for weapon in SHAKES:
		var data := load(SHAKES[weapon]) as WeaponData
		assert_object(data.motion).override_failure_message(weapon).is_not_null()
		amplitude[weapon] = data.motion.shake_deg
	for light: String in ["pistol", "smg", "rifle"]:
		assert_float(amplitude[light]).override_failure_message(light).is_between(0.05, 0.4)
		for heavy: String in ["shotgun", "sniper"]:
			assert_float(amplitude[heavy]).override_failure_message(heavy).is_greater(amplitude[light] * 2.0)
	assert_float(amplitude["baton"]).is_equal(0.0)
