extends GdUnitTestSuite
## Skill-to-aim blend (ADR 0120 targets, ADR 0123): a still shooter built from components
## (shooter_fixtures.gd, recoil on) fires at a standing guard's torso (a 0.44 x 0.62 m plate) 10 m
## away, centre to centre (eye to plate centre), at each Weapons tier; the share of shots on the
## plate per tier.
## - Pistol: a shot every 1.0 s (a short pause: the kick has returned, the cone has nearly settled),
##   200 shots. Targets ~55 / 75 / 90 / 100 %.
## - Assault rifle: 20 sprays of 10 shots, trigger held, the cone settled and the recoil at rest
##   before each; the shooter pulls against the learned pattern (each shot's pattern step at its
##   skill's size, the moment it climbs; the noise is not pulled), blooming the cone like mouse look.
##   Targets ~30 / 50 / 70 / 85 %.
## The tolerance is +-10 points; each run prints a MEASURED line.

const Shooter := preload("res://tests/items/weapons/shooter_fixtures.gd")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const ORIGIN := Vector3(-600, 0, 300)
const DISTANCE := 10.0
const PISTOL_TARGETS: Array[float] = [0.55, 0.75, 0.90, 1.0]
const RIFLE_TARGETS: Array[float] = [0.30, 0.50, 0.70, 0.85]
const TOLERANCE := 0.10
const PISTOL_SHOTS := 200
const PISTOL_PAUSE := 1.0
## Ticks of the pause between pistol shots (the cone and recoil decays are exact for any step).
const PAUSE_TICKS := 10
const SPRAYS := 20
const SPRAY_SHOTS := 10

var _shooter: Shooter
var _plate: StaticBody3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_pistol_hit_share_per_tier_at_10_m() -> void:
	await _setup(PISTOL)
	var shares: Array[float] = []
	for tier in 4:
		_shooter.set_tier(&"pistols", tier)
		shares.append(_pistol_share())
	print("MEASURED pistol hit share at 10 m per tier: ", _percent(shares))
	_assert_near(shares, PISTOL_TARGETS)


func test_rifle_compensated_spray_hit_share_per_tier_at_10_m() -> void:
	await _setup(RIFLE)
	var shares: Array[float] = []
	for tier in 4:
		_shooter.set_tier(&"rifles", tier)
		shares.append(_spray_share())
	print("MEASURED assault rifle 10-shot compensated spray hit share at 10 m per tier: ", _percent(shares))
	_assert_near(shares, RIFLE_TARGETS)


func test_master_first_still_shot_is_exact() -> void:
	await _setup(PISTOL)
	_shooter.set_tier(&"pistols", 3)
	_shooter.aim_at(_plate.global_position)
	assert_float(_shooter.holder.aim.spread).is_equal(0.0)
	_shooter.set_tier(&"pistols", 0)
	_shooter.aim_at(_plate.global_position)
	assert_float(_shooter.holder.aim.spread).is_equal_approx(PISTOL.aim_config.base_min_deg, 0.0001)


func _pistol_share() -> float:
	_shooter.aim_at(_plate.global_position)
	var holder := _shooter.holder
	var hits := 0
	for shot in PISTOL_SHOTS:
		holder.state().magazine = PISTOL.magazine_size
		assert_int(holder.trigger()).is_equal(WeaponState.Result.FIRED)
		if _on_plate():
			hits += 1
		for tick in PAUSE_TICKS:
			_shooter.tick(PISTOL_PAUSE / PAUSE_TICKS)
	StimulusSystem.clear()
	return hits / float(PISTOL_SHOTS)


func _spray_share() -> float:
	var holder := _shooter.holder
	var size := Attributes.read(_shooter.user, RIFLE.class_attribute("recoil_size_mult"), 1.0)
	var hits := 0
	for spray in SPRAYS:
		_shooter.aim_at(_plate.global_position)
		holder.state().magazine = RIFLE.magazine_size
		holder.state().cooldown = 0.0
		holder.trigger_held = true
		var fired := 0
		var ticks := 0
		while fired < SPRAY_SHOTS and ticks < 120:
			ticks += 1
			if not _shooter.tick():
				continue
			if _on_plate():
				hits += 1
			# The learned pull-down: against the pattern step this shot climbed.
			_shooter.pull(-RIFLE.recoil.pattern_step(fired) * RIFLE.recoil.pattern_scale * size)
			fired += 1
		holder.trigger_held = false
		assert_int(fired).is_equal(SPRAY_SHOTS)
		StimulusSystem.clear()
	return hits / float(SPRAYS * SPRAY_SHOTS)


func _on_plate() -> bool:
	return not _shooter.holder.last_hit.is_empty() and _shooter.holder.last_hit["collider"] == _plate


func _assert_near(shares: Array[float], targets: Array[float]) -> void:
	for tier in 4:
		assert_float(shares[tier]).override_failure_message("tier %d: %s" % [tier, _percent(shares)]).is_between(
			targets[tier] - TOLERANCE, minf(targets[tier] + TOLERANCE, 1.0)
		)


func _percent(shares: Array[float]) -> String:
	return " / ".join(shares.map(func(share: float) -> String: return "%.0f %%" % (share * 100.0)))


func _setup(weapon: WeaponData) -> void:
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	_shooter = Shooter.new(root, ORIGIN, [weapon] as Array[WeaponData])
	_plate = Shooter.plate(root, ORIGIN + Vector3(0, Shooter.EYE, -DISTANCE))
	# The plate and the shooter join the physics space on the next step.
	for i in 2:
		await get_tree().physics_frame
