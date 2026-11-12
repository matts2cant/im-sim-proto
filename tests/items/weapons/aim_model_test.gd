extends GdUnitTestSuite
## Unit: AimModel (floors per stance, settle curve, bloom caps, max, deterministic cone sampling).

const CONFIG: AimConfig = preload("res://items/weapons/aim_untrained.tres")
const FRAME := 1.0 / 60.0

var _aim: AimModel


func before_test() -> void:
	_aim = AimModel.new(CONFIG, 1234)


func test_starts_at_the_base_floor() -> void:
	assert_float(_aim.spread).is_equal(0.5)


func test_floors_per_stance() -> void:
	assert_float(_aim.floor_for(AimModel.Stance.STILL)).is_equal_approx(0.5, 0.0001)
	assert_float(_aim.floor_for(AimModel.Stance.CROUCH_STILL)).is_equal_approx(0.4, 0.0001)
	# M13a (ADR 0123): a moderate moving penalty, walking near standing, airborne bad.
	assert_float(_aim.floor_for(AimModel.Stance.WALK)).is_equal_approx(1.25, 0.0001)
	assert_float(_aim.floor_for(AimModel.Stance.SPRINT)).is_equal_approx(4.5, 0.0001)
	assert_float(_aim.floor_for(AimModel.Stance.AIR)).is_equal_approx(6.5, 0.0001)


func test_still_mult_scales_only_the_still_floor() -> void:
	# Master (ADR 0123): still cone 0, the movement terms x the spread multiplier.
	assert_float(_aim.floor_for(AimModel.Stance.STILL, 0.0, 0.4, 0.0)).is_equal(0.0)
	assert_float(_aim.floor_for(AimModel.Stance.CROUCH_STILL, 0.0, 0.4, 0.0)).is_equal(0.0)
	assert_float(_aim.floor_for(AimModel.Stance.WALK, 0.0, 0.4, 0.0)).is_equal_approx(0.3, 0.0001)
	assert_float(_aim.floor_for(AimModel.Stance.STILL, 0.0, 1.0, 0.5)).is_equal_approx(0.25, 0.0001)


func test_arm_penalty_adds_to_the_floor_and_caps_at_max() -> void:
	assert_float(_aim.floor_for(AimModel.Stance.STILL, 3.0)).is_equal_approx(3.5, 0.0001)
	assert_float(_aim.floor_for(AimModel.Stance.SPRINT, 6.0)).is_equal(10.0)


func test_rising_floor_widens_at_once() -> void:
	_aim.step(FRAME, _aim.floor_for(AimModel.Stance.SPRINT))

	assert_float(_aim.spread).is_equal_approx(4.5, 0.0001)


func test_settles_exponentially_with_the_time_constant() -> void:
	_aim.spread = 9.5
	for i in 48:
		_aim.step(FRAME, 1.5)

	# After 0.8 s (one time constant) the excess of 8 has decayed to 8 / e.
	assert_float(_aim.spread).is_equal_approx(1.5 + 8.0 / exp(1.0), 0.001)
	for i in 192:
		_aim.step(FRAME, 1.5)
	assert_float(_aim.spread).is_equal_approx(1.5 + 8.0 * exp(-5.0), 0.001)


func test_settles_exactly_onto_the_base_floor() -> void:
	_aim.spread = 9.5
	var floor_deg := _aim.floor_for(AimModel.Stance.STILL)
	for i in 600:
		_aim.step(FRAME, floor_deg)

	assert_float(_aim.spread).is_equal(0.5)


func test_faster_settle_time_settles_faster() -> void:
	var trained := CONFIG.duplicate() as AimConfig
	trained.settle_time = 0.2
	var aim := AimModel.new(trained, 1)
	aim.spread = 9.5
	for i in 12:
		aim.step(FRAME, 1.5)

	assert_float(aim.spread).is_equal_approx(1.5 + 8.0 / exp(1.0), 0.001)


func test_look_bloom_per_pixel_and_frame_cap() -> void:
	_aim.add_look(50.0)
	assert_float(_aim.spread).is_equal_approx(1.5, 0.0001)

	_aim.add_look(1000.0)
	assert_float(_aim.spread).is_equal_approx(3.5, 0.0001)


func test_shot_bloom_and_max_spread() -> void:
	_aim.add_shot()
	assert_float(_aim.spread).is_equal_approx(3.0, 0.0001)
	for i in 5:
		_aim.add_shot()
	assert_float(_aim.spread).is_equal(10.0)
	_aim.add_look(1000.0)
	assert_float(_aim.spread).is_equal(10.0)


func test_samples_stay_inside_the_cone() -> void:
	var basis := Basis.from_euler(Vector3(0.3, 1.1, 0))
	for spread: float in [1.5, 4.5, 10.0]:
		_aim.spread = spread
		var widest := 0.0
		for i in 500:
			var direction := _aim.sample_direction(basis)
			assert_float(direction.length()).is_equal_approx(1.0, 0.0001)
			widest = maxf(widest, AimModel.angle_off(basis, direction))
		assert_float(widest).is_less_equal(spread + 0.0001)
		# Uniform on the disk: some shots land near the edge.
		assert_float(widest).is_greater(spread * 0.9)


func test_samples_are_uniform_on_the_disk() -> void:
	_aim.spread = 6.0
	var inner := 0
	var count := 2000
	for i in count:
		# Inside half the radius (tan-space) = a quarter of the area.
		var direction := _aim.sample_direction(Basis.IDENTITY)
		var radius := Vector2(direction.x, direction.y).length() / -direction.z
		if radius <= tan(deg_to_rad(6.0)) * 0.5:
			inner += 1
	assert_float(float(inner) / count).is_equal_approx(0.25, 0.04)


func test_same_seed_same_shots() -> void:
	var other := AimModel.new(CONFIG, 1234)
	_aim.spread = 5.0
	other.spread = 5.0
	for i in 10:
		assert_vector(_aim.sample_direction(Basis.IDENTITY)).is_equal(other.sample_direction(Basis.IDENTITY))


func test_reticle_radius_matches_the_cone() -> void:
	# tan(1.5) / tan(40) x 324 for an 80 degree camera on a 648 px viewport.
	assert_float(AimModel.reticle_radius(1.5, 80.0, 648.0)).is_equal_approx(10.11, 0.01)
	assert_float(AimModel.reticle_radius(0.5, 80.0, 648.0)).is_equal_approx(3.37, 0.01)
	assert_float(AimModel.reticle_radius(7.5, 80.0, 648.0)).is_equal_approx(50.84, 0.01)
	assert_float(AimModel.reticle_radius(40.0, 80.0, 648.0)).is_equal_approx(324.0, 0.01)


func test_sway_scales_with_the_multiplier() -> void:
	_aim.step(0.5, 1.5)
	var base := _aim.sway(1.0)

	assert_float(base.length()).is_greater(0.0)
	assert_float(base.length()).is_less_equal(CONFIG.sway_deg * 1.2)
	assert_vector(_aim.sway(2.0)).is_equal_approx(base * 2.0, Vector2.ONE * 0.0001)
