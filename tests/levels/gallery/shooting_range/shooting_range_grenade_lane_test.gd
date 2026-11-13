extends GdUnitTestSuite
## Grenade lane scenarios (M14c, ADR 0131) in the range room alone. A character standing on the
## throwing line (its centre on the line) and looking level at the target throws the shipped frag
## grenade Untrained (12 m): it first touches down on the target, then rolls on and goes off a few
## metres past it. A frag stuck on the target and shot from the line goes off there: the dummies 2, 4
## and 6 m from the target take what the frag does at those distances (dead, badly hurt, light).

const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/shooting_range/shooting_range_room.tscn")
const FRAG: WeaponData = preload("res://items/grenades/frag/frag_grenade.tres")
const FRAG_SCENE: PackedScene = preload("res://items/grenades/frag/frag_grenade.tscn")
const ORIGIN := Vector3(-560, 0, 300)
## Height of the frag's centre (a 0.1 m model) when it first touches the floor, with margin.
const LANDED_Y := 0.12
const EYE := 1.65

var _room: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_room = auto_free(ROOM_SCENE.instantiate()) as Node3D
	_room.position = ORIGIN
	add_child(_room)
	await Grenades.frames(get_tree(), 5)


func after_test() -> void:
	StimulusSystem.clear()


func test_a_frag_thrown_from_the_line_lands_on_the_target() -> void:
	var line := _local("GrenadeLane/ThrowLine")
	var target := _local("GrenadeLane/Target")
	var user := Grenades.thrower(_room, Vector3(line.x, 0, line.z), 0.0, 0.0, FRAG)
	await Grenades.frames(get_tree(), 3)

	Grenades.holder_of(user).trigger()
	var grenade := Thrower.of(user).last_fuse.entity as RigidBody3D
	var landed := Vector3.INF
	var last := grenade.position
	for frame in 200:
		await get_tree().physics_frame
		if not is_instance_valid(grenade):
			break
		last = grenade.position
		if landed == Vector3.INF and last.y < LANDED_Y:
			landed = last

	var touch := Vector2(landed.x - target.x, landed.z - target.z)
	var blast := Vector2(last.x - target.x, last.z - target.z)
	# Measured 0.21 m short of the target's centre, inside the 1.2 m square.
	assert_float(touch.length()).is_less(0.6)
	# It rolls on along the throw (measured 3.75 m past) and goes off on the lane, short of the far wall.
	assert_bool(is_instance_valid(grenade)).is_false()
	assert_float(-blast.y).is_between(0.5, 6.0)
	assert_float(absf(blast.x)).is_less(1.5)


func test_a_frag_stuck_on_the_target_and_shot_hurts_the_dummies_by_distance() -> void:
	var target := _local("GrenadeLane/Target")
	var line := _local("GrenadeLane/ThrowLine")
	var frag := FRAG_SCENE.instantiate() as RigidBody3D
	_room.add_child(frag)
	var floor_node := _room.get_node("GrenadeLane/Target") as Node3D
	var pose := Transform3D(Basis.IDENTITY, _room.to_global(target + Vector3(0, Sticky.of(frag).surface_offset, 0)))
	Sticky.of(frag).stick(floor_node, pose)
	await Grenades.frames(get_tree(), 2)

	# A pistol round from the line's eye height at the stuck frag.
	var eye := _room.to_global(Vector3(line.x, EYE, line.z))
	var at := frag.global_position
	StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 25.0, eye, (at - eye).normalized(), 30.0))
	await Grenades.frames(get_tree(), 6)

	assert_bool(is_instance_valid(frag)).is_false()
	var torso: Dictionary[int, float] = {}
	for metres: int in [2, 4, 6]:
		var dummy := _room.get_node("GrenadeLane/Dummy%dm" % metres) as TrainingDummy
		torso[metres] = dummy.body.health(&"torso")
	# Measured (dummy torso 80): 2 m dead; 4 m alive, torso 0.7 left; 6 m torso 66.6 left (a light
	# wound: the frag's "badly hurts" stops at about 5 m, M14b).
	assert_bool((_room.get_node("GrenadeLane/Dummy2m") as TrainingDummy).body.is_dead()).is_true()
	for metres: int in [4, 6]:
		assert_bool((_room.get_node("GrenadeLane/Dummy%dm" % metres) as TrainingDummy).body.is_dead()).is_false()
	assert_float(torso[4]).is_less(40.0)
	assert_float(torso[6]).is_greater(60.0)


func _local(path: String) -> Vector3:
	return (_room.get_node(path) as Node3D).position
