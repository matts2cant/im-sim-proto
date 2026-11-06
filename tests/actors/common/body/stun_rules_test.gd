extends GdUnitTestSuite
## Unit: StunRules (rear arc, unaware x10, accumulation to the knockout threshold).

const ARC := 120.0
const FORWARD := Vector3(0, 0, -1)


func test_directly_behind_is_behind() -> void:
	assert_bool(StunRules.is_behind(Vector3.ZERO, FORWARD, Vector3(0, 0, 2), ARC)).is_true()


func test_in_front_and_beside_are_not_behind() -> void:
	assert_bool(StunRules.is_behind(Vector3.ZERO, FORWARD, Vector3(0, 0, -2), ARC)).is_false()
	assert_bool(StunRules.is_behind(Vector3.ZERO, FORWARD, Vector3(2, 0, 0), ARC)).is_false()


func test_arc_edges_at_60_degrees_from_the_back() -> void:
	var inside := Vector3(sin(deg_to_rad(59.0)), 0, cos(deg_to_rad(59.0))) * 2.0
	var outside := Vector3(sin(deg_to_rad(61.0)), 0, cos(deg_to_rad(61.0))) * 2.0

	assert_bool(StunRules.is_behind(Vector3.ZERO, FORWARD, inside, ARC)).is_true()
	assert_bool(StunRules.is_behind(Vector3.ZERO, FORWARD, outside, ARC)).is_false()
	assert_bool(StunRules.is_behind(Vector3.ZERO, FORWARD, Vector3(-inside.x, 0, inside.z), ARC)).is_true()


func test_height_and_facing_rotation_are_handled() -> void:
	# Target facing +X: behind is -X. Height differences do not matter.
	assert_bool(StunRules.is_behind(Vector3(5, 0, 5), Vector3(1, 0, 0), Vector3(3, 1.5, 5), ARC)).is_true()
	assert_bool(StunRules.is_behind(Vector3(5, 0, 5), Vector3(1, 0, 0), Vector3(7, 0, 5), ARC)).is_false()


func test_attacker_on_top_counts_as_front() -> void:
	assert_bool(StunRules.is_behind(Vector3.ZERO, FORWARD, Vector3(0, 1, 0), ARC)).is_false()


func test_unaware_from_behind_multiplies_by_ten() -> void:
	assert_float(StunRules.stun_points(20.0, 1.0, true, false, 10.0)).is_equal(200.0)


func test_aware_or_from_the_front_is_plain() -> void:
	assert_float(StunRules.stun_points(20.0, 1.0, true, true, 10.0)).is_equal(20.0)
	assert_float(StunRules.stun_points(20.0, 1.0, false, false, 10.0)).is_equal(20.0)
	assert_float(StunRules.stun_points(20.0, 0.5, false, false, 10.0)).is_equal(10.0)


func test_three_frontal_hits_knock_out() -> void:
	var stun := 0.0
	for hit in 2:
		stun += StunRules.stun_points(20.0, 1.0, false, false, 10.0)
		assert_bool(StunRules.knocks_out(stun, 60.0)).is_false()
	stun += StunRules.stun_points(20.0, 1.0, false, false, 10.0)
	assert_bool(StunRules.knocks_out(stun, 60.0)).is_true()


func test_zero_threshold_never_knocks_out() -> void:
	assert_bool(StunRules.knocks_out(1000.0, 0.0)).is_false()
