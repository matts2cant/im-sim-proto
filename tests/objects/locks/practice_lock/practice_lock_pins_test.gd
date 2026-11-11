extends GdUnitTestSuite
## Unit/integration: PracticeLockPins, the visible pins of a see-through lock prop. One scene serves
## every practice tier: the acrylic practice lock shows as many key pins and drivers as its tier has
## (3, 5, 5, 6), centred inside the acrylic; any entity with a MechanicalLock shows its own pin count
## (generality); a re-lock lays the pins out at new heights, each driver resting on its key pin.

const PRACTICE: PackedScene = preload("res://objects/locks/practice_lock/practice_lock.tscn")
const COUNTS: Array[int] = [3, 5, 5, 6]


func test_the_practice_lock_shows_its_tiers_pins() -> void:
	for tier in COUNTS.size():
		var body := _practice(tier)
		var pins := body.get_node("Pins") as PracticeLockPins
		var acrylic := (body.get_node("Acrylic") as MeshInstance3D).get_aabb()
		var where := "tier %d" % tier
		assert_int(pins.shown_count()).override_failure_message(where).is_equal(COUNTS[tier])
		assert_int(pins.get_child_count()).override_failure_message(where).is_equal(COUNTS[tier] * 2)
		var xs: Array[float] = []
		for key_pin in pins.key_pins():
			xs.append(key_pin.position.x)
		# Centred, evenly spaced, inside the acrylic body.
		assert_float(xs[0] + xs[-1]).override_failure_message(where).is_equal_approx(0.0, 0.0001)
		assert_float(xs[1] - xs[0]).override_failure_message(where).is_equal_approx(pins.spacing, 0.0001)
		assert_float(xs[-1] + 0.006).override_failure_message(where).is_less(acrylic.end.x)


func test_any_mechanical_lock_entity_shows_its_pin_count() -> void:
	var entity := auto_free(Node3D.new()) as Node3D
	var lockable := Lockable.new()
	lockable.locked = true
	entity.add_child(lockable)
	var lock := MechanicalLock.new()
	lock.data = MechanicalLockData.new()
	lock.data.pins = [&"standard", &"spool", &"standard", &"serrated"] as Array[StringName]
	entity.add_child(lock)
	var pins := PracticeLockPins.new()
	pins.key_pin_mesh = CylinderMesh.new()
	pins.driver_mesh = CylinderMesh.new()
	entity.add_child(pins)
	add_child(entity)

	assert_int(pins.shown_count()).is_equal(4)


func test_a_relock_lays_the_pins_out_anew() -> void:
	var body := _practice(MechanicalLockData.Tier.HIGH_SECURITY)
	var pins := body.get_node("Pins") as PracticeLockPins
	var before := _heights(pins)

	(body.get_node("MechanicalLock") as MechanicalLock).relocked.emit(2)

	var after := _heights(pins)
	assert_array(after).is_not_equal(before)
	var key_half := pins.key_pin_mesh.get_aabb().size.y * 0.5
	var driver_half := pins.driver_mesh.get_aabb().size.y * 0.5
	for index in pins.shown_count():
		var key_pin := pins.key_pins()[index]
		var driver := pins.get_node("Driver%d" % (index + 1)) as Node3D
		assert_float(key_pin.position.y).is_between(pins.key_pin_low, pins.key_pin_low + pins.key_pin_rise)
		assert_float(driver.position.y - driver_half - (key_pin.position.y + key_half)).is_equal_approx(
			pins.driver_gap, 0.0001
		)


func _practice(tier: int) -> StaticBody3D:
	var body := auto_free(PRACTICE.instantiate()) as StaticBody3D
	var lock := body.get_node("MechanicalLock") as MechanicalLock
	lock.data = lock.data.duplicate() as MechanicalLockData
	lock.data.practice_tier = tier as MechanicalLockData.Tier
	body.position = Vector3(0, -100, 900)
	add_child(body)
	return body


static func _heights(pins: PracticeLockPins) -> Array[float]:
	var result: Array[float] = []
	for key_pin in pins.key_pins():
		result.append(key_pin.position.y)
	return result
