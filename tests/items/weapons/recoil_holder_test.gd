extends GdUnitTestSuite
## Integration (ADR 0123): recoil is a WeaponHolder feature, not the player's: a shooter built from
## components (shooter_fixtures.gd) at a wall 8 m away.
## - Skill scales it through attributes: Master's first rifle step is the pattern x1 with a quarter
##   of Untrained's noise (x1.5 and x2), and returns faster.
## - The bullets follow the whole climb whatever share the eye follows: a spray with the eye
##   following none of it (camera motion 0) hits where it hits with the eye following all of it.
## - Pulling against the pattern keeps a spray on the aim point; not pulling climbs off it.
## - A scoped shot blacks the scope out for a moment; a holder with recoil off never climbs.

const Shooter := preload("res://tests/items/weapons/shooter_fixtures.gd")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const SNIPER: WeaponData = preload("res://items/weapons/sniper_rifle/sniper_rifle.tres")
const ORIGIN := Vector3(-600, 0, 420)
const WALL_DISTANCE := 8.0

var _shooter: Shooter
var _wall: StaticBody3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_skill_scales_the_pattern_noise_and_return() -> void:
	await _setup(RIFLE)
	var pattern := RIFLE.recoil.pattern_step(0) * RIFLE.recoil.pattern_scale
	var untrained := _first_step(0)
	var untrained_return := _return_time()
	var master := _first_step(3)
	var master_return := _return_time()
	var untrained_noise := untrained - pattern * 1.5
	var master_noise := master - pattern
	assert_vector(untrained_noise).is_equal_approx(master_noise * 4.0, Vector2.ONE * 0.0001)
	assert_float(master_noise.length()).is_less(RIFLE.recoil.noise_deg)
	# Return time x0.55 at Master (rifle_recoil_recover_mult).
	assert_float(master_return).is_less(untrained_return * 0.8)


func test_bullets_follow_the_whole_climb_whatever_the_eye_follows() -> void:
	await _setup(RIFLE)
	# A twin shooter 3 m to the side, built at the same moment: the same sway phase and seeds.
	var twin := Shooter.new(_wall.get_parent(), ORIGIN + Vector3(3, 0, 0), [RIFLE] as Array[WeaponData])
	await get_tree().physics_frame
	var followed := await _spray_hits(1.0)
	var swapped := _shooter
	_shooter = twin
	var unfollowed := await _spray_hits(0.0)
	_shooter = swapped
	assert_int(followed.size()).is_equal(10)
	assert_int(unfollowed.size()).is_equal(10)
	for i in followed.size():
		# Turning the eye then the shot (or the shot alone) differs only to second order.
		var offset := unfollowed[i] - Vector3(3, 0, 0)
		assert_float(followed[i].distance_to(offset)).override_failure_message("shot %d" % i).is_less(0.02)
	# The spray did climb: the last hit is well above the first.
	assert_float(followed[-1].y - followed[0].y).is_greater(0.3)


func test_pulling_against_the_pattern_keeps_a_spray_on_target() -> void:
	await _setup(RIFLE)
	_shooter.set_tier(&"rifles", 3)
	var aim_y := _wall.global_position.y + 0.2
	var pulled := await _spray_hits(1.0, true)
	var free := await _spray_hits(1.0, false)
	var pulled_rise := _mean(pulled).y - aim_y
	var free_rise := _mean(free).y - aim_y
	print(
		(
			"MEASURED rifle Master 10-shot spray at 8 m, mean rise (m): pulled %.3f, not pulled %.3f"
			% [pulled_rise, free_rise]
		)
	)
	assert_float(absf(pulled_rise)).is_less(0.08)
	assert_float(free_rise).is_greater(0.2)


func test_a_scoped_shot_blacks_the_scope_out_for_a_moment() -> void:
	await _setup(SNIPER)
	var holder := _shooter.holder
	assert_bool(holder.toggle_scope()).is_true()
	for tick in 20:
		_shooter.tick()
	assert_int(holder.trigger()).is_equal(WeaponState.Result.FIRED)
	assert_float(holder.recoil.blackout()).is_equal(1.0)
	for tick in 9:
		_shooter.tick()
	assert_float(holder.recoil.blackout()).is_between(0.4, 0.6)
	for tick in 12:
		_shooter.tick()
	assert_float(holder.recoil.blackout()).is_equal(0.0)


func test_a_holder_with_recoil_off_never_climbs() -> void:
	await _setup(RIFLE)
	_shooter.holder.recoil_enabled = false
	_shooter.aim_at(_wall.global_position)
	_shooter.holder.trigger_held = true
	for tick in 30:
		_shooter.tick()
	_shooter.holder.trigger_held = false
	assert_vector(_shooter.holder.recoil.offset).is_equal(Vector2.ZERO)


# The first shot's climb at Weapons `tier` (the same recoil seed each time).
func _first_step(tier: int) -> Vector2:
	_shooter.set_tier(&"rifles", tier)
	_shooter.aim_at(_wall.global_position)
	_shooter.holder.seed_rng(41)
	_shooter.holder.state().cooldown = 0.0
	assert_int(_shooter.holder.trigger()).is_equal(WeaponState.Result.FIRED)
	return _shooter.holder.recoil.offset


# Seconds until the climb of the last shot is back to rest.
func _return_time() -> float:
	var ticks := 0
	while _shooter.holder.recoil.offset != Vector2.ZERO and ticks < 120:
		_shooter.tick()
		ticks += 1
	return ticks * Shooter.STEP


# Hit points of a 10-shot spray at the wall's centre (seed fixed), the eye following `share` of the
# climb; `pull`: the shooter pulls against each pattern step.
func _spray_hits(share: float, pull: bool = false) -> Array[Vector3]:
	var holder := _shooter.holder
	holder.recoil.view_share = share
	var wall := _wall.global_position
	_shooter.aim_at(Vector3(_shooter.user.global_position.x, wall.y + 0.2, wall.z))
	holder.seed_rng(23)
	holder.state().magazine = RIFLE.magazine_size
	holder.state().cooldown = 0.0
	var size := Attributes.read(_shooter.user, RIFLE.class_attribute("recoil_size_mult"), 1.0)
	var hits: Array[Vector3] = []
	holder.trigger_held = true
	var ticks := 0
	while hits.size() < 10 and ticks < 120:
		ticks += 1
		if not _shooter.tick():
			continue
		if not holder.last_hit.is_empty():
			hits.append(holder.last_hit["position"] as Vector3)
		if pull:
			_shooter.pull(-RIFLE.recoil.pattern_step(hits.size() - 1) * RIFLE.recoil.pattern_scale * size)
	holder.trigger_held = false
	StimulusSystem.clear()
	await get_tree().physics_frame
	return hits


func _mean(points: Array[Vector3]) -> Vector3:
	var total := Vector3.ZERO
	for point in points:
		total += point
	return total / float(maxi(points.size(), 1))


func _setup(weapon: WeaponData) -> void:
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	_shooter = Shooter.new(root, ORIGIN, [weapon] as Array[WeaponData])
	_wall = Shooter.plate(root, ORIGIN + Vector3(0, Shooter.EYE, -WALL_DISTANCE), Vector3(12, 8, 0.4))
	for i in 2:
		await get_tree().physics_frame
