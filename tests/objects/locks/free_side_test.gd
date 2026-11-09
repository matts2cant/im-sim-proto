extends GdUnitTestSuite
## Integration (ADR 0090): a lock's free side. Any Lock can name a side of its entity (FRONT: +Z,
## BACK: -Z) from which the locked door opens without the key, like an exit handle: E there says
## "E: open" and opens it without unlocking it (it is locked again once closed), and a character
## on that side may pass (Lockable.grants_passage). From the other side the lock works as before.
## Door fixture: tests/objects/fixtures/door_wall.tscn (wall along z = 0, door at x = 0).

const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
## Users 1.5 m either side of the doorway (centre to centre), relative to the fixture.
const FRONT := Vector3(0, 0, 1.5)
const BACK := Vector3(0, 0, -1.5)

var _scene: Node3D
var _entity: StaticBody3D
var _door: Door


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_scene = auto_free(load(Helpers.WALL).instantiate())
	_scene.position = Helpers.ORIGIN
	add_child(_scene)
	await Helpers.frames(get_tree(), 3)
	_entity = Helpers.door_entity(_scene)
	_door = Door.of(_entity)
	EventLog.clear()


func test_a_mechanical_lock_opens_freely_from_its_free_side_only() -> void:
	var lock := Helpers.add_mechanical(_entity, 3)
	lock.free_side = Lock.BACK
	Helpers.lock(_entity)
	var outside := _user("Outside", FRONT)
	var inside := _user("Inside", BACK)

	assert_str(_door.prompt(outside)).is_equal("Locked: lockpick")
	assert_bool(_door.use(outside)).is_false()
	assert_bool(_door.is_open()).is_false()
	assert_bool(Lockable.of(_entity).grants_passage(outside)).is_false()

	assert_str(_door.prompt(inside)).is_equal("E: open")
	assert_bool(Lockable.of(_entity).grants_passage(inside)).is_true()
	assert_bool(_door.use(inside)).is_true()

	# An authorised open: open, still locked, so it is locked again once closed.
	assert_bool(_door.is_open()).is_true()
	assert_bool(_door.is_locked()).is_true()
	assert_array(EventLog.find(&"door.opened_freely")).has_size(1)
	await Helpers.frames(get_tree(), 45)
	assert_bool(_door.close(outside)).is_true()
	await Helpers.frames(get_tree(), 45)
	assert_str(_door.prompt(outside)).is_equal("Locked: lockpick")


func test_any_lock_can_have_a_free_side() -> void:
	var reader := Helpers.add_keycard(_entity, &"vault")
	reader.free_side = Lock.FRONT
	Helpers.lock(_entity)
	var front := _user("Front", FRONT)
	var back := _user("Back", BACK)

	assert_bool(_door.opens_freely_for(front)).is_true()
	assert_bool(_door.opens_freely_for(back)).is_false()
	assert_str(_door.prompt(back)).is_equal("Locked: keycard")
	# A character on the free side gets through as its path reaches the door (DoorOpener).
	assert_bool(_door.open_for(front)).is_true()


func test_no_free_side_by_default() -> void:
	var lock := Helpers.add_mechanical(_entity, 3)
	Helpers.lock(_entity)

	assert_int(lock.free_side).is_equal(Lock.NO_SIDE)
	assert_bool(_door.opens_freely_for(_user("Front", FRONT))).is_false()
	assert_bool(_door.opens_freely_for(_user("Back", BACK))).is_false()


func test_free_side_rule() -> void:
	assert_bool(LockRules.on_free_side(Lock.FRONT, 0.5)).is_true()
	assert_bool(LockRules.on_free_side(Lock.FRONT, -0.5)).is_false()
	assert_bool(LockRules.on_free_side(Lock.BACK, -0.5)).is_true()
	assert_bool(LockRules.on_free_side(Lock.BACK, 0.5)).is_false()
	assert_bool(LockRules.on_free_side(Lock.NO_SIDE, 0.5)).is_false()
	assert_bool(LockRules.on_free_side(Lock.FRONT, 0.0)).is_false()


func _user(user_name: String, offset: Vector3) -> Node3D:
	return Fixtures.entity(_scene, user_name, offset, [], [])
