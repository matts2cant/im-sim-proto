extends GdUnitTestSuite
## Unit: carry eligibility, throw speed, carry speed factor, hold distance and point, release target,
## upright yaw snapping, pick-up blend and release fraction (ADR 0053).

const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")
const EPS := Vector3.ONE * 0.0001


func test_carry_eligibility_against_limit() -> void:
	assert_bool(CarryRules.can_carry(10.0, 20.0)).is_true()
	assert_bool(CarryRules.can_carry(20.0, 20.0)).is_true()
	assert_bool(CarryRules.can_carry(25.0, 20.0)).is_false()
	assert_bool(CarryRules.can_carry(60.0, 70.0)).is_true()
	assert_bool(CarryRules.can_carry(0.0, 20.0)).is_false()


func test_throw_speed_is_impulse_over_mass_capped() -> void:
	# 40 N s: small crate 10 kg -> 4 m/s, 20 kg -> 2 m/s, cardboard 2 kg -> 20 capped to 12, bottle 12.
	assert_float(CarryRules.throw_speed(10.0, CONFIG)).is_equal_approx(4.0, 0.0001)
	assert_float(CarryRules.throw_speed(20.0, CONFIG)).is_equal_approx(2.0, 0.0001)
	assert_float(CarryRules.throw_speed(2.0, CONFIG)).is_equal_approx(12.0, 0.0001)
	assert_float(CarryRules.throw_speed(0.5, CONFIG)).is_equal_approx(12.0, 0.0001)


func test_heavy_load_slows_the_player() -> void:
	assert_float(CarryRules.speed_factor(0.0, CONFIG)).is_equal(1.0)
	assert_float(CarryRules.speed_factor(9.9, CONFIG)).is_equal(1.0)
	assert_float(CarryRules.speed_factor(10.0, CONFIG)).is_equal(0.8)


func test_hold_distance_grows_with_the_object_size() -> void:
	# Small crate 0.6 m cube -> 0.75 m, cardboard 0.5 m -> 0.7 m, a 0.9 m tall barrel -> 0.9 m.
	assert_float(CarryRules.half_extent(AABB(Vector3.ONE * -0.3, Vector3.ONE * 0.6))).is_equal_approx(0.3, 0.0001)
	assert_float(CarryRules.half_extent(AABB(Vector3(-0.3, -0.45, -0.3), Vector3(0.6, 0.9, 0.6)))).is_equal_approx(
		0.45, 0.0001
	)
	assert_float(CarryRules.hold_distance(0.3, CONFIG)).is_equal_approx(0.75, 0.0001)
	assert_float(CarryRules.hold_distance(0.25, CONFIG)).is_equal_approx(0.7, 0.0001)
	assert_float(CarryRules.hold_distance(0.45, CONFIG)).is_equal_approx(0.9, 0.0001)


func test_hold_point_is_ahead_along_the_view_and_lower_on_the_screen() -> void:
	var eye := Transform3D(Basis.IDENTITY, Vector3(0, 1.65, 0))
	# Small crate: 0.75 m ahead, 0.1 + 0.3 = 0.4 m down.
	assert_vector(CarryRules.hold_point(eye, 0.3, CONFIG)).is_equal_approx(Vector3(0, 1.25, -0.75), EPS)

	# Looking 30 degrees up: the offsets follow the camera (same place on the screen).
	var up := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(30.0)), eye.origin)
	var local := up.affine_inverse() * CarryRules.hold_point(up, 0.3, CONFIG)
	assert_vector(local).is_equal_approx(Vector3(0, -0.4, -0.75), EPS)


func test_release_target_is_clear_of_the_capsule_when_looking_down() -> void:
	# Level: the hold point (0.75 m ahead >= 0.35 + 0.3 + 0.1).
	var eye := Transform3D(Basis.IDENTITY, Vector3(0, 1.65, 0))
	assert_vector(CarryRules.release_target(eye, 0.3, CONFIG)).is_equal_approx(Vector3(0, 1.25, -0.75), EPS)

	# 60 degrees down, facing +X: pushed out to 0.75 m from the axis along the view, height kept.
	var down := Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(-60.0)), eye.origin)
	var hold := CarryRules.hold_point(down, 0.3, CONFIG)
	var target := CarryRules.release_target(down, 0.3, CONFIG)
	assert_float(hold.x).is_less(0.5)
	assert_float(target.x).is_equal_approx(0.75, 0.0001)
	assert_float(target.z).is_equal_approx(0.0, 0.0001)
	assert_float(target.y).is_equal_approx(hold.y, 0.0001)


