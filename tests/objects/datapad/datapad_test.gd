extends GdUnitTestSuite
## Integration (ADR 0060): the player reads a world datapad in place with E. The prompt names it,
## the reading overlay shows its text (the world keeps running, the player's input is off and the
## mouse free: ADR 0110), the player's PersonalLog gets the entry once (HUD "Added to log"), its code
## becomes known, and the datapad stays in the world while the inventory is unchanged. E closing the
## overlay is not a second read. The overlay closes when the player is knocked out.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const DATAPAD: PackedScene = preload("res://objects/datapad/datapad.tscn")
## On the floor 0.6 m ahead (centre to centre): about 1.75 m from the eyes, inside the 2 m reach.
const PAD_POSITION := Vector3(0, 0.02, -0.6)

var _driver: PlayerDriver
var _player: Player
var _overlay: ReadingOverlay
var _log: PersonalLog


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_datapad_scene_is_a_readable_prop_not_an_item() -> void:
	var pad: RigidBody3D = auto_free(DATAPAD.instantiate())

	assert_object(ItemPickup.of(pad)).is_null()
	assert_object(Usable.of(pad) as Readable).is_not_null()
	assert_bool(pad is PhysicsObject).is_true()


func test_e_reads_in_place_and_logs_the_entry() -> void:
	await _load()
	var pad := await _spawn_pad(&"test.storage", "Storage access", "Code 2817.", {&"storage_door": "2817"})
	assert_str(_player.interactor.prompt).is_equal("E: read Storage access")

	await _driver.press(&"use")

	assert_bool(_overlay.is_open()).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_player.input_enabled).is_false()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	assert_str(_overlay.title_label.text).is_equal("Storage access")
	assert_str(_overlay.text_label.text).is_equal("Code 2817.")
	assert_int(_log.entries().size()).is_equal(1)
	assert_str(_log.entries()[0].source).is_equal("Datapad")
	assert_str(_log.known_code(&"storage_door")).is_equal("2817")
	assert_str(_log.code_source(&"storage_door")).is_equal("Storage access")
	assert_array(Objects.logged(&"log.entry_added", "entry_id", "test.storage")).has_size(1)
	# Read in place: still in the world, nothing in the inventory.
	assert_bool(is_instance_valid(pad) and pad.is_inside_tree()).is_true()
	assert_array(_player.inventory.inventory.stacks).is_empty()
	assert_array(EventLog.find(&"item.picked_up")).is_empty()

	await _driver.press(&"use")
	assert_bool(_overlay.is_open()).is_false()
	assert_bool(_player.input_enabled).is_true()
	# The HUD says it was added.
	var hud := _player.get_node("Hud") as Hud
	assert_str(hud.message_label.text).is_equal("Added to log: Storage access")
	# The E that closed the overlay is not a new read.
	await _driver.frames(3)
	assert_bool(_overlay.is_open()).is_false()


func test_reading_twice_keeps_one_entry() -> void:
	await _load()
	await _spawn_pad(&"test.memo", "Memo", "Hello")

	await _driver.press(&"use")
	await _driver.press(&"ui_cancel")
	await _driver.press(&"use")

	assert_bool(_overlay.is_open()).is_true()
	assert_str(_overlay.text_label.text).is_equal("Hello")
	assert_int(_log.entries().size()).is_equal(1)
	assert_array(EventLog.find(&"log.entry_added")).has_size(1)
	await _driver.press(&"ui_cancel")


func test_two_datapads_make_two_entries_newest_first() -> void:
	await _load()
	await _spawn_pad(&"test.first", "First", "One")
	await _driver.press(&"use")
	await _driver.press(&"ui_cancel")
	_player.get_parent().get_node("Datapad").free()
	await _spawn_pad(&"test.second", "Second", "Two")
	await _driver.press(&"use")
	await _driver.press(&"ui_cancel")

	assert_int(_log.entries().size()).is_equal(2)
	assert_str(_log.entries()[0].title).is_equal("Second")


func test_dead_player_cannot_read() -> void:
	await _load()
	await _spawn_pad(&"test.memo", "Memo", "Hello")
	_player.body.take_damage(&"damage.ballistic", 30.0, &"head")
	_player.reload_on_reset = false

	await _driver.press(&"use")

	assert_bool(_overlay.is_open()).is_false()
	assert_array(_log.entries()).is_empty()


func test_player_log_survives_save_and_load() -> void:
	await _load()
	await _spawn_pad(&"test.storage", "Storage access", "Code 2817.", {&"storage_door": "2817"})
	await _driver.press(&"use")
	await _driver.press(&"ui_cancel")
	assert_bool(_log.is_in_group(&"saveable")).is_true()
	var saved := _log.save_state()

	_log.load_state({})
	assert_array(_log.entries()).is_empty()
	assert_str(_log.known_code(&"storage_door")).is_equal("")
	_log.load_state(saved)

	assert_int(_log.entries().size()).is_equal(1)
	assert_str(_log.entries()[0].title).is_equal("Storage access")
	assert_str(_log.known_code(&"storage_door")).is_equal("2817")


func _spawn_pad(entry_id: StringName, title: String, text: String, codes: Dictionary = {}) -> RigidBody3D:
	var pad := DATAPAD.instantiate() as RigidBody3D
	var readable := Usable.of(pad) as Readable
	readable.entry_id = entry_id
	readable.title = title
	readable.text = text
	readable.codes.assign(codes)
	_player.get_parent().add_child(pad)
	pad.global_position = PAD_POSITION
	await _driver.frames(20)
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, pad.global_position))
	await _driver.frames(3)
	return pad


func test_the_overlay_closes_when_the_player_is_knocked_out() -> void:
	await _load()
	_log.read(LogEntry.make(&"test.note", "Note", "Text.", "Datapad"))
	assert_bool(_overlay.is_open()).is_true()

	_player.body.take_damage(&"damage.stun", 1000.0)
	await _driver.frames(2)

	assert_bool(_overlay.is_open()).is_false()
	assert_bool(_player.input_enabled).is_true()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_player.reload_on_reset = false
	_overlay = _player.get_node("ReadingOverlay") as ReadingOverlay
	_log = PersonalLog.of(_player)
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
