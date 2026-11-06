extends GdUnitTestSuite
## Unit: impact loudness, damage and sound tier formulas; material damage multipliers.

const SETTINGS: ImpactSettings = preload("res://objects/components/impact_settings.tres")
const WOOD: MaterialProfile = preload("res://objects/materials/wood.tres")
const METAL: MaterialProfile = preload("res://objects/materials/metal.tres")
const GLASS: MaterialProfile = preload("res://objects/materials/glass.tres")
const CARDBOARD: MaterialProfile = preload("res://objects/materials/cardboard.tres")


func test_loudness_is_speed_times_root_mass_times_factor() -> void:
	# 5 m/s x sqrt(10) x 0.8 = 12.65
	assert_float(ImpactRules.loudness(5.0, 10.0, 1.0, SETTINGS)).is_equal_approx(12.649, 0.001)


func test_loudness_is_clamped_before_the_material_multiplier() -> void:
	assert_float(ImpactRules.loudness(0.5, 1.0, 1.0, SETTINGS)).is_equal(2.0)
	assert_float(ImpactRules.loudness(12.0, 60.0, 1.0, SETTINGS)).is_equal(30.0)
	assert_float(ImpactRules.loudness(12.0, 60.0, METAL.impact_loudness, SETTINGS)).is_equal_approx(42.0, 0.0001)


func test_material_multipliers() -> void:
	assert_float(WOOD.impact_loudness).is_equal(1.0)
	assert_float(METAL.impact_loudness).is_equal(1.4)
	assert_float(GLASS.impact_loudness).is_equal(1.6)
	assert_float(CARDBOARD.impact_loudness).is_equal(0.4)
	# Small crate 10 kg at 3 m/s on wood: 3 x 3.162 x 0.8 = 7.59
	assert_float(ImpactRules.loudness(3.0, 10.0, WOOD.impact_loudness, SETTINGS)).is_equal_approx(7.589, 0.001)


func test_damage_is_kinetic_energy_over_forty() -> void:
	# 0.5 x 10 x 6^2 / 40 = 4.5
	assert_float(ImpactRules.damage(6.0, 10.0, SETTINGS)).is_equal_approx(4.5, 0.0001)
	assert_float(ImpactRules.damage(0.0, 10.0, SETTINGS)).is_equal(0.0)


func test_sound_tier_by_loudness() -> void:
	assert_int(ImpactRules.tier(4.0, SETTINGS)).is_equal(0)
	assert_int(ImpactRules.tier(8.0, SETTINGS)).is_equal(1)
	assert_int(ImpactRules.tier(16.0, SETTINGS)).is_equal(2)
	assert_object(WOOD.impact_sound(2)).is_not_null()
	assert_object(CARDBOARD.impact_sound(0)).is_not_null()


func test_volume_is_ten_db_per_decade_clamped() -> void:
	assert_float(ImpactRules.volume_db(10.0, SETTINGS)).is_equal_approx(0.0, 0.0001)
	assert_float(ImpactRules.volume_db(1.0, SETTINGS)).is_equal_approx(-10.0, 0.0001)
	assert_float(ImpactRules.volume_db(1000.0, SETTINGS)).is_equal(SETTINGS.audio_max_db)


func test_damage_multiplier_most_specific_entry_wins() -> void:
	var profile := MaterialProfile.new()
	profile.damage_multipliers = {&"damage": 0.5, &"damage.fire": 2.0}

	assert_float(profile.damage_multiplier(&"damage.fire")).is_equal(2.0)
	assert_float(profile.damage_multiplier(&"damage.blunt")).is_equal(0.5)
	assert_float(MaterialProfile.new().damage_multiplier(&"damage.blunt")).is_equal(1.0)


func test_material_damage_tables() -> void:
	assert_float(WOOD.damage_multiplier(&"damage.fire")).is_equal(1.0)
	assert_float(WOOD.damage_multiplier(&"damage.explosive")).is_equal(0.5)
	assert_float(WOOD.damage_multiplier(&"damage.blunt")).is_equal(1.0)
	assert_float(METAL.damage_multiplier(&"damage.fire")).is_equal(0.0)
	assert_float(GLASS.break_impact_speed).is_equal(4.0)
