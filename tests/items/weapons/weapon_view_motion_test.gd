extends GdUnitTestSuite
## Integration (ADR 0128): a WeaponHolder with `view_motion` on, held by a minimal user (a
## CharacterBody3D with Tags, moved by the test), stepped through physics_step() at 60 Hz.
## - Draw: switching weapons drops the new one out of its ready pose and raises it over its
##   draw_time; holstering lowers the drawn one, then hides it.
## - Reload: the model dips mid-reload and is back in its pose when the reload ends.
## - Bob: the model bobs while the user walks (its position moving), not while it stands.
## - Off (guards): the pose stays the plain recoil pose (no draw).

const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const DT := 1.0 / 60.0
const STILL := AimModel.Stance.STILL
const WALK := AimModel.Stance.WALK

var _holder: WeaponHolder
var _user: CharacterBody3D


func before_test() -> void:
	_user = auto_free(CharacterBody3D.new())
	var tags := Tags.new()
	tags.name = "Tags"
	_user.add_child(tags)
	add_child(_user)
	_holder = WeaponHolder.new()
	_holder.aim_config = AimConfig.new()
	_holder.weapons = [PISTOL, RIFLE] as Array[WeaponData]
	_holder.view_motion = true
	_user.add_child(_holder)
	_holder.setup(_user, _holder)


func test_switching_draws_the_new_weapon_up_into_view() -> void:
	_holder.equip(0)
	_steps(PISTOL.motion.draw_time + 0.05, STILL)
	var pistol_rest := _pivot().position
	assert_vector(pistol_rest).is_equal_approx(_rest(PISTOL), Vector3.ONE * 0.001)
	_holder.equip(1)
	# Just drawn: well below its ready pose, rising.
	assert_float(_pivot().position.y).is_less(_rest(RIFLE).y - RIFLE.motion.draw_drop * 0.9)
	_steps(RIFLE.motion.draw_time * 0.5, STILL)
	var middle := _pivot().position.y
	assert_float(middle).is_between(_rest(RIFLE).y - RIFLE.motion.draw_drop * 0.9, _rest(RIFLE).y - 0.01)
	_steps(RIFLE.motion.draw_time * 0.5 + 0.05, STILL)
	assert_vector(_pivot().position).is_equal_approx(_rest(RIFLE), Vector3.ONE * 0.001)


func test_holstering_lowers_the_weapon_then_hides_it() -> void:
	_holder.equip(0)
	_steps(PISTOL.motion.draw_time + 0.05, STILL)
	_holder.holster()
	assert_bool(_pivot().visible).is_true()
	assert_bool(_pivot().is_holstering()).is_true()
	_steps(PISTOL.motion.holster_time * 0.5, STILL)
	assert_float(_pivot().position.y).is_less(_rest(PISTOL).y - 0.05)
	_steps(PISTOL.motion.holster_time * 0.5 + 0.05, STILL)
	assert_bool(_pivot().visible).is_false()
	assert_object(_pivot().data).is_null()


func test_reload_dips_the_model_and_brings_it_back() -> void:
	_holder.equip(0)
	_steps(PISTOL.motion.draw_time + 0.05, STILL)
	_holder.state().magazine = 3
	assert_bool(_holder.reload()).is_true()
	var total := _holder.state().reload_total
	_steps(total * 0.5, STILL)
	assert_float(_pivot().position.y).is_less(_rest(PISTOL).y - PISTOL.motion.reload_drop * 0.9)
	_steps(total * 0.5 + 0.05, STILL)
	assert_bool(_holder.state().is_reloading()).is_false()
	assert_vector(_pivot().position).is_equal_approx(_rest(PISTOL), Vector3.ONE * 0.001)


func test_the_model_bobs_while_the_user_walks() -> void:
	_holder.equip(0)
	_steps(PISTOL.motion.draw_time + 0.05, STILL)
	var standing := _largest_move(1.0, 0.0, STILL)
	var walking := _largest_move(1.5, 4.0, WALK)
	assert_float(standing).is_less(0.0001)
	assert_float(walking).is_greater(PISTOL.motion.bob_height * 0.8)


func test_without_motion_the_view_keeps_its_pose() -> void:
	_holder.view_motion = false
	_holder.equip(0)
	assert_vector(_pivot().position).is_equal_approx(_rest(PISTOL), Vector3.ONE * 0.0001)
	_holder.holster()
	assert_bool(_pivot().visible).is_false()


func _pivot() -> WeaponView:
	return _holder.view_pivot()


func _rest(data: WeaponData) -> Vector3:
	return WeaponView.rest_position(data.view_offset, _holder.view_shift_deg)


func _steps(seconds: float, stance: AimModel.Stance) -> void:
	for i in roundi(seconds / DT):
		_holder.physics_step(DT, stance)


# Moves the user at `speed` m/s along -Z for `seconds` and returns the largest distance of the grip
# from its ready pose.
func _largest_move(seconds: float, speed: float, stance: AimModel.Stance) -> float:
	var largest := 0.0
	for i in roundi(seconds / DT):
		_user.position.z -= speed * DT
		_holder.physics_step(DT, stance)
		largest = maxf(largest, _pivot().position.distance_to(_rest(PISTOL)))
	return largest
