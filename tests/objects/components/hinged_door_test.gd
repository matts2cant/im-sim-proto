extends GdUnitTestSuite
## HingedDoor (ADR 0130) on a minimal leaf built in code (a StaticBody3D whose origin is the hinge):
## E opens it while unlocked and closes it while open, the leaf turns `open_angle` degrees about +Y
## in `open_time` s, a Lockable keeps it shut until a user unlocks it on purpose (which opens it),
## and its state saves and loads. Nothing names the leaf.

const ORIGIN := Vector3(-280, 0, -260)
const ANGLE: float = -90.0
const OPEN_TIME: float = 0.25

var _root: Node3D
var _leaf: StaticBody3D
var _door: HingedDoor
var _user: Node3D


func before_test() -> void:
	EventLog.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_user = Node3D.new()
	_user.name = "User"
	_root.add_child(_user)


# The leaf at ORIGIN with a HingedDoor (and a Lockable, locked or not, when `lock` is set).
func _build(lock: bool = false, locked: bool = false) -> void:
	_leaf = StaticBody3D.new()
	_leaf.name = "Leaf"
	_leaf.position = ORIGIN
	if lock:
		var lockable := Lockable.new()
		lockable.locked = locked
		_leaf.add_child(lockable)
	_door = HingedDoor.new()
	_door.open_angle = ANGLE
	_door.open_time = OPEN_TIME
	_leaf.add_child(_door)
	_root.add_child(_leaf)


# Waits until the leaf has finished its swing (frame cap: twice the open time).
func _settle() -> void:
	var cap := ceili(OPEN_TIME * 2.0 * Engine.physics_ticks_per_second)
	for i in cap:
		if _door.is_settled():
			return
		await get_tree().physics_frame


func _yaw() -> float:
	return rad_to_deg(_leaf.transform.basis.get_euler().y)


func test_use_swings_the_leaf_open_and_shut() -> void:
	_build()
	assert_str(_door.prompt(_user)).is_equal("E: open")
	assert_bool(_door.use(_user)).is_true()
	assert_bool(_door.open).is_true()
	await _settle()
	assert_bool(_door.is_settled()).is_true()
	assert_float(_yaw()).is_equal_approx(ANGLE, 0.5)
	# The hinge stays where it is.
	assert_vector(_leaf.position).is_equal_approx(ORIGIN, Vector3.ONE * 0.001)
	assert_str(_door.prompt(_user)).is_equal("E: close")

	assert_bool(_door.use(_user)).is_true()
	await _settle()
	assert_float(_yaw()).is_equal_approx(0.0, 0.5)
	assert_int(EventLog.find(EventKinds.HINGED_DOOR_OPENED).size()).is_equal(1)
	assert_int(EventLog.find(EventKinds.HINGED_DOOR_CLOSED).size()).is_equal(1)


func test_a_locked_leaf_stays_shut_until_unlocked_on_purpose() -> void:
	_build(true, true)
	assert_bool(_door.is_locked()).is_true()
	assert_bool(_door.use(_user)).is_false()
	assert_bool(_door.open).is_false()
	assert_str(_door.prompt(_user)).starts_with("Locked")

	# Unlocked by a user who wants through (a pick, a key): it opens.
	Lockable.of(_leaf).unlock(_user, &"pick", true)
	assert_bool(_door.open).is_true()
	# Closing never locks it again.
	_door.use(_user)
	assert_bool(_door.is_locked()).is_false()


func test_unlocking_without_wanting_through_leaves_it_shut() -> void:
	_build(true, true)
	Lockable.of(_leaf).unlock(_user, &"command")
	assert_bool(_door.open).is_false()
	assert_str(_door.prompt(_user)).is_equal("E: open")


func test_saves_and_loads_open_at_once() -> void:
	_build()
	assert_dict(_door.save_state()).is_equal({"open": false})
	_door.load_state({"open": true})
	assert_bool(_door.open).is_true()
	assert_float(_yaw()).is_equal_approx(ANGLE, 0.5)
	assert_dict(_door.save_state()).is_equal({"open": true})
