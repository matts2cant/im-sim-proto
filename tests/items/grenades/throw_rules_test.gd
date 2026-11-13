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


func test_on_a_wall_it_stands_upright_its_side_on_the_surface() -> void:
	var wall_normal := Vector3(0, 0, 1)
	# Half height 0.05, radius 0.04.
	var pose := ThrowRules.stick_transform(Vector3(1, 1.5, -2), wall_normal, Vector3(0.2, -0.1, -1), 0.05, 0.04)
	assert_vector(pose.basis.y).is_equal_approx(Vector3.UP, Vector3.ONE * 0.0001)
	# +X straight into the wall, whatever the view's slant.
	assert_vector(pose.basis.x).is_equal_approx(Vector3.FORWARD, Vector3.ONE * 0.0001)
	assert_bool(pose.basis.is_equal_approx(pose.basis.orthonormalized())).is_true()
	assert_float(pose.basis.determinant()).is_equal_approx(1.0, 0.0001)
	assert_vector(pose.origin).is_equal_approx(Vector3(1, 1.5, -1.96), Vector3.ONE * 0.0001)
	# A wall leaning back 30 degrees (60 from level, steeper than 45): still upright, the bottom rim
	# on the plane: 0.05 * sin 30 + 0.04 * cos 30 out along the normal.
	var leaning := Vector3(0, sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)))
	var lean_pose := ThrowRules.stick_transform(Vector3.ZERO, leaning, Vector3.FORWARD, 0.05, 0.04)
	assert_vector(lean_pose.basis.y).is_equal_approx(Vector3.UP, Vector3.ONE * 0.0001)
	var reach := 0.05 * 0.5 + 0.04 * cos(deg_to_rad(30.0))
	assert_vector(lean_pose.origin).is_equal_approx(leaning * reach, Vector3.ONE * 0.0001)


func test_on_a_floor_or_ceiling_it_sits_on_its_base() -> void:
	var floor_pose := ThrowRules.stick_transform(Vector3(2, 0, 0), Vector3.UP, Vector3(0.3, -0.8, -1), 0.05, 0.04)
	assert_vector(floor_pose.basis.y).is_equal_approx(Vector3.UP, Vector3.ONE * 0.0001)
	assert_vector(floor_pose.origin).is_equal_approx(Vector3(2, 0.05, 0), Vector3.ONE * 0.0001)
	# +X along the view on the floor.
	assert_vector(floor_pose.basis.x).is_equal_approx(Vector3(0.3, 0, -1).normalized(), Vector3.ONE * 0.0001)
	# A ramp 30 degrees from level: on its base, +Y along the normal.
	var ramp := Vector3(0, cos(deg_to_rad(30.0)), sin(deg_to_rad(30.0)))
	var ramp_pose := ThrowRules.stick_transform(Vector3.ZERO, ramp, Vector3.FORWARD, 0.05, 0.04)
	assert_vector(ramp_pose.basis.y).is_equal_approx(ramp, Vector3.ONE * 0.0001)
	# A ceiling: upside down, its base on it.
	var ceiling_pose := ThrowRules.stick_transform(Vector3(0, 3, 0), Vector3.DOWN, Vector3.FORWARD, 0.05, 0.04)
	assert_vector(ceiling_pose.basis.y).is_equal_approx(Vector3.DOWN, Vector3.ONE * 0.0001)
	assert_vector(ceiling_pose.origin).is_equal_approx(Vector3(0, 2.95, 0), Vector3.ONE * 0.0001)
	assert_float(ceiling_pose.basis.determinant()).is_equal_approx(1.0, 0.0001)
	# Looking straight at a floor (view along the normal) still gives a pose.
	var down_pose := ThrowRules.stick_transform(Vector3.ZERO, Vector3.UP, Vector3.DOWN, 0.05, 0.04)
	assert_float(down_pose.basis.determinant()).is_equal_approx(1.0, 0.0001)
	assert_vector(down_pose.basis.y).is_equal_approx(Vector3.UP, Vector3.ONE * 0.0001)
