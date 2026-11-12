extends GdUnitTestSuite
## Integration (ADR 0127): an AI shooter's recoil compensation. A WeaponHolder with the assault rifle
## (recoil on, its pattern and noise; a cone of zero so each shot flies exactly along the aim) on a
## minimal user, driven the way CombatBehaviour drives it: the recoil's view_share is the
## compensation share, view_recoil() is called before each physics step and the eye stays on the
## target (it re-aims every tick). A 4-shot burst at a wide plate 10 m ahead (centre to centre from
## the eye to the plate, at eye height): with a share of 0 the shots climb by the whole pattern,
## with 1 they stay on the aim point, with 0.7 they keep 30 % of the climb.

const Shooter := preload("res://tests/items/weapons/shooter_fixtures.gd")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const DISTANCE := 10.0
const SHOTS := 4

var _root: Node3D
var _holder: WeaponHolder
var _eye: Node3D


func before_test() -> void:
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	var user := StaticBody3D.new()
	user.collision_layer = 0
	_root.add_child(user)
	_eye = Node3D.new()
	_eye.position.y = Shooter.EYE
	user.add_child(_eye)
	var no_cone := AimConfig.new()
	no_cone.base_min_deg = 0.0
	no_cone.shot_bloom_deg = 0.0
	no_cone.sway_deg = 0.0
	_holder = WeaponHolder.new()
	_holder.aim_config = no_cone
	_holder.weapon_aim = false
	_holder.recoil_enabled = true
	_holder.weapons = [RIFLE] as Array[WeaponData]
	_eye.add_child(_holder)
	_holder.setup(user, _eye)
	_holder.equip(0)
	Shooter.plate(_root, Vector3(0, Shooter.EYE, -DISTANCE), Vector3(12, 12, 0.2))
	for i in 2:
		await get_tree().physics_frame


func after_test() -> void:
	StimulusSystem.clear()


func test_the_compensation_share_pulls_back_that_much_of_the_pattern() -> void:
	var full := _burst(0.0)
	var none := _burst(1.0)
	var guard := _burst(0.7)
	print("MEASURED rifle burst rise at 10 m (deg): share 0 %s, share 0.7 %s, share 1 %s" % [full, guard, none])
	assert_int(full.size()).is_equal(SHOTS)
	# Share 0: the last shot climbed by the pattern's first three steps (x1.5 Untrained, plus noise).
	assert_float(full[-1]).is_greater(RecoilState.pattern_climb(RIFLE.recoil, SHOTS - 1).y * 0.4)
	for i in SHOTS:
		assert_float(none[i]).is_equal_approx(0.0, 0.01)
		# The same seed: the same pattern and noise, 30 % of it left.
		assert_float(guard[i]).is_equal_approx(full[i] * 0.3, 0.02)


# Elevation (degrees above the aim) of each shot of a burst with compensation `share`.
func _burst(share: float) -> Array[float]:
	_holder.seed_rng(17)
	_holder.recoil.reset()
	_holder.recoil.view_share = share
	_holder.state().magazine = RIFLE.magazine_size
	_holder.state().cooldown = 0.0
	var rises: Array[float] = []
	_holder.recoil.view_recoil()
	_holder.physics_step(Shooter.STEP, AimModel.Stance.STILL)
	if _holder.trigger() == WeaponState.Result.FIRED:
		rises.append(_rise())
	_holder.trigger_held = true
	for tick in 60:
		if rises.size() >= SHOTS:
			break
		var magazine := _holder.state().magazine
		_holder.recoil.view_recoil()
		_holder.physics_step(Shooter.STEP, AimModel.Stance.STILL)
		if _holder.state().magazine < magazine:
			rises.append(_rise())
	_holder.trigger_held = false
	return rises


func _rise() -> float:
	var point: Vector3 = _holder.last_hit.get("position", _eye.global_position)
	return rad_to_deg(atan2(point.y - _eye.global_position.y, DISTANCE - 0.1))