func test_view_yaw_and_forward_hold_at_any_pitch() -> void:
	var basis := Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, deg_to_rad(-85.0))

	assert_float(CarryRules.view_yaw(basis)).is_equal_approx(0.7, 0.0001)
	assert_vector(CarryRules.view_forward(basis)).is_equal_approx(Vector3(-sin(0.7), 0, -cos(0.7)), EPS)


func test_upright_yaw_of_a_tilted_object() -> void:
	# Yawed 20 degrees then tilted 30 degrees about its X: upright again at 20 degrees.
	var tilted := Basis(Vector3.UP, deg_to_rad(20.0)) * Basis(Vector3.RIGHT, deg_to_rad(30.0))
	assert_float(rad_to_deg(CarryRules.upright_yaw(tilted))).is_equal_approx(20.0, 0.01)
	# Upside down (rolled 180 degrees about X): yaw kept.
	var flipped := Basis(Vector3.UP, deg_to_rad(-40.0)) * Basis(Vector3.RIGHT, PI)
	assert_float(rad_to_deg(CarryRules.upright_yaw(flipped))).is_equal_approx(-40.0, 0.01)
	assert_float(CarryRules.upright_yaw(Basis.IDENTITY)).is_equal_approx(0.0, 0.0001)


func test_yaw_offset_snaps_to_the_nearest_quarter_turn() -> void:
	assert_float(rad_to_deg(CarryRules.snapped_yaw_offset(deg_to_rad(20.0), 0.0))).is_equal_approx(0.0, 0.01)
	assert_float(rad_to_deg(CarryRules.snapped_yaw_offset(deg_to_rad(70.0), 0.0))).is_equal_approx(90.0, 0.01)
	assert_float(rad_to_deg(CarryRules.snapped_yaw_offset(deg_to_rad(10.0), deg_to_rad(120.0)))).is_equal_approx(
		-90.0, 0.01
	)
	# Across the +-180 wrap: 170 - (-170) = 340 -> -20 -> 0.
	assert_float(rad_to_deg(CarryRules.snapped_yaw_offset(deg_to_rad(170.0), deg_to_rad(-170.0)))).is_equal_approx(
		0.0, 0.01
	)
	var basis := CarryRules.held_basis(deg_to_rad(30.0), PI * 0.5)
	assert_vector(basis.y).is_equal_approx(Vector3.UP, EPS)
	assert_float(rad_to_deg(CarryRules.view_yaw(basis))).is_equal_approx(120.0, 0.01)


func test_pickup_blend_eases_over_the_turn_time() -> void:
	assert_float(CarryRules.pickup_blend(0.0, 0.15)).is_equal(0.0)
	assert_float(CarryRules.pickup_blend(0.075, 0.15)).is_equal_approx(0.5, 0.0001)
	assert_float(CarryRules.pickup_blend(0.2, 0.15)).is_equal(1.0)
	assert_float(CarryRules.pickup_blend(0.0, 0.0)).is_equal(1.0)


func test_release_fraction_backs_off_from_the_first_contact() -> void:
	# Clear path: all the way. Hit at 0.5 of a 1 m cast with a 1 cm margin: 0.49.
	assert_float(CarryRules.release_fraction(1.0, 1.0, 0.01)).is_equal(1.0)
	assert_float(CarryRules.release_fraction(0.5, 1.0, 0.01)).is_equal_approx(0.49, 0.0001)
	assert_float(CarryRules.release_fraction(0.005, 1.0, 0.01)).is_equal(0.0)
	assert_float(CarryRules.release_fraction(0.0, 0.0, 0.01)).is_equal(0.0)


func test_release_path_goes_out_then_down_or_up_then_out() -> void:
	var chest := Vector3(0, 1.3, 0)
	# Lower target (put down, stack): out at chest height, then down.
	assert_vector(CarryRules.release_corner(chest, Vector3(0, 0.8, -0.75))).is_equal_approx(Vector3(0, 1.3, -0.75), EPS)
	# Higher target (shelf): up on the player's axis, then out.
	assert_vector(CarryRules.release_corner(chest, Vector3(0.5, 1.7, -0.5))).is_equal_approx(Vector3(0, 1.7, 0), EPS)
