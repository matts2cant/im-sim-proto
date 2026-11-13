extends GdUnitTestSuite
## "Clean hands" (M12c, ADR 0115): MissionTally counts what the player broke from real EventLog
## entries, on shipped props and devices damaged by stimuli: a crate, a camera and a network switch
## (devices keep their broken husk), a barrel the player shot (its blast breaks the crate beside it
## too). A guard breaking something on its own is not the player's. The tally listens to
## EventLog.entry_added like the mission does.

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const CRATE: PackedScene = preload("res://objects/small_crate/small_crate.tscn")
const BARREL: PackedScene = preload("res://objects/explosive_barrel/explosive_barrel.tscn")
const CAMERA: PackedScene = preload("res://objects/camera/security_camera.tscn")
const SWITCH: PackedScene = preload("res://objects/network/switch_rack.tscn")
const ORIGIN := Vector3(260, 0, -380)

var _root: Node3D
var _tally: MissionTally
var _player: Node3D
var _guard: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_player = _stand_in("Player", Vector3(0, 1, -6), &"actor.player")
	_guard = _stand_in("Guard", Vector3(2, 1, -6), &"actor.guard")
	_tally = MissionTally.new()
	EventLog.entry_added.connect(_tally.observe)
	await Wait.frames(get_tree(), 2)


func after_test() -> void:
	if EventLog.entry_added.is_connected(_tally.observe):
		EventLog.entry_added.disconnect(_tally.observe)
	StimulusSystem.clear()


# A character stand-in: what makes it the player is its tag (MissionTally), not its name.
func _stand_in(node_name: String, offset: Vector3, tag: StringName) -> Node3D:
	return Fixtures.entity(_root, node_name, ORIGIN + offset, [], [tag] as Array[StringName])


func _add(scene: PackedScene, node_name: String, offset: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	node.position = ORIGIN + offset
	_root.add_child(node)
	return node


# Hits `target` with a heavy ballistic hit from `by` (delivered on the next tick).
func _hit(target: Node3D, by: Node3D) -> void:
	StimulusSystem.emit(Stimulus.make_contact(&"damage.ballistic", 500.0, target, by))


func test_nothing_broken_keeps_clean_hands() -> void:
	_add(CRATE, "Crate", Vector3(0, 0.3, 0))
	await Wait.frames(get_tree(), 4)
	assert_bool(_tally.clean_hands()).is_true()


func test_breaking_a_crate_loses_it() -> void:
	var crate := _add(CRATE, "Crate", Vector3(0, 0.3, 0))
	# Its stable id while it stands (it falls apart and is freed).
	var id := MissionTally.object_id(crate)
	_hit(crate, _player)
	await Wait.frames(get_tree(), 4)
	assert_bool(_tally.clean_hands()).is_false()
	assert_array(_tally.broken.keys()).contains_exactly([id])


func test_breaking_a_camera_or_a_switch_loses_it() -> void:
	var camera := _add(CAMERA, "Camera", Vector3(0, 2.5, 0))
	var switch := _add(SWITCH, "Switch", Vector3(3, 1.5, 0))
	_hit(camera, _player)
	await Wait.frames(get_tree(), 4)
	assert_bool(Device.of(camera).broken).is_true()
	assert_bool(_tally.has_broken(camera)).is_true()
	assert_int(_tally.broken.size()).is_equal(1)
	_hit(switch, _player)
	await Wait.frames(get_tree(), 4)
	assert_bool(_tally.has_broken(switch)).is_true()
	assert_int(_tally.broken.size()).is_equal(2)
	# Saved and loaded with the mission's tally.
	var loaded := MissionTally.new()
	loaded.from_dict(_tally.to_dict())
	assert_bool(loaded.clean_hands()).is_false()
	assert_bool(loaded.has_broken(camera)).is_true()
	assert_bool(loaded.has_broken(switch)).is_true()


func test_a_barrel_the_player_shot_breaks_it_and_what_its_blast_breaks() -> void:
	var barrel := _add(BARREL, "Barrel", Vector3(0, 0.5, 0))
	var crate := _add(CRATE, "Crate", Vector3(1.2, 0.3, 0))
	# Their stable ids while they still stand (both break apart and leave the tree).
	var ids := [MissionTally.object_id(barrel), MissionTally.object_id(crate)]
	_hit(barrel, _player)
	await Wait.frames(get_tree(), 6)
	assert_bool(_tally.broken.has(ids[0])).is_true()
	assert_bool(_tally.broken.has(ids[1])).is_true()
	assert_bool(_tally.clean_hands()).is_false()


func test_a_guard_breaking_things_on_its_own_keeps_clean_hands() -> void:
	var crate := _add(CRATE, "Crate", Vector3(0, 0.3, 0))
	var camera := _add(CAMERA, "Camera", Vector3(3, 2.5, 0))
	_hit(crate, _guard)
	_hit(camera, _guard)
	await Wait.frames(get_tree(), 4)
	assert_bool(Device.of(camera).broken).is_true()
	assert_bool(_tally.clean_hands()).is_true()
