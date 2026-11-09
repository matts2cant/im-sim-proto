extends GdUnitTestSuite
## Integration (ADR 0078): every lock component on a minimal entity (Node3D + Tags + Attributes +
## StimulusReceiver + Lockable, no Door): each opens only by its own method (a keycard grants an
## opening without unlocking, ADR 0098), and remote lock / unlock
## commands reach a bare Lockable on a Device, blocked by `state.unpowered` / `state.broken`.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const COMMAND_LOCK: Receptron = preload("res://objects/devices/receptrons/command_lock.tres")
const COMMAND_UNLOCK: Receptron = preload("res://objects/devices/receptrons/command_unlock.tres")
const FRAME := 1.0 / 60.0

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)


func test_keypad_opens_only_with_its_code() -> void:
	var box := _locked_box([])
	var keypad := _keypad(box, &"locker", "0451")
	var user := _user([])
	var wanted: Array[Node] = []
	Lockable.of(box).unlocked_by_user.connect(func(by: Node) -> void: wanted.append(by))

	assert_bool(keypad.submit("1234", user)).is_false()
	await Fixtures.frames(get_tree(), 2)

	assert_bool(Lockable.of(box).locked).is_true()
	var beeps := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise"
	)
	assert_array(beeps).has_size(1)
	assert_float(float(beeps[0].data["intensity"])).is_equal_approx(4.0, 0.001)

	assert_bool(keypad.submit("0451", user)).is_true()
	assert_bool(Lockable.of(box).locked).is_false()
	assert_array(wanted).contains_exactly([user])
	assert_array(EventLog.find(&"lock.code_entered")).has_size(2)


func test_keypad_reminder_comes_from_the_users_log() -> void:
	var box := _locked_box([])
	var keypad := _keypad(box, &"locker", "0451")
	var user := _user([])
	var reader_log := PersonalLog.new()
	reader_log.name = "PersonalLog"
	user.add_child(reader_log)
	assert_str(keypad.reminder(user)).is_equal("")

	reader_log.read(LogEntry.make(&"roster", "Shift roster", "Locker 0451", "Desk", {&"locker": "0451"}))

	assert_str(keypad.reminder(user)).is_equal("Note: 0451, from 'Shift roster'")
	# Knowing the code does not unlock anything: the user still types it.
	assert_bool(Lockable.of(box).locked).is_true()
	# A user without a keypad screen cannot type (no prompt, E does nothing).
	assert_str(keypad.use_prompt(user)).is_equal("")
	assert_bool(keypad.use_locked(user)).is_false()


func test_mechanical_lock_picks_in_pins_times_skill_and_resets_on_release() -> void:
	var box := _locked_box([])
	var lock := _mechanical(box, 3)
	var user := _user([])
	var attributes := Attributes.of(user)
	attributes.attribute_set.add_modifier(
		Modifier.create(&"lockpick_time_mult", Modifier.Op.MULTIPLY, 0.75, &"skill.lockpicking")
	)
	assert_float(lock.pick_time(user)).is_equal_approx(2.25, 0.0001)
	assert_bool(lock.accepts_tool(&"lockpick")).is_true()
	assert_bool(lock.accepts_tool(&"crowbar")).is_false()

	# 1.5 s, then letting go: the progress is lost.
	_hold(lock, user, 1.5)
	lock.tool_release(user)
	assert_float(lock.tool_progress()).is_equal(-1.0)
	# 2.0 s is not enough...
	_hold(lock, user, 2.0)
	assert_bool(Lockable.of(box).locked).is_true()
	assert_float(lock.tool_progress()).is_between(0.85, 0.92)
	# ... 2.4 s in all is.
	_hold(lock, user, 0.4)

	assert_bool(Lockable.of(box).locked).is_false()
	assert_bool(lock.accepts_tool(&"lockpick")).is_false()
	assert_array(EventLog.find(&"lock.pick_cancelled")).has_size(1)
	assert_array(EventLog.find(&"lock.picked")).has_size(1)


func test_mechanical_lock_pins_are_data() -> void:
	var box := _locked_box([])
	var lock := _mechanical(box, 5)
	lock.data.pins[1] = &"spool"

	assert_int(lock.pin_count()).is_equal(5)
	assert_str(String(lock.data.pins[1])).is_equal("spool")
	assert_float(lock.pick_time(_user([]))).is_equal_approx(5.0, 0.0001)


