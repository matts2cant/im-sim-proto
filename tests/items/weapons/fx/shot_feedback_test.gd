extends GdUnitTestSuite
## ShotFeedback (ADR 0126) on a shooter built from components (shooter_fixtures.gd): every holder's
## shots leave impacts by material and tracers through the viewport's ShotFx, whoever shoots. A
## tracer every third round of the automatic weapons (WeaponData.tracer_every), every round when
## the holder asks (guards' tracer_every 1), none from the pistol; bullets hole concrete and metal,
## puff on bodies without a hole; a baton on a body sparks blue-white, on a wall does nothing.
## Distances are centre to centre from the shooter's feet.

const Shooter := preload("res://tests/items/weapons/shooter_fixtures.gd")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const SMG: WeaponData = preload("res://items/weapons/smg/smg.tres")
const SHOTGUN: WeaponData = preload("res://items/weapons/shotgun/shotgun.tres")
const SNIPER: WeaponData = preload("res://items/weapons/sniper_rifle/sniper_rifle.tres")
const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")
const GUARD: PackedScene = preload("res://actors/guard/guard.tscn")
const PLAYER: PackedScene = preload("res://actors/player/player.tscn")
const DUMMY: PackedScene = preload("res://actors/dummy/training_dummy.tscn")
const ORIGIN := Vector3(640, 0, -360)

var _root: Node3D
var _fx: ShotFx


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_fx = ShotFx.in_world(self)
	_fx.clear()


func after_test() -> void:
	StimulusSystem.clear()
	_fx.clear()


func test_every_third_round_of_the_automatic_weapons_has_a_tracer() -> void:
	assert_int(RIFLE.tracer_every).is_equal(3)
	assert_int(SMG.tracer_every).is_equal(3)
	for weapon: WeaponData in [PISTOL, SHOTGUN, SNIPER, BATON]:
		assert_int(weapon.tracer_every).override_failure_message(String(weapon.id)).is_equal(0)
	var shooter := _shooter(RIFLE)
	var target := _plate(Vector3(0, 1.4, -10))
	await _settle()

	_fire(shooter, target, 9)

	assert_int(_fx.tracers_started).is_equal(3)
	# From the muzzle to the plate's front face (0.13 m before its centre).
	var tracer := _fx.last_tracer()
	assert_float(tracer.end.z - ORIGIN.z).is_equal_approx(-9.87, 0.02)
	assert_float(tracer.start.distance_to(shooter.eye.global_position)).is_less(1.2)


func test_a_holder_asking_for_every_round_traces_each_shot() -> void:
	var shooter := _shooter(PISTOL)
	shooter.holder.tracer_every = 1
	var target := _plate(Vector3(0, 1.4, -10))
	await _settle()

	_fire(shooter, target, 4)

	assert_int(_fx.tracers_started).is_equal(4)


func test_pistol_shots_leave_no_tracer() -> void:
	var shooter := _shooter(PISTOL)
	var target := _plate(Vector3(0, 1.4, -10))
	await _settle()

	_fire(shooter, target, 4)

	assert_int(_fx.tracers_started).is_equal(0)
	assert_int(_fx.holes.count()).is_equal(4)


func test_guards_trace_every_shot_the_player_by_the_weapon() -> void:
	assert_int(_holder_tracer_every(GUARD)).is_equal(1)
	assert_int(_holder_tracer_every(PLAYER)).is_equal(0)


func test_bullets_hole_concrete_and_spark_on_metal() -> void:
	var shooter := _shooter(PISTOL)
	var concrete := _plate(Vector3(-0.5, 1.4, -8))
	var metal := _plate(Vector3(0.5, 1.4, -8))
	metal.set_meta(&"surface", &"metal")
	await _settle()

	_fire(shooter, concrete, 1)
	_fire(shooter, metal, 1)

	assert_int(_fx.puffs_played.get(&"concrete", 0)).is_equal(1)
	assert_int(_fx.puffs_played.get(&"metal", 0)).is_equal(1)
	assert_int(_fx.holes.count()).is_equal(2)


func test_a_body_hit_puffs_dark_red_without_a_hole() -> void:
	var shooter := _shooter(PISTOL)
	var dummy := _dummy(Vector3(0, 0, -5))
	await _settle()

	_fire(shooter, dummy.hitboxes.box(&"torso").global_position, 1)

	assert_int(_fx.puffs_played.get(ShotFxConfig.BODY, 0)).is_equal(1)
	assert_int(_fx.hole_count()).is_equal(0)


func test_a_baton_hit_on_a_body_sparks_on_a_wall_does_nothing() -> void:
	var shooter := _shooter(BATON)
	var dummy := _dummy(Vector3(0, 0, -1.2))
	await _settle()

	_fire(shooter, dummy.hitboxes.box(&"torso").global_position, 1)

	assert_int(_fx.puffs_played.get(ShotFxConfig.STUN, 0)).is_equal(1)
	assert_int(_fx.puffs_played.get(ShotFxConfig.BODY, 0)).is_equal(0)

	dummy.global_position = ORIGIN + Vector3(0, 0, -100)
	var wall := _plate(Vector3(0, 1.4, -1.2))
	await _settle()
	_fx.clear()
	_fire(shooter, wall, 1)

	assert_bool(_fx.puffs_played.is_empty()).is_true()
	assert_int(_fx.hole_count()).is_equal(0)


func _shooter(weapon: WeaponData) -> Shooter:
	return Shooter.new(_root, ORIGIN, [weapon] as Array[WeaponData])


# A torso-sized static plate (no surface data: concrete) centred `offset` from ORIGIN.
func _plate(offset: Vector3) -> StaticBody3D:
	return Shooter.plate(_root, ORIGIN + offset)


func _dummy(offset: Vector3) -> TrainingDummy:
	var dummy := DUMMY.instantiate() as TrainingDummy
	_root.add_child(dummy)
	# Facing the shooter (+Z).
	dummy.global_transform = Transform3D(Basis(Vector3.UP, PI), ORIGIN + offset)
	return dummy


func _settle() -> void:
	for i in 3:
		await get_tree().physics_frame


# `times` exact shots (no cone) at `target` (a point, or a body's centre), the recoil at rest.
func _fire(shooter: Shooter, target: Variant, times: int) -> void:
	var point: Vector3 = (target as Node3D).global_position if target is Node3D else target
	for i in times:
		shooter.aim_at(point)
		shooter.holder.aim.spread = 0.0
		shooter.holder.state().cooldown = 0.0
		shooter.holder.trigger()


# The tracer_every of the WeaponHolder node a scene saves (0 when it keeps the default).
func _holder_tracer_every(scene: PackedScene) -> int:
	var state := scene.get_state()
	for node in state.get_node_count():
		if state.get_node_name(node) != &"WeaponHolder":
			continue
		for property in state.get_node_property_count(node):
			if state.get_node_property_name(node, property) == &"tracer_every":
				return int(state.get_node_property_value(node, property))
	return 0
