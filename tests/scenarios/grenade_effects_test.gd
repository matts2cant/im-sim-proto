extends GdUnitTestSuite
## Scenario (ADR 0131, M14a x M14b): the shipped grenade entities (m14a: Fuse, Sticky,
## ProximityTrigger, Breakable) set off through `Explosive.explode()` release their payloads (m14b),
## whatever set them off:
## - a gas grenade thrown by a minimal character leaves a gas cloud where it lands, 2.5 s after the
##   throw (none at 2.3 s);
## - an EMP mine stuck on the floor, set off by a character walking at it, switches a camera 3 m away
##   off;
## - a frag mine set off by a walking character sets off an explosive barrel 3 m away (a chain);
## - a damage ray (a shot) on a stuck jamming grenade sets it off: a jamming field starts.
## Each case has its own spot 30 m from the others (x east): gas lane (0, 0, 0) to -Z, EMP (30, 0,
## 0), frag (60, 0, 0), jammer (90, 0, 0). Distances centre to centre unless stated.

const Wait := preload("res://tests/helpers/wait.gd")
const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Effects := preload("res://tests/objects/explosives/explosive_fixtures.gd")
const GAS_WEAPON: WeaponData = preload("res://items/grenades/gas/gas_grenade.tres")
const EMP_SCENE := "res://items/grenades/emp/emp_grenade.tscn"
const FRAG_SCENE := "res://items/grenades/frag/frag_grenade.tscn"
const JAMMING_SCENE := "res://items/grenades/jamming/jamming_grenade.tscn"
const CAMERA: PackedScene = preload("res://objects/camera/security_camera.tscn")
const BARREL: PackedScene = preload("res://objects/explosive_barrel/explosive_barrel.tscn")
const ORIGIN := Vector3(1000, 0, 300)
## The shipped grenade's centre when it first touches the floor (0.053 m half height), with margin.
const LANDED_Y: float = 0.12

var _root: Node3D
var _floor: StaticBody3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_floor = Grenades.box(_root, ORIGIN + Vector3(45, -0.5, -20), Vector3(120, 1, 80))


func after_test() -> void:
	Effects.clear_effects(get_tree())
	StimulusSystem.clear()


func test_a_thrown_gas_grenade_leaves_a_cloud_where_it_lands_after_the_fuse() -> void:
	var user := Grenades.thrower(_root, ORIGIN, 0.0, 0.0, GAS_WEAPON)
	await Wait.frames(get_tree(), 3)
	Grenades.holder_of(user).trigger()
	var grenade := Thrower.of(user).last_fuse.entity as RigidBody3D
	var landed := Vector3.INF
	var last := grenade.global_position
	# 2.3 s after the throw: no cloud yet.
	for frame in 138:
		await get_tree().physics_frame
		last = grenade.global_position
		if landed == Vector3.INF and last.y < LANDED_Y:
			landed = last
	assert_object(Effects.first(get_tree(), GasCloud.GROUP)).is_null()
	assert_bool(landed != Vector3.INF).is_true()

	await Grenades.seconds(get_tree(), 0.4)

	var cloud := Effects.first(get_tree(), GasCloud.GROUP)
	assert_object(cloud).is_not_null()
	# Where the grenade was when it went off: it lands about 12 m out, bounces and rolls a few metres.
	var at_rest := Vector2(cloud.global_position.x - last.x, cloud.global_position.z - last.z)
	assert_float(at_rest.length()).is_less(0.3)
	var from_landing := Vector2(cloud.global_position.x - landed.x, cloud.global_position.z - landed.z)
	assert_float(from_landing.length()).is_less(6.0)
	assert_float(ORIGIN.z - cloud.global_position.z).is_between(9.0, 16.0)
	assert_bool(is_instance_valid(grenade)).is_false()