func test_keycard_reader_opens_for_its_access_only() -> void:
	var box := _locked_box([])
	var reader := KeycardLock.new()
	reader.data = KeycardLockData.new()
	reader.data.access_id = &"vault"
	box.add_child(reader)
	var stranger := _user([&"access.office"])
	var holder := _user([&"access.vault"])

	assert_bool(reader.use_locked(stranger)).is_false()
	assert_bool(reader.grants_passage(stranger)).is_false()
	assert_str(reader.use_prompt(stranger)).is_equal("")
	assert_bool(Lockable.of(box).locked).is_true()
	assert_bool(reader.grants_passage(holder)).is_true()
	assert_bool(Lockable.of(box).grants_passage(holder)).is_true()
	assert_int(Lockable.of(box).passage_layers()).is_equal(AccessLayers.access_layer(&"vault"))

	# A swipe grants one opening and leaves it locked (ADR 0098): the card is needed every time.
	var granted: Array[Node] = []
	Lockable.of(box).access_granted.connect(func(user: Node) -> void: granted.append(user))
	assert_bool(reader.use_locked(holder)).is_true()
	assert_bool(Lockable.of(box).locked).is_true()
	assert_array(granted).contains_exactly([holder])
	assert_array(EventLog.find(&"lock.unlocked")).is_empty()
	assert_str(String(EventLog.find(&"lock.granted")[0].data["how"])).is_equal("keycard")


func test_fail_safe_lock_unlocks_on_power_loss_and_fail_secure_stays() -> void:
	var safe := _locked_box([&"door.fail_safe"], true)
	var secure := _locked_box([&"door.fail_secure"], true)
	for box: Node3D in [safe, secure]:
		box.add_child(ElectronicLock.new())

	Powered.of(safe).on = false
	Powered.of(secure).on = false

	assert_bool(Lockable.of(safe).locked).is_false()
	assert_bool(Lockable.of(secure).locked).is_true()
	assert_array(EventLog.find(&"lock.unlocked")).has_size(1)
	assert_str(String(EventLog.find(&"lock.unlocked")[0].data["how"])).is_equal("power")


func test_fail_safe_lock_unlocks_when_tagged_unpowered() -> void:
	var safe := _locked_box([&"door.fail_safe"])
	safe.add_child(ElectronicLock.new())

	ActorState.set_tag(safe, &"state.unpowered", true)

	assert_bool(Lockable.of(safe).locked).is_false()


func test_lock_and_unlock_commands_reach_a_bare_lockable() -> void:
	var box := _locked_box([], false, [COMMAND_LOCK, COMMAND_UNLOCK])

	StimulusSystem.emit(Stimulus.make_contact(&"command.unlock", 1.0, box, _root))
	await Fixtures.frames(get_tree(), 2)
	assert_bool(Lockable.of(box).locked).is_false()

	ActorState.set_tag(box, &"state.unpowered", true)
	StimulusSystem.emit(Stimulus.make_contact(&"command.lock", 1.0, box, _root))
	await Fixtures.frames(get_tree(), 2)
	assert_bool(Lockable.of(box).locked).is_false()

	ActorState.set_tag(box, &"state.unpowered", false)
	StimulusSystem.emit(Stimulus.make_contact(&"command.lock", 1.0, box, _root))
	await Fixtures.frames(get_tree(), 2)
	assert_bool(Lockable.of(box).locked).is_true()


func test_lockable_saves_locked() -> void:
	var box := _locked_box([])
	var lockable := Lockable.of(box)
	var saved := lockable.save_state()
	lockable.unlock()

	lockable.load_state(saved)

	assert_bool(lockable.locked).is_true()
	assert_bool(lockable.is_in_group(&"saveable")).is_true()


# A locked minimal entity (Tags, Attributes, StimulusReceiver, Lockable; optionally Powered).
func _locked_box(tags: Array[StringName], powered: bool = false, receptrons: Array[Receptron] = []) -> Node3D:
	var box := Node3D.new()
	var lockable := Lockable.new()
	lockable.name = "Lockable"
	lockable.locked = true
	box.add_child(lockable)
	if powered:
		var power := Powered.new()
		power.name = "Powered"
		box.add_child(power)
	if not receptrons.is_empty():
		var device := Device.new()
		device.name = "Device"
		box.add_child(device)
	return Fixtures.compose(box, _root, "Box", Vector3.ZERO, receptrons, tags)


func _keypad(box: Node3D, code_id: StringName, code: String) -> KeypadLock:
	var keypad := KeypadLock.new()
	keypad.data = KeypadLockData.new()
	keypad.data.code_id = code_id
	keypad.data.code = code
	box.add_child(keypad)
	return keypad


func _mechanical(box: Node3D, pins: int) -> MechanicalLock:
	var lock := MechanicalLock.new()
	lock.data = MechanicalLockData.new()
	lock.data.pins.clear()
	for i in pins:
		lock.data.pins.append(&"standard")
	box.add_child(lock)
	return lock


func _user(tags: Array[StringName]) -> Node3D:
	return Fixtures.entity(_root, "User", Vector3(0, 0, 2), [], tags)


func _hold(lock: MechanicalLock, user: Node, seconds: float) -> void:
	for i in roundi(seconds / FRAME):
		lock.tool_hold(user, FRAME)
