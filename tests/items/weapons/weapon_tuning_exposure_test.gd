extends GdUnitTestSuite
## The M13a tuning values (ADR 0123) are what the range's tuning panel lists by reflection
## (TuningProperties, ADR 0125): for the submachine gun and the assault rifle, the recoil config
## (pattern scale, noise, return delay and time, kick), the aim config (still cone, bloom, cap,
## movement terms, settle) and the weapon's damage falloff all appear as sliders; the pattern's loop
## index (part of the shape) does not.

const SMG: WeaponData = preload("res://items/weapons/smg/smg.tres")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const RECOIL_SLIDERS: Array[String] = [
	"pattern_scale", "kick_up_deg", "kick_side_deg", "noise_deg", "recover_delay", "recover_time"
]
const AIM_SLIDERS: Array[String] = [
	"base_min_deg",
	"walk_add_deg",
	"sprint_add_deg",
	"air_add_deg",
	"settle_time",
	"shot_bloom_deg",
	"shot_bloom_cap_deg"
]


func test_the_smg_and_rifle_tuning_shows_on_the_panel() -> void:
	for weapon: WeaponData in [SMG, RIFLE]:
		var recoil := _slider_names(weapon, weapon.recoil)
		var aim := _slider_names(weapon, weapon.aim_config)
		for name in RECOIL_SLIDERS:
			assert_array(recoil).override_failure_message("%s %s" % [weapon.id, name]).contains([name])
		for name in AIM_SLIDERS:
			assert_array(aim).override_failure_message("%s %s" % [weapon.id, name]).contains([name])
		assert_array(recoil).not_contains(["loop_from"])
	var root := _slider_names(SMG, SMG)
	assert_array(root).contains(["falloff_start", "falloff_end", "falloff_min"])


# The slider names TuningProperties lists for `resource` among the entries of `weapon` (empty when
# the resource is not one of them).
func _slider_names(weapon: WeaponData, resource: Resource) -> Array[String]:
	var names: Array[String] = []
	for entry in TuningProperties.entries(weapon):
		if entry.resource == resource:
			for slider in TuningProperties.sliders(entry.resource):
				names.append(slider.name)
	return names
