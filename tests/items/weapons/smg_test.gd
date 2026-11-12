extends GdUnitTestSuite
## The submachine gun (ADR 0120, ADR 0123): its data, and measured outcomes against a standing target
## with the guards' body (training dummy with guard_body.tres: torso 80, head 40, head x2), fired by
## a shooter built from components (shooter_fixtures.gd) holding the trigger and pulling against the
## learned pattern (the noise is not pulled), aimed at the torso centre, over fixed seeds. Distances
## are centre to centre (shooter's feet to the dummy's feet). Each test prints a MEASURED line.
## - Untrained, 5 m: kills in 0.6-0.7 s (the median).
## - 20 m: clearly worse than the assault rifle (Master: median time to kill at least 1.3 x the rifle's;
##   Untrained: kills in fewer runs within a magazine): damage falloff past 8 m does it.

const Shooter := preload("res://tests/items/weapons/shooter_fixtures.gd")
const SMG: WeaponData = preload("res://items/weapons/smg/smg.tres")
const SMG_ITEM: ItemData = preload("res://items/weapons/smg/smg_item.tres")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const CATALOG: ItemCatalog = preload("res://items/item_catalog.tres")
const DUMMY: PackedScene = preload("res://actors/dummy/training_dummy.tscn")
const GUARD_BODY: BodyProfile = preload("res://actors/guard/guard_body.tres")
const ORIGIN := Vector3(600, 0, -300)
const SEEDS: Array[int] = [11, 23, 37, 41]
## Frames a run may last: past a 30-round magazine of either weapon.
const MAX_FRAMES := 180
## Out of every weapon's reach.
const FAR := Vector3(0, 0, -300)

var _shooter: Shooter
var _dummy: TrainingDummy


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_smg_data() -> void:
	assert_float(SMG.damage[&"damage.ballistic"]).is_equal(9.0)
	assert_float(SMG.cycle_time).is_equal_approx(0.07, 0.0001)
	assert_int(SMG.magazine_size).is_equal(30)
	assert_float(SMG.reload_time).is_equal_approx(1.8, 0.0001)
	assert_float(SMG.max_range).is_equal(40.0)
	assert_float(SMG.fire_noise).is_equal(22.0)
	assert_bool(SMG.automatic).is_true()
	assert_str(String(SMG.attribute_class)).is_equal("pistol")
	assert_str(String(SMG.ammo_item)).is_equal("pistol_ammo")
	assert_array(SMG.attachment_slots).contains([&"muzzle"])
	assert_object(CATALOG.find(&"smg")).is_same(SMG_ITEM)
	assert_object(SMG_ITEM.weapon).is_same(SMG)


func test_held_trigger_keeps_the_0_07_s_rhythm_at_60_steps_a_second() -> void:
	await _setup(SMG)
	var holder := _shooter.holder
	holder.state().magazine = 60
	holder.trigger_held = true
	var shots := 0
	# 1.4 s: 20 cycles of 0.07 s (a shot at the start of each), not 17 whole 5-step cycles.
	for tick in 84:
		if _shooter.tick():
			shots += 1
	holder.trigger_held = false
	StimulusSystem.clear()
	assert_int(shots).is_between(20, 21)


func test_untrained_smg_kills_at_5_m_in_0_6_to_0_7_s() -> void:
	await _setup(SMG)
	var times := await _times_to_kill(SMG, 5.0)
	print("MEASURED SMG Untrained 5 m time to kill pulling the recoil (s, sorted): ", times)
	assert_float(_median(times)).override_failure_message("%s" % [times]).is_between(0.58, 0.75)
	assert_float(times[-1]).override_failure_message("%s" % [times]).is_less(1.0)


func test_smg_is_clearly_worse_than_the_rifle_at_20_m() -> void:
	await _setup(SMG)
	var smg_untrained := await _times_to_kill(SMG, 20.0)
	_shooter.set_tier(&"pistols", 3)
	var smg_master := await _times_to_kill(SMG, 20.0)
	await _rearm(RIFLE)
	var rifle_untrained := await _times_to_kill(RIFLE, 20.0)
	_shooter.set_tier(&"rifles", 3)
	var rifle_master := await _times_to_kill(RIFLE, 20.0)
	print(
		(
			(
				"MEASURED 20 m time to kill (s, sorted; %.2f = alive after a magazine): "
				+ "SMG untrained %s master %s, rifle untrained %s master %s"
			)
			% [MAX_FRAMES * Shooter.STEP, smg_untrained, smg_master, rifle_untrained, rifle_master]
		)
	)
	assert_float(_median(smg_master)).is_greater_equal(_median(rifle_master) * 1.3)
	# Untrained, both often empty a magazine without a kill at 20 m: the SMG kills in fewer runs,
	# and no faster.
	assert_int(_kills(smg_untrained)).is_less(_kills(rifle_untrained))
	assert_float(_median(smg_untrained)).is_greater_equal(_median(rifle_untrained))


# Seconds the drawn weapon takes to kill the dummy `distance` m away per seed (sorted; MAX_FRAMES
# when it survives).
func _times_to_kill(weapon: WeaponData, distance: float) -> Array[float]:
	var times: Array[float] = []
	var holder := _shooter.holder
	var size := Attributes.read(_shooter.user, weapon.class_attribute("recoil_size_mult"), 1.0)
	for seed in SEEDS:
		_dummy.reset()
		_dummy.global_position = ORIGIN + Vector3(0, 0, -distance)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_shooter.aim_at(_dummy.hitboxes.box(&"torso").global_position)
		holder.seed_rng(seed)
		holder.state().magazine = 60
		holder.state().cooldown = 0.0
		holder.trigger_held = true
		var fired := 0
		var frames := 0
		while not _dummy.body.is_dead() and frames < MAX_FRAMES:
			await get_tree().physics_frame
			frames += 1
			if _shooter.tick():
				_shooter.pull(-weapon.recoil.pattern_step(fired) * weapon.recoil.pattern_scale * size)
				fired += 1
		holder.trigger_held = false
		times.append(frames * Shooter.STEP)
	_dummy.global_position = ORIGIN + FAR
	times.sort()
	return times


func _kills(times: Array[float]) -> int:
	return times.filter(func(time: float) -> bool: return time < MAX_FRAMES * Shooter.STEP - 0.001).size()


func _median(times: Array[float]) -> float:
	return (times[times.size() / 2 - 1] + times[times.size() / 2]) * 0.5


func _setup(weapon: WeaponData) -> void:
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	_shooter = Shooter.new(root, ORIGIN, [weapon] as Array[WeaponData])
	_dummy = DUMMY.instantiate() as TrainingDummy
	(_dummy.get_node("BodyParts") as BodyParts).profile = GUARD_BODY
	root.add_child(_dummy)
	# Facing the shooter (+Z), like the weapon range's target.
	_dummy.global_transform = Transform3D(Basis(Vector3.UP, PI), ORIGIN + FAR)
	for i in 3:
		await get_tree().physics_frame


# A new shooter holding `weapon` in place of the old one (same spot, fresh skills).
func _rearm(weapon: WeaponData) -> void:
	var root := _shooter.root.get_parent()
	_shooter.root.queue_free()
	await get_tree().physics_frame
	_shooter = Shooter.new(root, ORIGIN, [weapon] as Array[WeaponData])
	await get_tree().physics_frame
