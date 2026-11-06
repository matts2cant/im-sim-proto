extends GdUnitTestSuite
## Unit/integration: the held view model. The baton pivots about its grip (the hand), points up and
## forward at rest and chops down across the view; the pistol keeps its own pose.

const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")

var _holder: WeaponHolder


func before_test() -> void:
	_holder = auto_free(WeaponHolder.new())
	_holder.aim_config = AimConfig.new()
	_holder.weapons = [BATON, PISTOL] as Array[WeaponData]
	add_child(_holder)
	_holder.setup(null, null)


func test_baton_rest_pose_points_up_and_forward_from_the_grip() -> void:
	_holder.equip(0)

	var pivot := _holder.view_pivot()
	var tip := _tip()
	assert_vector(pivot.position).is_equal_approx(BATON.view_offset, Vector3.ONE * 0.001)
	var shaft := (tip - pivot.position).normalized()
	var elevation := rad_to_deg(asin(shaft.y))
	assert_float(elevation).is_between(50.0, 70.0)
	assert_float(shaft.z).is_less(-0.3)
	# Tilted inwards: the tip is nearer the centre line than the grip.
	assert_float(tip.x).is_less(pivot.position.x)
	# The grip end is the low end, in the lower right of the view.
	assert_float(pivot.position.y).is_less(0.0)
	assert_float(pivot.position.x).is_greater(0.0)


func test_baton_swing_keeps_the_grip_and_moves_the_tip() -> void:
	_holder.equip(0)
	var grip_rest := _grip()
	var tip_rest := _tip()
	var max_tip_move := 0.0
	for progress: float in [0.1, 0.2, 0.3, 0.4, 0.7, 1.0]:
		_holder.preview_swing(progress)
		assert_vector(_grip()).is_equal_approx(grip_rest, Vector3.ONE * 0.03)
		max_tip_move = maxf(max_tip_move, _tip().distance_to(tip_rest))
	assert_float(max_tip_move).is_greater(0.2)
	# The chop sends the tip forward and down across the view.
	_holder.preview_swing(0.3)
	assert_float(_tip().y).is_less(tip_rest.y - 0.2)
	assert_float(_tip().x).is_less(tip_rest.x)
	# The swing ends back in the ready pose.
	_holder.preview_swing(1.0)
	assert_vector(_tip()).is_equal_approx(tip_rest, Vector3.ONE * 0.001)


func test_pistol_pose_is_unchanged() -> void:
	_holder.equip(1)

	assert_vector(_holder.view_pivot().position).is_equal_approx(PISTOL.view_offset, Vector3.ONE * 0.001)
	assert_vector(_holder.get_node("ViewPivot/ViewModel").position).is_equal(Vector3.ZERO)
	assert_bool(_holder.view_pivot().transform.basis.is_equal_approx(Basis.IDENTITY)).is_true()


## The grip end of the box, in camera space.
func _grip() -> Vector3:
	return _end(0.5)


func _tip() -> Vector3:
	return _end(-0.5)


# `side` * half the box length along the box axis, in the holder's frame.
func _end(side: float) -> Vector3:
	var model := _holder.get_node("ViewPivot/ViewModel") as Node3D
	return _holder.view_pivot().transform * (model.position + Vector3(0, 0, side * BATON.view_size.z))