func test_an_emp_mine_set_off_by_a_walker_switches_a_camera_off() -> void:
	var at := Vector3(30, 0, 0)
	var mine := await _armed_mine(EMP_SCENE, at)
	var camera := CAMERA.instantiate() as Node3D
	camera.name = "Camera"
	camera.position = ORIGIN + at + Vector3(0, 2.6, -3)
	_root.add_child(camera)
	await Grenades.seconds(get_tree(), 0.1)
	assert_bool(SecurityCamera.of(camera).is_watching()).is_true()

	_walker("Intruder", at + Vector3(0, 0, 6), Vector3(0, 0, -2))
	await Grenades.seconds(get_tree(), 2.0)

	assert_bool(is_instance_valid(mine)).is_false()
	assert_str(str(Grenades.logged(&"mine.triggered")[0].data["by"])).is_equal("Intruder")
	assert_bool(SecurityCamera.of(camera).is_watching()).is_false()


func test_a_frag_mine_set_off_by_a_walker_chains_to_a_barrel() -> void:
	var at := Vector3(60, 0, 0)
	await _armed_mine(FRAG_SCENE, at)
	var barrel := BARREL.instantiate() as Node3D
	barrel.name = "Barrel"
	barrel.position = ORIGIN + at + Vector3(3, 0.45, 0)
	_root.add_child(barrel)
	await Grenades.seconds(get_tree(), 0.2)

	_walker("Walker", at + Vector3(0, 0, 6), Vector3(0, 0, -2))
	await Grenades.seconds(get_tree(), 2.0)

	assert_array(Grenades.logged(&"mine.triggered")).has_size(1)
	assert_array(Grenades.logged(&"object.exploded", "Barrel")).has_size(1)
	assert_bool(is_instance_valid(barrel)).is_false()


func test_a_shot_sets_off_a_stuck_grenade() -> void:
	var at := Vector3(90, 0, 0)
	var wall := Grenades.box(_root, ORIGIN + at + Vector3(0, 1.5, -0.1), Vector3(3, 3, 0.2))
	var grenade := (load(JAMMING_SCENE) as PackedScene).instantiate() as RigidBody3D
	_root.add_child(grenade, true)
	var sticky := Sticky.of(grenade)
	var point := ORIGIN + at + Vector3(0, 1.5, 0)
	sticky.stick(
		wall.get_node("Shape") as Node3D, ThrowRules.stick_transform(point, Vector3.BACK, Vector3.FORWARD, 0.053)
	)
	var shooter := Node3D.new()
	shooter.name = "Shooter"
	_root.add_child(shooter)
	await Wait.frames(get_tree(), 2)

	# A pistol shot (damage 25, ballistic) from 5 m away at its centre.
	var from := grenade.global_position + Vector3(0, 0, 5)
	StimulusSystem.emit(
		Stimulus.make_ray(&"damage.ballistic", 25.0, from, Vector3.FORWARD, 10.0, shooter, PhysicsLayers.WEAPON_MASK)
	)
	await Wait.frames(get_tree(), 3)

	assert_bool(is_instance_valid(grenade)).is_false()
	assert_object(Effects.first(get_tree(), JammingField.GROUP)).is_not_null()


# A shipped grenade stuck on the floor at `at` (from ORIGIN) and armed.
func _armed_mine(scene: String, at: Vector3) -> RigidBody3D:
	var mine := (load(scene) as PackedScene).instantiate() as RigidBody3D
	_root.add_child(mine, true)
	var pose := ThrowRules.stick_transform(ORIGIN + at, Vector3.UP, Vector3.FORWARD, Sticky.of(mine).surface_offset)
	Sticky.of(mine).stick(_floor.get_node("Shape") as Node3D, pose)
	await Grenades.seconds(get_tree(), 2.1)
	assert_bool(ProximityTrigger.of(mine).is_armed).is_true()
	return mine


func _walker(walker_name: String, at: Vector3, drive: Vector3) -> CharacterBody3D:
	var body := Characters.character(_root, walker_name, ORIGIN + at, [])
	body.set(&"drive", drive)
	return body
