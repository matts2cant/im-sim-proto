extends GdUnitTestSuite
## Integration (ADR 0131): the player (input off, driven through its components) in the grenade
## room. With Demolition Trained, crouched 1.5 m from a frag mine on the floor (centre to mine,
## horizontal), E (Interactor.perform()) puts it back into the inventory as a frag grenade. Saving
## and loading the room keeps a thrown grenade's fuse, a stuck one's arming and pose, and the grenades
## left in the inventory.

const Wait := preload("res://tests/helpers/wait.gd")
const ROOM := "res://tests/items/grenades/fixtures/grenade_room.tscn"
const FRAG: ItemData = preload("res://items/grenades/frag/frag_grenade_item.tres")
const FRAG_SCENE := "res://items/grenades/frag/frag_grenade.tscn"
const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")

var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_trained_crouched_player_disarms_a_mine_into_the_inventory() -> void:
	var room := await _room()
	_place(Vector3(0, 0, 8), 0.0, 0.0, false)
	var mine := (load(FRAG_SCENE) as PackedScene).instantiate() as RigidBody3D
	room.add_child(mine)
	var at := Vector3(0, 0, 4.5)
	var floor_node := room.get_node("Floor") as Node3D
	Sticky.of(mine).stick(floor_node, ThrowRules.stick_transform(at, Vector3.UP, Vector3.FORWARD, 0.053))
	await Grenades.seconds(get_tree(), 2.1)
	assert_bool(ProximityTrigger.of(mine).is_armed).is_true()
	_player.skills.set_tier(&"demolition", 1)
	# Crouched 1.5 m from it, looking at it.
	var feet := Vector3(0, 0, 6.0)
	var to := mine.global_position - (feet + Vector3.UP * _player.config.crouched_eye_height)
	_place(feet, 0.0, atan2(to.y, Vector2(to.x, to.z).length()), true)
	await Wait.frames(get_tree(), 3)
	_player.interactor.refresh()
	assert_str(_player.interactor.target_name).is_equal("Frag grenade")

	assert_bool(_player.interactor.perform()).is_true()
	await Wait.frames(get_tree(), 2)

	assert_bool(is_instance_valid(mine)).is_false()
	assert_array(EventLog.find(&"mine.disarmed")).has_size(1)
	assert_array(EventLog.find(&"object.exploded")).is_empty()
	assert_object(_player.inventory.belt.stack_in(0).item).is_same(FRAG)


func test_save_and_load_keep_fuses_mines_and_the_inventory() -> void:
	var room := await _room()
	_place(Vector3.ZERO, 0.0, 0.0, false)
	_player.inventory.give(FRAG, 3)
	_player.inventory.select_slot(0)
	await Wait.frames(get_tree(), 1)
	# Stick one on the wall 1.0 m ahead, then turn to the open floor (-X) and throw one.
	_player.weapons.trigger()
	_place(Vector3.ZERO, PI * 0.5, 0.0, false)
	await Wait.frames(get_tree(), 50)
	_player.weapons.trigger()
	await Wait.frames(get_tree(), 12)
	var saved := _grenades(room)
	assert_int(saved.size()).is_equal(2)
	var thrown_left := Fuse.of(saved["thrown"]).left
	var arming_left := ProximityTrigger.of(saved["stuck"]).arming_left
	var stuck_at := (saved["stuck"] as Node3D).global_position
	var snapshot := LevelSnapshot.capture(room)
	room.free()
	StimulusSystem.clear()

	var fresh := await _room()
	var report := LevelSnapshot.apply(fresh, snapshot)

	assert_array(report.skipped).is_empty()
	var restored := _grenades(fresh)
	assert_int(restored.size()).is_equal(2)
	assert_float(Fuse.of(restored["thrown"]).left).is_equal_approx(thrown_left, 0.001)
	var stuck := restored["stuck"] as RigidBody3D
	assert_bool(Sticky.of(stuck).is_stuck).is_true()
	assert_bool(stuck.freeze).is_true()
	assert_float(ProximityTrigger.of(stuck).arming_left).is_equal_approx(arming_left, 0.001)
	assert_vector(stuck.global_position).is_equal_approx(stuck_at, Vector3.ONE * 0.01)
	assert_int(_player.inventory.belt.stack_in(0).count).is_equal(1)
	assert_object(_player.weapons.weapon()).is_same(FRAG.weapon)


# The room's grenades: {"thrown": lit fuse, "stuck": stuck}.
func _grenades(room: Node) -> Dictionary:
	var found := {}
	for child in room.get_children():
		var sticky := Sticky.of(child)
		if sticky == null:
			continue
		if sticky.is_stuck:
			found["stuck"] = child
		elif Fuse.of(child).is_lit:
			found["thrown"] = child
	return found


func _place(feet: Vector3, yaw: float, pitch: float, crouched: bool) -> void:
	_player.load_state({"position": feet, "yaw": yaw, "pitch": pitch, "crouched": crouched, "velocity": Vector3.ZERO})


# The grenade room with its player's input off (its stance stays as load_state() sets it).
func _room() -> Node3D:
	var room := (load(ROOM) as PackedScene).instantiate() as Node3D
	_player = room.get_node("Player") as Player
	_player.input_enabled = false
	add_child(room)
	auto_free(room)
	await Wait.frames(get_tree(), 5)
	return room
