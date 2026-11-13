extends GdUnitTestSuite
## Unit + small integration (ADR 0130): the interaction frame's status rules. Which things the frame
## shows beyond what E acts on, the word and colour per state, the blink, and the readers on minimal
## entities built from components (network_fixtures.body_device, a bare Powered prop, a bare
## BodyParts character), never shipped scenes.
##   Switch (gear, powered) ── Panel (powered, breakable, DeviceSwitch)
##   Lone (device, powered, no cables)   Lamp (Powered only)   Crate (nothing)

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const ORIGIN := Vector3(560, 0, -560)
const W := TargetStatus.Word

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func after_test() -> void:
	StimulusSystem.clear()


func test_qualifies_by_components() -> void:
	assert_bool(TargetStatus.qualifies(true, false, false, false)).is_true()
	assert_bool(TargetStatus.qualifies(false, true, false, false)).is_true()
	assert_bool(TargetStatus.qualifies(false, false, true, false)).is_true()
	assert_bool(TargetStatus.qualifies(false, false, false, true)).is_true()
	assert_bool(TargetStatus.qualifies(false, false, false, false)).is_false()


func test_network_words_in_priority_order() -> void:
	assert_int(TargetStatus.network_word(true, false, false, true)).is_equal(W.ONLINE)
	assert_int(TargetStatus.network_word(true, false, false, false)).is_equal(W.CUT_OFF)
	assert_int(TargetStatus.network_word(true, false, true, true)).is_equal(W.DISABLED)
	assert_int(TargetStatus.network_word(true, true, true, true)).is_equal(W.BROKEN)
	# No power wins over everything (the light is dark).
	assert_int(TargetStatus.network_word(false, true, true, false)).is_equal(W.NO_POWER)


func test_powered_and_character_words() -> void:
	assert_int(TargetStatus.powered_word(true, false)).is_equal(W.POWERED)
	assert_int(TargetStatus.powered_word(false, false)).is_equal(W.NO_POWER)
	assert_int(TargetStatus.powered_word(false, true)).is_equal(W.BROKEN)
	assert_int(TargetStatus.character_word(false, false)).is_equal(W.NONE)
	assert_int(TargetStatus.character_word(false, true)).is_equal(W.UNCONSCIOUS)
	assert_int(TargetStatus.character_word(true, true)).is_equal(W.DEAD)


func test_texts_colours_and_blink() -> void:
	assert_str(TargetStatus.text(W.ONLINE)).is_equal("Online")
	assert_str(TargetStatus.text(W.CUT_OFF)).is_equal("Cut off")
	assert_str(TargetStatus.text(W.NO_POWER)).is_equal("No power")
	assert_str(TargetStatus.text(W.NONE)).is_equal("")
	# The network states use the status light's colours.
	assert_that(TargetStatus.color(W.ONLINE)).is_equal(StatusLight.COLORS[StatusLight.State.UP])
	assert_that(TargetStatus.color(W.CUT_OFF)).is_equal(StatusLight.COLORS[StatusLight.State.CUT_OFF])
	assert_that(TargetStatus.color(W.DISABLED)).is_equal(StatusLight.COLORS[StatusLight.State.DISABLED])
	assert_that(TargetStatus.color(W.BROKEN)).is_equal(StatusLight.COLORS[StatusLight.State.DISABLED])
	assert_that(TargetStatus.color(W.NO_POWER)).is_equal(TargetStatus.NO_POWER_COLOR)
	assert_that(TargetStatus.color(W.UNCONSCIOUS)).is_equal(TargetStatus.UNCONSCIOUS_COLOR)
	assert_that(TargetStatus.color(W.DEAD)).is_equal(TargetStatus.DEAD_COLOR)
	assert_bool(TargetStatus.blinks(W.CUT_OFF)).is_true()
	assert_bool(TargetStatus.blinks(W.ONLINE)).is_false()
	# 0.8 s period like the LED: dim in the first half, lit in the second.
	assert_float(TargetStatus.blink_alpha(0.1)).is_equal(TargetStatus.BLINK_DIM)
	assert_float(TargetStatus.blink_alpha(0.6)).is_equal(1.0)
	assert_float(TargetStatus.blink_alpha(0.9)).is_equal(TargetStatus.BLINK_DIM)


