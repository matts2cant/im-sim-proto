extends GdUnitTestSuite
## Unit + small integration (ADR 0130): the interaction frame's status rules. Which things the frame
## shows beyond what E acts on, the word (a StatusWord, ADR 0137) and colour per state, the blink,
## and the readers on minimal
## entities built from components (network_fixtures.body_device, a bare Powered prop, a bare
## BodyParts character), never shipped scenes.
##   Switch (gear, powered) ── Panel (powered, breakable, DeviceSwitch)
##   Lone (device, powered, no cables)   Lamp (Powered only)   Crate (nothing)

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const ORIGIN := Vector3(560, 0, -560)

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
	assert_object(TargetStatus.network_word(true, false, false, true)).is_same(TargetStatus.ONLINE)
	assert_object(TargetStatus.network_word(true, false, false, false)).is_same(TargetStatus.CUT_OFF)
	assert_object(TargetStatus.network_word(true, false, true, true)).is_same(TargetStatus.DISABLED)
	assert_object(TargetStatus.network_word(true, true, true, true)).is_same(TargetStatus.BROKEN)
	# No power wins over everything (the light is dark).
	assert_object(TargetStatus.network_word(false, true, true, false)).is_same(TargetStatus.NO_POWER)


func test_powered_and_character_words() -> void:
	assert_object(TargetStatus.powered_word(true, false)).is_same(TargetStatus.POWERED)
	assert_object(TargetStatus.powered_word(false, false)).is_same(TargetStatus.NO_POWER)
	assert_object(TargetStatus.powered_word(false, true)).is_same(TargetStatus.BROKEN)
	assert_object(TargetStatus.character_word(false, false)).is_null()
	assert_object(TargetStatus.character_word(false, true)).is_same(TargetStatus.UNCONSCIOUS)
	assert_object(TargetStatus.character_word(true, true)).is_same(TargetStatus.DEAD)


func test_texts_colours_and_blink() -> void:
	assert_str(TargetStatus.ONLINE.text).is_equal("Online")
	assert_str(TargetStatus.CUT_OFF.text).is_equal("Cut off")
	assert_str(TargetStatus.NO_POWER.text).is_equal("No power")
	# The network states use the status light's colours.
	assert_that(TargetStatus.ONLINE.color).is_equal(StatusLight.COLORS[StatusLight.State.UP])
	assert_that(TargetStatus.POWERED.color).is_equal(StatusLight.COLORS[StatusLight.State.UP])
	assert_that(TargetStatus.CUT_OFF.color).is_equal(StatusLight.COLORS[StatusLight.State.CUT_OFF])
	assert_that(TargetStatus.JAMMED.color).is_equal(StatusLight.COLORS[StatusLight.State.JAMMED])
	assert_that(TargetStatus.DISABLED.color).is_equal(StatusLight.COLORS[StatusLight.State.DISABLED])
	assert_that(TargetStatus.BROKEN.color).is_equal(StatusLight.COLORS[StatusLight.State.DISABLED])
	# The approved mockup's colours: grey, blue-white, dim red.
	assert_that(TargetStatus.NO_POWER.color).is_equal(Color("8a9296"))
	assert_that(TargetStatus.UNCONSCIOUS.color).is_equal(Color("9fd8ff"))
	assert_that(TargetStatus.DEAD.color).is_equal(Color("b0423b"))
	# They blink where the light blinks.
	assert_bool(TargetStatus.CUT_OFF.blink).is_equal(StatusLight.blinks(StatusLight.State.CUT_OFF))
	assert_bool(TargetStatus.JAMMED.blink).is_equal(StatusLight.blinks(StatusLight.State.JAMMED))
	assert_bool(TargetStatus.ONLINE.blink).is_false()
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

	assert_object(TargetStatus.word_of(panel, links)).is_same(TargetStatus.ONLINE)
	(switch.get_node("Powered") as Powered).on = false
	assert_object(TargetStatus.word_of(panel, links)).is_same(TargetStatus.CUT_OFF)
	(switch.get_node("Powered") as Powered).on = true
	toggle.set_disabled(true)
	assert_object(TargetStatus.word_of(panel, links)).is_same(TargetStatus.DISABLED)
	(panel.get_node("Powered") as Powered).on = false
	assert_object(TargetStatus.word_of(panel, links)).is_same(TargetStatus.NO_POWER)
	(panel.get_node("Powered") as Powered).on = true
	Breakable.of(panel).take_damage(&"ballistic", 100.0)
	assert_object(TargetStatus.word_of(panel, links)).is_same(TargetStatus.BROKEN)


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
	assert_object(TargetStatus.word_of(lone, none)).is_same(TargetStatus.POWERED)
	assert_object(TargetStatus.word_of(lamp, none)).is_same(TargetStatus.POWERED)
	power.on = false
	assert_object(TargetStatus.word_of(lamp, none)).is_same(TargetStatus.NO_POWER)
	assert_object(TargetStatus.word_of(crate, none)).is_null()
	assert_object(TargetStatus.word_of(guard, none)).is_null()
	ActorState.set_tag(guard, ActorState.UNCONSCIOUS, true)
	assert_object(TargetStatus.word_of(guard, none)).is_same(TargetStatus.UNCONSCIOUS)
	ActorState.set_tag(guard, ActorState.DEAD, true)
	assert_object(TargetStatus.word_of(guard, none)).is_same(TargetStatus.DEAD)


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
