extends GdUnitTestSuite
## Integration: the HUD's interaction frame (ADR 0129) on what the Interactor targets: a pickup, a
## usable built from bare components, a carryable body; hidden when looking away, out of reach,
## while carrying and while the player cannot act.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const WALL_POINT := Vector3(0, 1.5, -5.8)

var _driver: PlayerDriver
var _player: Player
var _frame: TargetFrame


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_frames_a_pickup_within_reach_with_its_name() -> void:
	await _load()
	var tool := Items.spawn_pickup(_driver.runner.scene(), Items.LOCKPICK, Vector3(0, 0.05, -0.9), 3)
	await _driver.frames(20)

	await _look_at(tool.global_position)

	assert_bool(_frame.visible).is_true()
	assert_str(_frame.name_text()).is_equal("Lockpick (3)")
	assert_bool(_frame.frame_rect.has_point(_projected(tool.global_position))).is_true()
	# The prompt under the crosshair is unchanged.
	assert_str(_player.interactor.prompt).is_equal("E: pick up Lockpick (3)")

	await _look_at(WALL_POINT)
	assert_bool(_frame.visible).is_false()
	assert_str(_frame.name_text()).is_equal("")


func test_hidden_out_of_reach() -> void:
	await _load()
	var tool := Items.spawn_pickup(_driver.runner.scene(), Items.LOCKPICK, Vector3(0, 0.05, -0.9))
	await _driver.frames(20)
	await _look_at(tool.global_position)
	assert_bool(_frame.visible).is_true()

	# 2.0 m reach: from 1.6 m further back the pickup is about 3 m from the eye.
	_player.load_state(Objects.aiming_state(_player, Vector3(0, 0, 1.6), tool.global_position))
	await _driver.frames(3)
	_frame.refresh(_player)

	assert_bool(_frame.visible).is_false()


func test_frames_a_usable_built_from_components_but_not_its_label() -> void:
	await _load()
	var panel := _usable_panel(Vector3(0.4, 1.3, -1.0))
	await _driver.frames(5)

	await _look_at(panel.global_position)

	assert_int(_player.interactor.kind).is_equal(Interactor.Kind.USE)
	assert_bool(_frame.visible).is_true()
	assert_str(_frame.name_text()).is_equal("Wall switch")
	assert_bool(_frame.frame_rect.has_point(_projected(panel.global_position))).is_true()
	# Its floating label (a HUD-like helper 0.6 m above it) is not framed.
	assert_bool(_frame.frame_rect.has_point(_projected(panel.global_position + Vector3.UP * 0.6))).is_false()


func test_frames_a_carryable_body_and_not_while_carrying_it() -> void:
	await _load()
	var crate := Objects.spawn(_driver.runner.scene(), Objects.SMALL_CRATE, Vector3(0, 0.3, -1.4))
	await _driver.frames(20)
	await _look_at(crate.global_position)

	assert_int(_player.interactor.kind).is_equal(Interactor.Kind.CARRY)
	assert_bool(_frame.visible).is_true()
	assert_str(_frame.name_text()).is_equal("Small crate")
	assert_bool(_frame.frame_rect.has_point(_projected(crate.global_position))).is_true()

	await _driver.hold(&"use", 2)
	await _driver.frames(2)
	_frame.refresh(_player)

	assert_bool(_player.carry.is_carrying()).is_true()
	assert_bool(_frame.visible).is_false()


func test_hidden_while_the_player_cannot_act() -> void:
	await _load()
	var tool := Items.spawn_pickup(_driver.runner.scene(), Items.LOCKPICK, Vector3(0, 0.05, -0.9))
	await _driver.frames(20)
	await _look_at(tool.global_position)
	assert_bool(_frame.visible).is_true()

	ActorState.set_tag(_player, ActorState.UNCONSCIOUS, true)
	await _driver.frames(2)
	_frame.refresh(_player)

	assert_bool(_frame.visible).is_false()
	ActorState.set_tag(_player, ActorState.UNCONSCIOUS, false)


func test_visual_parts_leave_out_helpers() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	root.add_child(mesh)
	var shadow := MeshInstance3D.new()
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	root.add_child(shadow)
	root.add_child(Label3D.new())
	root.add_child(CPUParticles3D.new())
	var overlay := MeshInstance3D.new()
	overlay.top_level = true
	root.add_child(overlay)

	var parts := TargetFrame.visual_parts(root)

	assert_array(parts).contains_exactly([mesh])
	root.free()


# A wall switch from bare components: a static body with a box, a mesh, a Usable and a label above.
func _usable_panel(position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "WallSwitch"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.4, 0.1)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	body.add_child(mesh)
	var label := Label3D.new()
	label.text = "SWITCH"
	label.position = Vector3.UP * 0.6
	body.add_child(label)
	var usable := Usable.new()
	usable.verb = "press"
	body.add_child(usable)
	_driver.runner.scene().add_child(body)
	body.global_position = position
	return body


func _projected(point: Vector3) -> Vector2:
	return _frame.get_viewport().get_camera_3d().unproject_position(point)


func _look_at(target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, target))
	await _driver.frames(3)
	_frame.refresh(_player)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_frame = (_player.get_node("Hud") as Hud).target_frame
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
