extends GdUnitTestSuite
## Unit/integration: the held view model. The baton pivots about its grip (the hand), points up and
## forward at rest and chops down across the view; a weapon without a model (the guards' pistol) is
## a box in its own pose; a weapon with a model (the pistol, ADR 0085) shows it instead of the box,
## its muzzle flash at the model's muzzle, and a fitted silencer at the muzzle mount.

const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")
const BOX_PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol_unsilenced.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const SILENCER: ItemData = preload("res://items/attachments/silencer/silencer.tres")

var _holder: WeaponHolder


func before_test() -> void:
	_holder = auto_free(WeaponHolder.new())
	_holder.aim_config = AimConfig.new()
	_holder.weapons = [BATON, BOX_PISTOL, PISTOL] as Array[WeaponData]
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
		_holder.view_pivot().preview_swing(progress)
		assert_vector(_grip()).is_equal_approx(grip_rest, Vector3.ONE * 0.03)
		max_tip_move = maxf(max_tip_move, _tip().distance_to(tip_rest))
	assert_float(max_tip_move).is_greater(0.2)
	# The chop sends the tip forward and down across the view.
	_holder.view_pivot().preview_swing(0.3)
	assert_float(_tip().y).is_less(tip_rest.y - 0.2)
	assert_float(_tip().x).is_less(tip_rest.x)
	# The swing ends back in the ready pose.
	_holder.view_pivot().preview_swing(1.0)
	assert_vector(_tip()).is_equal_approx(tip_rest, Vector3.ONE * 0.001)


func test_box_pistol_pose_is_unchanged() -> void:
	_holder.equip(1)

	assert_vector(_holder.view_pivot().position).is_equal_approx(BOX_PISTOL.view_offset, Vector3.ONE * 0.001)
	assert_vector(_holder.get_node("ViewPivot/ViewModel").position).is_equal(Vector3.ZERO)
	assert_bool(_holder.view_pivot().transform.basis.is_equal_approx(Basis.IDENTITY)).is_true()
	assert_object(_holder.view_pivot().model).is_null()
	assert_object((_holder.get_node("ViewPivot/ViewModel") as MeshInstance3D).mesh).is_not_null()


func test_a_weapon_with_a_model_shows_it_with_the_flash_at_its_muzzle() -> void:
	_holder.equip(2)

	var model := _holder.view_pivot().model
	assert_object(model).is_not_null()
	assert_object((_holder.get_node("ViewPivot/ViewModel") as MeshInstance3D).mesh).is_null()
	assert_object(_holder.flash.get_parent()).is_same(model.muzzle_point())
	_holder.flash.hold(PISTOL)
	# In front of the barrel's end.
	assert_float(_holder.flash.position.z).is_less(0.0)
	assert_float(_holder.flash.global_position.distance_to(model.muzzle_point().global_position)).is_less(0.1)


func test_a_fitted_silencer_shows_at_the_muzzle_and_moves_it_forward() -> void:
	_holder.equip(2)
	var bare_muzzle := _holder.view_pivot().model.muzzle_point().global_position

	# Fitting it to the drawn weapon's state rebuilds the view.
	_holder.state().attach(SILENCER.attachment)

	var model := _holder.view_pivot().model
	assert_array(model.fitted_models()).has_size(1)
	assert_object(model.fitted_models()[0].get_parent()).is_same(model.mount_for(&"muzzle"))
	# The muzzle (flash, shot noise) moved to the silencer's end, further along -Z.
	var forward := -_holder.view_pivot().global_basis.z
	assert_float((model.muzzle_point().global_position - bare_muzzle).dot(forward)).is_greater(0.1)
	# Switching away and back keeps one silencer.
	_holder.equip(0)
	_holder.equip(2)
	assert_array(_holder.view_pivot().model.fitted_models()).has_size(1)


## The grip end of the box, in camera space.
func _grip() -> Vector3:
	return _end(0.5)


func _tip() -> Vector3:
	return _end(-0.5)


# `side` * half the box length along the box axis, in the holder's frame.
func _end(side: float) -> Vector3:
	var model := _holder.get_node("ViewPivot/ViewModel") as Node3D
	return _holder.view_pivot().transform * (model.position + Vector3(0, 0, side * BATON.view_size.z))
