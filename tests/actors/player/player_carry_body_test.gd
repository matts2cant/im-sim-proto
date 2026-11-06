extends GdUnitTestSuite
## Integration: the player carries downed characters (ADR 0071) in the carry room
## (tests/objects/fixtures/carry_room.tscn). A guard lies across the view (along +X), 1 m ahead
## of the player's feet, its torso straight ahead (within the 2 m reach of the eyes): E on its
## torso picks it up (a 15 kg carry mass within the unaugmented 20 kg); it is a ghost while held
## (body and hitboxes off every layer, its controller paused); Q drops it on the floor, still
## downed; it is saved held or dropped.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")
const GUARD_SCENE: PackedScene = preload("res://actors/guard/guard.tscn")
const BODY_FEET := Vector3(-1.2, 0, -1.0)

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_a_conscious_guard_is_not_offered() -> void:
	await _load()
	var guard := _guard([&"actor.guard"])
	await _driver.frames(5)
	assert_bool(PlayerCarry.can_offer(guard)).is_false()
	ActorState.set_tag(guard, ActorState.UNCONSCIOUS, true)
	assert_bool(PlayerCarry.can_offer(guard)).is_true()
	assert_float(Carryable.mass_of(guard)).is_less(_player.carry.mass_limit())


func test_pick_up_carry_and_drop_a_downed_guard() -> void:
	await _load()
	var guard := _guard([&"actor.guard", &"state.unconscious"])
	# DownedPose tips the figure and hitboxes over 0.5 s (a tween): aim once it lies still.
	await _driver.frames(60)
	await _aim_at_torso(guard)
	assert_int(_player.interactor.kind).is_equal(Interactor.Kind.CARRY)

	await _driver.hold(&"use", 2)
	assert_object(_player.carry.held).is_same(guard)
	assert_int(guard.collision_layer).is_equal(0)
	assert_int(guard.collision_mask).is_equal(0)
	for box in Hitboxes.of(guard).boxes():
		assert_int(box.collision_layer).is_equal(0)
	assert_bool(guard.is_physics_processing()).is_false()
	assert_float(_player.carry.speed_factor()).is_equal_approx(0.6, 0.001)

	await _driver.hold(&"move_forward", 40)
	await _driver.frames(20)
	# The middle of the body sits at the hold point (half-extent 0.9 m: 1.8 m long lying down).
	var middle := PerceptionSensor.center_of(guard)
	assert_float(middle.distance_to(CarryRules.hold_point(_player.eye_transform(), 0.9, CONFIG))).is_less(0.01)

	await _driver.hold(&"drop_throw", 2)
	assert_bool(_player.carry.is_carrying()).is_false()
	assert_int(guard.collision_layer).is_equal(PhysicsLayers.ACTORS)
	assert_bool(guard.is_physics_processing()).is_true()
	assert_int(Hitboxes.of(guard).boxes()[0].collision_layer).is_equal(PhysicsLayers.HITBOXES)
	await _driver.frames(90)
	# On the floor, still down, in front of where the player stands.
	assert_float(guard.global_position.y).is_equal_approx(0.0, 0.05)
	assert_bool(ActorState.has(guard, ActorState.UNCONSCIOUS)).is_true()
	assert_bool((guard.get_node("DownedPose") as DownedPose).is_down).is_true()
	assert_float(guard.global_position.z).is_less(_player.global_position.z)


func test_a_dropped_body_stays_down_in_place_after_save_and_load() -> void:
	var room := await _room()
	var player := room.get_node("Player") as Player
	var guard := _spawn_guard(room, [&"actor.guard", &"state.unconscious"])
	await Objects.frames(get_tree(), 10)
	player.carry.pick_up(guard)
	await Objects.frames(get_tree(), 20)
	assert_bool(player.carry.drop()).is_true()
	await Objects.frames(get_tree(), 90)
	var dropped_at := guard.global_position
	assert_float(dropped_at.y).is_equal_approx(0.0, 0.05)

	var fresh := await _reload(room)
	var copy := fresh.get_node("Downed") as NavWalker
	await Objects.frames(get_tree(), 30)
	assert_float(copy.global_position.distance_to(dropped_at)).is_less(0.05)
	assert_bool(ActorState.has(copy, ActorState.UNCONSCIOUS)).is_true()
	assert_bool((copy.get_node("DownedPose") as DownedPose).is_down).is_true()


func test_a_body_saved_while_carried_loads_downed_and_lands_on_the_floor() -> void:
	var room := await _room()
	var player := room.get_node("Player") as Player
	var guard := _spawn_guard(room, [&"actor.guard", &"state.unconscious"])
	await Objects.frames(get_tree(), 10)
	player.carry.pick_up(guard)
	await Objects.frames(get_tree(), 20)
	var held_at := guard.global_position
	assert_float(held_at.y).is_greater(0.2)

	var fresh := await _reload(room)
	var copy := fresh.get_node("Downed") as NavWalker
	assert_int(copy.collision_layer).is_equal(PhysicsLayers.ACTORS)
	await Objects.frames(get_tree(), 90)
	assert_float(copy.global_position.y).is_equal_approx(0.0, 0.05)
	assert_float(Vector2(copy.global_position.x - held_at.x, copy.global_position.z - held_at.z).length()).is_less(0.1)
	assert_bool(ActorState.has(copy, ActorState.UNCONSCIOUS)).is_true()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()


func _guard(tags: Array[StringName]) -> NavWalker:
	return _spawn_guard(_driver.runner.scene(), tags)


## A guard named "Downed" with `tags` under `parent`, lying along +X from BODY_FEET when downed.
static func _spawn_guard(parent: Node, tags: Array[StringName]) -> NavWalker:
	var guard := GUARD_SCENE.instantiate() as NavWalker
	guard.name = "Downed"
	(guard.get_node("Tags") as Tags).initial_tags = tags
	guard.position = BODY_FEET
	guard.rotation.y = PI * 0.5
	parent.add_child(guard)
	return guard


## The carry room outside a scene runner (so it can be freed and loaded again).
func _room() -> Node3D:
	var packed: PackedScene = load(ROOM)
	var room := packed.instantiate() as Node3D
	add_child(room)
	await Objects.frames(get_tree(), 5)
	return room


func _aim_at_torso(guard: Node3D) -> void:
	var torso := Hitboxes.of(guard).box(&"torso") as Node3D
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, torso.global_position))
	await _driver.frames(5)
	EventLog.clear()


## Captures `room`, frees it and restores the snapshot onto a fresh instance (returned).
func _reload(room: Node3D) -> Node3D:
	var snapshot := LevelSnapshot.capture(room)
	room.free()
	StimulusSystem.clear()
	var packed: PackedScene = load(ROOM)
	var fresh := packed.instantiate() as Node3D
	add_child(fresh)
	auto_free(fresh)
	await Objects.frames(get_tree(), 2)
	LevelSnapshot.apply(fresh, snapshot)
	return fresh
