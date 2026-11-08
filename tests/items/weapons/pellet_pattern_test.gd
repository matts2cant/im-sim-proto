extends GdUnitTestSuite
## Unit: PelletPattern (ADR 0085). One projectile flies along the shot; several spread evenly-random
## inside the cone: all inside it, one per angular sector, filling the disk (not bunched at the
## centre or the rim), the same for the same seed.

const FORWARD := Vector3(0, 0, -1)


func test_one_projectile_or_no_spread_flies_along_the_shot() -> void:
	var rng := _rng(7)
	assert_array(PelletPattern.spread(FORWARD, Vector3.UP, 1, 5.0, rng)).contains_exactly([FORWARD])
	assert_array(PelletPattern.spread(FORWARD, Vector3.UP, 8, 0.0, rng)).contains_exactly([FORWARD])


func test_pellets_stay_inside_the_cone() -> void:
	var rng := _rng(3)
	var direction := Vector3(0.3, -0.2, -1).normalized()
	for shot in 50:
		var pellets := PelletPattern.spread(direction, Vector3.UP, 8, 5.0, rng)
		assert_int(pellets.size()).is_equal(8)
		for pellet in pellets:
			assert_float(rad_to_deg(direction.angle_to(pellet))).is_less_equal(5.0 + 0.0001)
			assert_float(pellet.length()).is_equal_approx(1.0, 0.0001)


func test_each_pellet_takes_its_own_sector() -> void:
	var rng := _rng(11)
	for shot in 20:
		var pellets := PelletPattern.spread(FORWARD, Vector3.UP, 8, 5.0, rng)
		var sectors: Array[int] = []
		for pellet in pellets:
			# Angle around the shot in the plane facing it (side = +X, lift = +Y for -Z forward).
			var angle := fposmod(atan2(pellet.y, pellet.x), TAU)
			sectors.append(floori(angle / (TAU / 8.0)))
		sectors.sort()
		assert_array(sectors).contains_exactly([0, 1, 2, 3, 4, 5, 6, 7])


func test_pellets_fill_the_disk_evenly_by_area() -> void:
	var rng := _rng(5)
	var inner := 0
	var total := 0
	for shot in 400:
		for pellet in PelletPattern.spread(FORWARD, Vector3.UP, 8, 5.0, rng):
			total += 1
			# Inside half the cone's radius: a quarter of the disk's area.
			if Vector2(pellet.x, pellet.y).length() / -pellet.z < tan(deg_to_rad(5.0)) * 0.5:
				inner += 1
	assert_float(float(inner) / total).is_between(0.21, 0.29)


func test_same_seed_same_pattern() -> void:
	var a := PelletPattern.spread(FORWARD, Vector3.UP, 8, 5.0, _rng(99))
	var b := PelletPattern.spread(FORWARD, Vector3.UP, 8, 5.0, _rng(99))
	assert_array(a).is_equal(b)


func test_works_when_shooting_straight_up() -> void:
	var pellets := PelletPattern.spread(Vector3.UP, Vector3.UP, 4, 5.0, _rng(1))
	assert_int(pellets.size()).is_equal(4)
	for pellet in pellets:
		assert_float(rad_to_deg(Vector3.UP.angle_to(pellet))).is_less_equal(5.0 + 0.0001)


static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
