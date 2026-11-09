extends GdUnitTestSuite
## Integration (ADR 0085): pellets, automatic fire, the scope and attachments are WeaponData and
## WeaponHolder features, not the player's: a minimal character built in code (no Player, no
## inventory) holding a fixed loadout fires 8 pellets, keeps firing while its trigger is held,
## scopes, and is quieter with a silencer fitted to its WeaponState.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const SHOTGUN: WeaponData = preload("res://items/weapons/shotgun/shotgun.tres")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const SNIPER: WeaponData = preload("res://items/weapons/sniper_rifle/sniper_rifle.tres")
const SILENCER: ItemData = preload("res://items/attachments/silencer/silencer.tres")
const STEP := 1.0 / 60.0

var _holder: WeaponHolder
var _user: CharacterBody3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	# A wall 6 m ahead (-Z) for the rays to hit.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 6, 0.4)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.position = Vector3(300, 2, -6)
	_user = Characters.character(root, "Shooter", Vector3(300, 0, 0), [])
	var eye := Node3D.new()
	eye.name = "Eye"
	eye.position.y = 1.6
	_user.add_child(eye)
	_holder = WeaponHolder.new()
	_holder.aim_config = AimConfig.new()
	_holder.rng_seed = 7
	_holder.weapons = [SHOTGUN, RIFLE, SNIPER] as Array[WeaponData]
	eye.add_child(_holder)
	_holder.setup(_user, eye)
	# The wall joins the physics space on the next step.
	await _physics(2)


func test_any_holder_fires_pellets() -> void:
	_holder.equip(0)
	assert_int(_holder.trigger()).is_equal(WeaponState.Result.FIRED)
	await _physics(2)
	var fired := EventLog.find(&"weapon.fired")
	assert_int(fired[0].data["projectiles"]).is_equal(8)
	assert_int(fired[0].data["hits"]).is_equal(8)
	var damage := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"damage.ballistic"
	)
	assert_array(damage).has_size(8)


func test_any_holder_fires_automatically_while_its_trigger_is_held() -> void:
	_holder.equip(1)
	_holder.trigger_held = true
	for tick in 30:
		_holder.physics_step(STEP, AimModel.Stance.STILL)
	assert_int(EventLog.find(&"weapon.fired").size()).is_equal(5)
	_holder.trigger_held = false
	for tick in 30:
		_holder.physics_step(STEP, AimModel.Stance.STILL)
	assert_int(EventLog.find(&"weapon.fired").size()).is_equal(5)
	# Sustained fire bloomed the cone above the rifle's floor.
	assert_float(_holder.aim.config.base_min_deg).is_equal(RIFLE.aim_config.base_min_deg)


func test_any_holder_scopes_and_its_view_fov_follows() -> void:
	_holder.equip(2)
	assert_bool(_holder.toggle_scope()).is_true()
	for tick in 12:
		_holder.physics_step(STEP, AimModel.Stance.STILL)
	assert_float(_holder.scope.view_fov(_holder.weapon(), 70.0)).is_equal(SNIPER.scope_fov)
	assert_object(_holder.aim.config).is_same(SNIPER.scope_aim_config)
	_holder.equip(0)
	assert_bool(_holder.scope.scoped).is_false()
	assert_float(_holder.scope.view_fov(_holder.weapon(), 70.0)).is_equal(70.0)


func test_any_holder_shoots_quieter_with_a_silencer() -> void:
	_holder.equip(1)
	assert_bool(_holder.state().attach(SILENCER.attachment)).is_true()
	_holder.trigger()
	await _physics(2)
	var noises := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise"
	)
	assert_float(noises[0].data["intensity"]).is_equal_approx(RIFLE.fire_noise * 0.25, 0.0001)


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
