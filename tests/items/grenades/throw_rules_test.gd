extends GdUnitTestSuite
## Unit (ADR 0131): the throw's fixed arc and the stuck pose (ThrowRules), no scene tree.

const G: float = 9.8


func test_launch_speed_inverts_the_ballistic_range() -> void:
	for distance: float in [6.0, 12.0, 18.0]:
		var speed := ThrowRules.launch_speed(distance, deg_to_rad(20.0), 1.65, G)
		assert_float(ThrowRules.ballistic_range(speed, deg_to_rad(20.0), 1.65, G)).is_equal_approx(distance, 0.01)


func test_farther_throws_need_faster_launches() -> void:
	var near := ThrowRules.launch_speed(12.0, deg_to_rad(20.0), 1.65, G)
	var far := ThrowRules.launch_speed(18.0, deg_to_rad(20.0), 1.65, G)
	assert_float(far).is_greater(near)
	# A throw, not a gun: well under 20 m/s.
	assert_float(far).is_less(20.0)


func test_level_view_launches_the_lift_above_the_horizon() -> void:
	var velocity := ThrowRules.launch_velocity(Vector3.FORWARD, 12.0, 1.65, 20.0, 0.35, G)
	var elevation := rad_to_deg(atan2(velocity.y, Vector2(velocity.x, velocity.z).length()))
	assert_float(elevation).is_equal_approx(20.0, 0.01)
	assert_float(velocity.z).is_less(0.0)
	assert_float(absf(velocity.x)).is_less(0.0001)
	# Looking up raises the arc by the view's pitch at the same speed.
	var up := ThrowRules.launch_velocity(Vector3(0, sin(0.3), -cos(0.3)), 12.0, 1.65, 20.0, 0.35, G)
	assert_float(up.length()).is_equal_approx(velocity.length(), 0.0001)
	assert_float(atan2(up.y, -up.z)).is_equal_approx(0.3 + deg_to_rad(20.0), 0.0001)


func test_stick_pose_stands_on_the_surface() -> void:
	var wall_normal := Vector3(0, 0, 1)
	var pose := ThrowRules.stick_transform(Vector3(1, 1.5, -2), wall_normal, Vector3(0.2, -0.1, -1), 0.05)
	assert_bool(pose.basis.y.is_equal_approx(wall_normal)).is_true()
	assert_bool(pose.basis.is_equal_approx(pose.basis.orthonormalized())).is_true()
	assert_float(pose.basis.determinant()).is_equal_approx(1.0, 0.0001)
	assert_bool(pose.origin.is_equal_approx(Vector3(1, 1.5, -1.95))).is_true()
	# Looking straight at a floor (view along the normal) still gives a pose.
	var floor_pose := ThrowRules.stick_transform(Vector3.ZERO, Vector3.UP, Vector3.DOWN, 0.05)
	assert_float(floor_pose.basis.determinant()).is_equal_approx(1.0, 0.0001)
	assert_bool(floor_pose.basis.y.is_equal_approx(Vector3.UP)).is_true()