func test_network_device_words_from_its_components() -> void:
	var switch := _device("Switch", Vector3(0, 1, 0))
	ActorState.set_tag(switch, DeviceNetwork.NETWORK_GEAR, true)
	var panel := _device("Panel", Vector3(2, 1, 0))
	var toggle := DeviceSwitch.new()
	toggle.name = "DeviceSwitch"
	panel.add_child(toggle)
	Net.link(panel, switch)
	await get_tree().process_frame
	var links := NetworkState.links_of(Device.of(panel))
	assert_array(links).contains_exactly([Device.of(switch)])

	assert_int(TargetStatus.word_of(panel, links)).is_equal(W.ONLINE)
	(switch.get_node("Powered") as Powered).on = false
	assert_int(TargetStatus.word_of(panel, links)).is_equal(W.CUT_OFF)
	(switch.get_node("Powered") as Powered).on = true
	toggle.set_disabled(true)
	assert_int(TargetStatus.word_of(panel, links)).is_equal(W.DISABLED)
	(panel.get_node("Powered") as Powered).on = false
	assert_int(TargetStatus.word_of(panel, links)).is_equal(W.NO_POWER)
	(panel.get_node("Powered") as Powered).on = true
	Breakable.of(panel).take_damage(&"ballistic", 100.0)
	assert_int(TargetStatus.word_of(panel, links)).is_equal(W.BROKEN)


func test_things_off_any_network_and_characters() -> void:
	var lone := _device("Lone", Vector3(4, 1, 0))
	var lamp := StaticBody3D.new()
	var power := Powered.new()
	power.name = "Powered"
	lamp.add_child(power)
	_root.add_child(lamp)
	var crate := StaticBody3D.new()
	_root.add_child(crate)
	var guard := Characters.character(_root, "Walker", ORIGIN + Vector3(6, 0, 0), [] as Array[StringName])
	await get_tree().process_frame
	var none: Array[Device] = []

	assert_bool(TargetStatus.shows(lone)).is_true()
	assert_bool(TargetStatus.shows(lamp)).is_true()
	assert_bool(TargetStatus.shows(guard)).is_true()
	assert_bool(TargetStatus.shows(crate)).is_false()
	assert_array(NetworkState.links_of(Device.of(lone))).is_empty()
	assert_int(TargetStatus.word_of(lone, none)).is_equal(W.POWERED)
	assert_int(TargetStatus.word_of(lamp, none)).is_equal(W.POWERED)
	power.on = false
	assert_int(TargetStatus.word_of(lamp, none)).is_equal(W.NO_POWER)
	assert_int(TargetStatus.word_of(crate, none)).is_equal(W.NONE)
	assert_int(TargetStatus.word_of(guard, none)).is_equal(W.NONE)
	ActorState.set_tag(guard, ActorState.UNCONSCIOUS, true)
	assert_int(TargetStatus.word_of(guard, none)).is_equal(W.UNCONSCIOUS)
	ActorState.set_tag(guard, ActorState.DEAD, true)
	assert_int(TargetStatus.word_of(guard, none)).is_equal(W.DEAD)


func test_lock_line_reads_the_locks_on_the_entity() -> void:
	var box := StaticBody3D.new()
	var lockable := Lockable.new()
	lockable.name = "Lockable"
	box.add_child(lockable)
	var lock := MechanicalLock.new()
	lock.name = "MechanicalLock"
	lock.data = MechanicalLockData.new()
	box.add_child(lock)
	var reader := KeycardLock.new()
	reader.name = "KeycardLock"
	reader.data = KeycardLockData.new()
	box.add_child(reader)
	_root.add_child(box)

	assert_str(TargetStatus.lock_line(box, null)).is_equal("")
	lockable.lock(null, &"test")
	assert_str(TargetStatus.lock_line(box, null)).is_equal("Locked · lockpick or keycard")
	lock.data.key_id = &"bay_a"
	assert_str(TargetStatus.lock_line(box, null)).is_equal("Locked · key or lockpick or keycard")


func _device(entity_name: String, at: Vector3) -> StaticBody3D:
	return Net.body_device(_root, entity_name, ORIGIN + at, [], true, 10.0)
