extends GdUnitTestSuite
## Integration (ADR 0098): a keycard is needed every time. A swipe on the card reader box opens the
## locked door without unlocking it; it does not close by itself, and once closed (by anyone) it is
## locked again, its navigation link back on the locked layers. A keypad's code unlocks for good.
## Save and load keep both right, and a free side still opens the keycard door without a card.
## Door fixture: tests/objects/fixtures/door_wall.tscn (wall along z = 0, door at x = 0); users are
## stand-in entities (Tags only; an `access.vault` tag is the card).

const Wait := preload("res://tests/helpers/wait.gd")
const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
## Users 1.5 m in front of and behind the doorway (centre to centre), relative to the fixture.
const FRONT := Vector3(0, 0, 1.5)
const BACK := Vector3(0, 0, -1.5)
## 0.6 s to open or close, and margin (physics frames).
const SLIDE_FRAMES := 45

var _scene: Node3D
var _entity: StaticBody3D
var _door: Door
var _link: NavigationLink3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_scene = auto_free(load(Helpers.WALL).instantiate())
	_scene.position = Helpers.ORIGIN
	add_child(_scene)
	await Wait.frames(get_tree(), 3)
	_entity = Helpers.door_entity(_scene)
	_door = Door.of(_entity)
	_link = _entity.get_node("NavigationLink3D") as NavigationLink3D
	EventLog.clear()


func test_a_card_opens_it_and_it_locks_again_once_closed() -> void:
	Helpers.add_keycard(_entity, &"vault")
	Helpers.lock(_entity)
	await Wait.frames(get_tree(), 2)
	var holder := _user("Holder", FRONT, [&"access.vault"])
	var reader := Helpers.control(_door, true)

	assert_bool(reader.use(holder)).is_true()
	assert_bool(_door.is_open()).is_true()
	assert_bool(_door.is_locked()).is_true()
	# It does not close by itself.
	await Wait.frames(get_tree(), SLIDE_FRAMES * 4)
	assert_bool(_door.is_open()).is_true()
	assert_int(_link.navigation_layers).is_equal(AccessLayers.WALK)

	# Someone closes it: locked again, a stranger cannot open it, the card holder needs the card again.
	assert_bool(_door.close()).is_true()
	await Wait.frames(get_tree(), SLIDE_FRAMES)
	assert_bool(_door.is_locked()).is_true()
	assert_int(_link.navigation_layers).is_equal(AccessLayers.LOCKED | AccessLayers.access_layer(&"vault"))
	var stranger := _user("Stranger", FRONT, [])
	assert_str(reader.prompt(stranger)).is_equal("Locked: keycard")
	assert_bool(reader.use(stranger)).is_false()
	assert_bool(_door.is_open()).is_false()
	assert_str(reader.prompt(holder)).is_equal("E: open (keycard)")
	assert_array(EventLog.find(&"lock.unlocked")).is_empty()
	assert_array(EventLog.find(&"lock.granted")).has_size(1)


func test_a_keypad_code_unlocks_it_for_good() -> void:
	var keypad := Helpers.add_keypad(_entity, &"store", "1234")
	Helpers.lock(_entity)
	var user := _user("User", FRONT, [])
	assert_bool(keypad.submit("1234", user)).is_true()
	await Wait.frames(get_tree(), SLIDE_FRAMES)
	assert_bool(_door.is_open()).is_true()

	assert_bool(_door.close()).is_true()
	await Wait.frames(get_tree(), SLIDE_FRAMES)
	assert_bool(_door.is_locked()).is_false()
	assert_str(_door.prompt(user)).is_equal("E: open")


func test_save_and_load_keep_a_card_opening_and_a_code_unlock() -> void:
	# A keycard door opened with the card: open and locked.
	Helpers.add_keycard(_entity, &"vault")
	Helpers.lock(_entity)
	await Wait.frames(get_tree(), 2)
	Helpers.control(_door, true).use(_user("Holder", FRONT, [&"access.vault"]))
	await Wait.frames(get_tree(), SLIDE_FRAMES)
	var door_state := _door.save_state()
	var lock_state := Lockable.of(_entity).save_state()
	_door.close()
	await Wait.frames(get_tree(), SLIDE_FRAMES)

	_door.load_state(door_state)
	Lockable.of(_entity).load_state(lock_state)
	assert_bool(_door.is_open()).is_true()
	assert_bool(_door.is_locked()).is_true()
	# Closed after loading: locked again.
	_door.close()
	await Wait.frames(get_tree(), SLIDE_FRAMES)
	assert_bool(_door.is_locked()).is_true()

	# Unlocked for good (a code, a command): it stays unlocked after loading.
	Lockable.of(_entity).unlock(null, &"keypad")
	lock_state = Lockable.of(_entity).save_state()
	Helpers.lock(_entity)
	Lockable.of(_entity).load_state(lock_state)
	assert_bool(_door.is_locked()).is_false()
	assert_int(_link.navigation_layers).is_equal(AccessLayers.WALK)


func test_the_free_side_opens_a_keycard_door_on_its_reader_without_a_card() -> void:
	var reader_lock := Helpers.add_keycard(_entity, &"vault")
	reader_lock.free_side = Lock.BACK
	Helpers.lock(_entity)
	await Wait.frames(get_tree(), 2)
	var inside := _user("Inside", BACK, [])
	var outside := _user("Outside", FRONT, [])

	assert_str(Helpers.control(_door, true).prompt(outside)).is_equal("Locked: keycard")
	assert_str(Helpers.control(_door, false).prompt(inside)).is_equal("E: open")
	assert_str(_door.prompt(inside)).is_equal("E: open")
	assert_bool(Helpers.control(_door, false).use(inside)).is_true()
	assert_array(EventLog.find(&"door.opened_freely")).has_size(1)
	await Wait.frames(get_tree(), SLIDE_FRAMES)
	_door.close()
	await Wait.frames(get_tree(), SLIDE_FRAMES)
	assert_bool(_door.is_locked()).is_true()


func _user(user_name: String, offset: Vector3, tags: Array[StringName]) -> Node3D:
	return Fixtures.entity(_scene, user_name, offset, [], tags)
