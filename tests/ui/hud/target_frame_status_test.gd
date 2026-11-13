extends GdUnitTestSuite
## Integration (ADR 0130): the interaction frame on things E does not act on, in the carry room
## (player at the origin facing -Z, eye 1.65 m). Minimal entities built from components: a network
## device (network_fixtures.body_device) cabled to a gear switch, a Powered-only prop and a bare
## BodyParts character; each shows its status line, which follows the state live. Within reach only
## (2 m: a face 1.5 m from the eye shows, 3 m does not). E on a too-heavy crate says "Too heavy";
## the HUD has no prompt line.
##   Panel (0, 1.65, -1.7: face 1.5 m) ── Switch (gear, off to the side at x 3)

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
## A 0.4 m box centred here has its front face 1.5 m from the eye.
const NEAR := Vector3(0, 1.65, -1.7)
## ... and here 3 m.
const FAR := Vector3(0, 1.65, -3.2)

var _driver: PlayerDriver
var _player: Player
var _hud: Hud
var _frame: TargetFrame


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_a_network_device_shows_its_status_live() -> void:
	await _load()
	var scene := _driver.runner.scene()
	var switch := Net.body_device(scene, "Switch", Vector3(3, 1.65, -3), [], true, 10.0)
	ActorState.set_tag(switch, DeviceNetwork.NETWORK_GEAR, true)
	var panel := Net.body_device(scene, "Panel", NEAR, [], true, 10.0)
	var toggle := DeviceSwitch.new()
	toggle.name = "DeviceSwitch"
	panel.add_child(toggle)
	Net.link(panel, switch)
	await _driver.frames(3)

	await _look_at(panel.global_position)
	assert_bool(_frame.visible).is_true()
	assert_object(_frame.target).is_same(panel)
	assert_str(_frame.name_text()).is_equal("Panel")
	assert_str(_frame.status_text()).is_equal("Online")
	assert_that(_frame.status_square.color).is_equal(StatusLight.COLORS[StatusLight.State.UP])

	(switch.get_node("Powered") as Powered).on = false
	_frame.refresh(_player)
	assert_str(_frame.status_text()).is_equal("Cut off")
	(switch.get_node("Powered") as Powered).on = true
	toggle.set_disabled(true)
	_frame.refresh(_player)
	assert_str(_frame.status_text()).is_equal("Disabled")
	(panel.get_node("Powered") as Powered).on = false
	_frame.refresh(_player)
	assert_str(_frame.status_text()).is_equal("No power")
	assert_that(_frame.status_square.color).is_equal(TargetStatus.NO_POWER_COLOR)


func test_shown_within_reach_only() -> void:
	await _load()
	var panel := Net.body_device(_driver.runner.scene(), "Panel", NEAR, [], true, 10.0)
	await _driver.frames(3)
	await _look_at(panel.global_position)
	assert_bool(_frame.visible).is_true()
	assert_str(_frame.status_text()).is_equal("Powered")

	panel.global_position = FAR
	await _look_at(panel.global_position)

	assert_bool(_frame.visible).is_false()


func test_a_powered_prop_off_any_network() -> void:
	await _load()
	var lamp := _box(_driver.runner.scene(), "WallLamp", NEAR)
	var power := Powered.new()
	power.name = "Powered"
	lamp.add_child(power)
	await _driver.frames(2)

	await _look_at(lamp.global_position)
	assert_str(_frame.name_text()).is_equal("Wall lamp")
	assert_str(_frame.status_text()).is_equal("Powered")
	power.on = false
	_frame.refresh(_player)
	assert_str(_frame.status_text()).is_equal("No power")

	# A prop with none of those components is not framed.
	lamp.remove_child(power)
	power.free()
	await _look_at(lamp.global_position)
	assert_bool(_frame.visible).is_false()


func test_a_character_awake_unconscious_dead() -> void:
	await _load()
	var body := Characters.character(
		_driver.runner.scene(), "Walker", Vector3(0, 0, -1.6), [] as Array[StringName], PhysicsLayers.OBJECTS
	)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = Characters.RADIUS
	capsule.height = Characters.HEIGHT
	mesh.mesh = capsule
	mesh.position.y = Characters.HEIGHT * 0.5
	body.add_child(mesh)
	await _driver.frames(5)
	var chest := body.global_position + Vector3.UP * 1.2

	await _look_at(chest)
	assert_object(_frame.target).is_same(body)
	assert_str(_frame.name_text()).is_equal("Walker")
	assert_str(_frame.status_text()).is_equal("")

	ActorState.set_tag(body, ActorState.UNCONSCIOUS, true)
	_frame.refresh(_player)
	assert_str(_frame.status_text()).is_equal("Unconscious")
	ActorState.set_tag(body, ActorState.DEAD, true)
	_frame.refresh(_player)
	assert_str(_frame.status_text()).is_equal("Dead")


func test_e_on_a_too_heavy_crate_says_so() -> void:
	await _load()
	var heavy := Objects.spawn(_driver.runner.scene(), Objects.LARGE_CRATE, Vector3(-1.3, 0.6, -0.8))
	await _driver.frames(20)
	await _look_at(heavy.global_position)
	assert_int(_player.interactor.kind).is_equal(Interactor.Kind.TOO_HEAVY)

	await _driver.hold(&"use", 2)
	await _driver.frames(1)

	assert_bool(_player.carry.is_carrying()).is_false()
	assert_str(_hud.message_label.text).is_equal("Too heavy")


func test_e_on_an_unavailable_usable_says_why() -> void:
	await _load()
	var panel := _box(_driver.runner.scene(), "Terminal", NEAR)
	var power := Powered.new()
	power.name = "Powered"
	panel.add_child(power)
	panel.add_child(DeadWithoutPower.new())
	await _driver.frames(2)
	await _look_at(panel.global_position)
	assert_int(_player.interactor.kind).is_equal(Interactor.Kind.USE)

	power.on = false
	await _look_at(panel.global_position)
	# Not usable, still framed as a powered thing.
	assert_int(_player.interactor.kind).is_equal(Interactor.Kind.NONE)
	assert_str(_frame.status_text()).is_equal("No power")
	await _driver.hold(&"use", 2)
	await _driver.frames(1)

	assert_str(_hud.message_label.text).is_equal("No power")


func test_the_hud_shows_no_prompt() -> void:
	await _load()
	var tool := Items.spawn_pickup(_driver.runner.scene(), Items.LOCKPICK, Vector3(0, 0.05, -0.9))
	await _driver.frames(20)
	await _look_at(tool.global_position)
	await _driver.frames(2)
	assert_str(_player.interactor.prompt).is_equal("E: pick up Lockpick")

	assert_object(_hud.get_node_or_null(^"Prompt")).is_null()
	# (The hidden losing overlay's "E: restart level" is not an interaction prompt.)
	for node in _hud.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree():
			assert_str(label.text).override_failure_message(str(node.get_path())).not_contains("E: ")


# A static box (world layer) named `node_name` with a visible mesh, centred at `at`.
func _box(parent: Node, node_name: String, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.4
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = box.size
	mesh.mesh = cube
	body.add_child(mesh)
	parent.add_child(body)
	body.global_position = at
	return body


## A usable available only while its entity's Powered is on (like a computer).
class DeadWithoutPower:
	extends Usable

	func available(_user: Node) -> bool:
		var power := Powered.of(get_parent())
		return power == null or power.on


func _look_at(target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, target))
	await _driver.frames(3)
	_frame.refresh(_player)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_hud = _player.get_node("Hud") as Hud
	_frame = _hud.target_frame
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
