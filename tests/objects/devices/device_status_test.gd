extends GdUnitTestSuite
## Unit (ADR 0083, ADR 0137): DeviceStatus collects what a security screen shows from any entity's
## components (stand-ins here, not shipped devices): offline hides everything, online lists each
## component's words in tree order without duplicates, a view comes from whichever component offers
## one, a device is disabled when one of its components says so (ADR 0099 amendment), the commands
## offered are those its components declare now, and one colour rule (tone()) colours every screen.

const StatusStandIn := preload("res://tests/objects/devices/fixtures/status_stand_in.gd")
const ViewStandIn := preload("res://tests/objects/devices/fixtures/view_stand_in.gd")
const DisableStandIn := preload("res://tests/objects/devices/fixtures/disable_stand_in.gd")
const CommandStandIn := preload("res://tests/objects/devices/fixtures/command_stand_in.gd")


func _entity(words_per_component: Array[PackedStringArray]) -> Node3D:
	var entity: Node3D = auto_free(Node3D.new())
	for words in words_per_component:
		var component: Node = StatusStandIn.new()
		component.set("words", words)
		entity.add_child(component)
	return entity


func _words(texts: Array[String]) -> Array[StatusWord]:
	var found: Array[StatusWord] = []
	for text in texts:
		found.append(StatusWord.make(text))
	return found


func test_offline_is_only_offline() -> void:
	var words := DeviceStatus.summarize(false, _words(["enabled", "ringing"]))
	assert_array(Array(StatusWord.texts(words))).contains_exactly(["offline"])


func test_online_comes_first_then_the_words_without_duplicates() -> void:
	var words := DeviceStatus.summarize(true, _words(["enabled", "", "online", "enabled", "offline", "alert"]))
	assert_array(Array(StatusWord.texts(words))).contains_exactly(["online", "enabled", "alert"])


func test_words_come_from_every_component_in_tree_order() -> void:
	var entity := _entity([PackedStringArray(["open"]), PackedStringArray(["locked"])])
	# A child without the method adds nothing.
	entity.add_child(Node.new())
	assert_array(Array(DeviceStatus.of(entity, true))).contains_exactly(["online", "open", "locked"])
	assert_array(Array(DeviceStatus.of(entity, false))).contains_exactly(["offline"])
	# A device with no status component is just online.
	assert_array(Array(DeviceStatus.of(_entity([]), true))).contains_exactly(["online"])


func test_alert_is_a_flag_of_the_word_never_its_text() -> void:
	var entity := _entity([PackedStringArray(["ringing"])])
	assert_bool(StatusWord.any_alert(DeviceStatus.words_of(entity, true))).is_false()
	(entity.get_child(0) as Node).set("alert_words", PackedStringArray(["ringing"]))
	assert_bool(StatusWord.any_alert(DeviceStatus.words_of(entity, true))).is_true()
	# Offline: nothing is known, nothing alerts.
	assert_bool(StatusWord.any_alert(DeviceStatus.words_of(entity, false))).is_false()
	# The shipped words carry the flag.
	assert_bool(DeviceStatus.RINGING.alert).is_true()
	assert_bool(DeviceStatus.SILENT.alert).is_false()


func test_one_colour_rule_for_every_screen() -> void:
	var online := PackedStringArray(["online", "enabled"])
	var offline := PackedStringArray(["offline"])
	assert_int(DeviceStatus.tone(online)).is_equal(DeviceStatus.Tone.ONLINE)
	assert_int(DeviceStatus.tone(online, false, false, true)).is_equal(DeviceStatus.Tone.ALERT)
	assert_int(DeviceStatus.tone(online, false, true, true)).is_equal(DeviceStatus.Tone.ACCESS)
	assert_int(DeviceStatus.tone(online, true, true, true)).is_equal(DeviceStatus.Tone.DISABLED)
	assert_int(DeviceStatus.tone(offline, true, true, true)).is_equal(DeviceStatus.Tone.OFFLINE)
	# The deck and the Security app paint the same tones (each in its palette).
	assert_object(DeckStyle.status_color(online, false, false, true)).is_equal(DeckStyle.ALERT_COLOR)
	assert_object(HalcyonStyle.status_color(online, false, true)).is_equal(HalcyonStyle.ALERT)
	assert_object(HalcyonStyle.status_color(offline, true, true)).is_equal(HalcyonStyle.OFFLINE)
	assert_str(DeviceStatus.short_text(PackedStringArray(["online"]))).is_equal("online")
	assert_str(DeviceStatus.short_text(PackedStringArray(["online", "enabled", "clear"]))).is_equal("enabled · clear")
	assert_str(DeviceStatus.short_text(offline)).is_equal("offline")


