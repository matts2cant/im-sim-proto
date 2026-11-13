extends GdUnitTestSuite
## Network lab (gallery room 8), bay B (ADR 0130 step 3): the locked linking bay on the hall's east
## wall holding RTR-02, SW-SERVERS and the file server. With a lockpick in hand, LMB on its glass
## door starts the lockpicking minigame on it, and a finished pick swings it open; its key lies on the
## closet shelf, goes to the keychain, and E with it opens the door. Open, the file server inside is
## within reach. Lab-local positions; the fixture `fixtures/lab_player.tscn` (the room alone).

const Lab := preload("res://tests/levels/gallery/network_lab/network_lab_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
## In front of bay B's glass door (the bay's front at x 11.39), 0.9 m out, and the door's middle.
const AT_BAY_B := Vector3(10.5, 0, -15.7)
const BAY_B_GLASS := Vector3(11.375, 1.0, -15.7)

var _lab: Lab


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_lab = Lab.new()
	await _lab.setup(scene_runner(Lab.FIXTURE))


func after_test() -> void:
	StimulusSystem.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _door() -> HingedDoor:
	return HingedDoor.of(_lab.node("Devices/BayB/GlassDoor"))


func test_a_lockpick_starts_the_minigame_on_the_glass_door_and_a_pick_opens_it() -> void:
	var player := _lab.player
	player.inventory.give(Items.LOCKPICK, 1)
	player.inventory.hold(player.inventory.inventory.stacks_of(&"lockpick")[0])
	await _lab.stand(AT_BAY_B, BAY_B_GLASS)
	var glass := _lab.node("Devices/BayB/GlassDoor")
	assert_object(player.interactor.looked_at).is_same(glass)
	assert_bool(_door().is_locked()).is_true()

	await _lab.driver.hold(&"fire", 2)
	await _lab.driver.frames(1)

	var screen := LockpickScreen.of(player)
	assert_bool(screen.is_open()).is_true()
	var started := EventLog.find(&"lock.pick_started")
	assert_int(started.size()).is_equal(1)
	screen.close()
	var lock := glass.get_node("MechanicalLock") as MechanicalLock
	assert_bool(lock.complete_pick(player)).is_true()
	assert_bool(_door().open).is_true()


func test_the_key_from_the_closet_shelf_opens_bay_b() -> void:
	var player := _lab.player
	var key := _lab.node("Items/BayKey")
	# On the closet shelf, behind the closet door.
	var shelf := _lab.node("Furniture/ClosetShelf")
	assert_float(key.position.y).is_between(0.8, 0.85)
	assert_float(absf(key.position.x - shelf.position.x)).is_less(0.5)
	var closet := _lab.node("Shell/Closet") as Room
	assert_float(absf(key.position.z - closet.position.z)).is_less(closet.size.z * 0.5)
	var data := (_lab.node("Devices/BayB/GlassDoor/MechanicalLock") as MechanicalLock).data
	assert_str(String(data.key_id)).is_equal(str(ItemPickup.of(key).state["key_id"]))
	assert_str(ItemPickup.of(key).found_text).is_not_empty()
	# E without the key: still locked.
	await _lab.stand(AT_BAY_B, BAY_B_GLASS)
	assert_bool(_door().use(player)).is_false()
	assert_bool(_door().open).is_false()

	assert_bool(player.inventory.pick_up(ItemPickup.of(key))).is_true()
	await _lab.driver.frames(2)

	assert_bool(_door().use(player)).is_true()
	assert_bool(_door().open).is_true()
	await _lab.seconds(0.7)
	# Open: the crosshair on the file server's front reaches it.
	var server := _lab.node("Devices/BayB/FileServer")
	await _lab.stand(AT_BAY_B, server.global_transform * Vector3(0, 0.044, 0) - Lab.ORIGIN)
	assert_object(player.interactor.looked_at).is_same(server)