func test_a_view_comes_from_the_component_that_offers_one() -> void:
	var entity := _entity([PackedStringArray(["enabled"])])
	assert_bool(DeviceStatus.has_view(entity)).is_false()
	assert_object(DeviceStatus.view_of(entity)).is_null()
	var eye: Node3D = auto_free(Node3D.new())
	var component: Node = ViewStandIn.new()
	component.set("view", eye)
	entity.add_child(component)
	assert_bool(DeviceStatus.has_view(entity)).is_true()
	assert_object(DeviceStatus.view_of(entity)).is_same(eye)
	# Seeing nothing (disabled): it still has a view, but there is nothing to show.
	component.set("seeing", false)
	assert_bool(DeviceStatus.has_view(entity)).is_true()
	assert_object(DeviceStatus.view_of(entity)).is_null()


func test_disabled_when_a_component_says_so() -> void:
	# Components that cannot be switched off (no device_disabled()) never make it disabled.
	var entity := _entity([PackedStringArray(["silent"])])
	assert_bool(DeviceStatus.is_disabled(entity)).is_false()
	var component: Node = DisableStandIn.new()
	entity.add_child(component)
	assert_bool(DeviceStatus.is_disabled(entity)).is_false()
	component.set("disabled", true)
	assert_bool(DeviceStatus.is_disabled(entity)).is_true()
	assert_bool(DeviceStatus.is_disabled(null)).is_false()


func test_a_new_toggle_command_needs_only_its_component() -> void:
	# The table (a screen's commands the device accepts, in order) holds a command pair no shipped
	# code knows: the component alone says which applies now.
	var table: Array[StringName] = [CommandStandIn.ON, CommandStandIn.OFF, Siren.TEST]
	var entity: Node3D = auto_free(Node3D.new())
	var component: Node = CommandStandIn.new()
	entity.add_child(component)
	assert_array(DeviceStatus.applicable(table, entity)).is_equal([CommandStandIn.ON])
	component.set("on", true)
	assert_array(DeviceStatus.applicable(table, entity)).is_equal([CommandStandIn.OFF])
	# Its status word sits next to it.
	assert_array(Array(DeviceStatus.of(entity, true))).contains_exactly(["online", "on"])


func test_only_the_commands_that_apply_are_offered_in_table_order() -> void:
	# By what the components declare now, never by what the device is (ADR 0113, ADR 0137).
	var table: Array[StringName] = [
		Lockable.LOCK, Lockable.UNLOCK, DeviceSwitch.ENABLE, DeviceSwitch.DISABLE, CommandStandIn.ON
	]
	var entity: Node3D = auto_free(Node3D.new())
	var lockable := Lockable.new()
	lockable.locked = true
	entity.add_child(lockable)
	var switch: Node = DisableStandIn.new()
	entity.add_child(switch)
	entity.add_child(CommandStandIn.new())
	assert_array(DeviceStatus.applicable(table, entity)).is_equal(
		[Lockable.UNLOCK, DeviceSwitch.DISABLE, CommandStandIn.ON]
	)
	lockable.locked = false
	assert_array(DeviceStatus.applicable(table, entity)).is_equal(
		[Lockable.LOCK, DeviceSwitch.DISABLE, CommandStandIn.ON]
	)
	# Switched off: only what the switched-off component offers (Enable), nothing else works.
	switch.set("disabled", true)
	assert_array(DeviceStatus.applicable(table, entity)).is_equal([DeviceSwitch.ENABLE])
	# Its table without Enable: nothing.
	var no_enable: Array[StringName] = [Lockable.LOCK, Lockable.UNLOCK]
	assert_array(DeviceStatus.applicable(no_enable, entity)).is_empty()


func test_a_device_whose_components_declare_nothing_offers_every_command() -> void:
	var table: Array[StringName] = [Siren.RING, Siren.SILENCE]
	assert_array(DeviceStatus.applicable(table, _entity([PackedStringArray(["silent"])]))).is_equal(table)
	assert_array(DeviceStatus.applicable(table, null)).is_empty()
