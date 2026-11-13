extends GdUnitTestSuite
## Integration: picking up, carrying, putting down, dropping and throwing objects (Carrier,
## ADR 0053). Ghosting, upright turn and safe release: player_carry_ghost_test.gd.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")
const CARRY: CarryConfig = preload("res://actors/common/carry/carry.tres")

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_pick_up_carry_and_put_down() -> void:
	await _load()
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 0.3, -1.5))
	await _place_aiming(Vector3.ZERO, crate.global_position)

	await _driver.hold(&"use", 2)
	assert_object(_player.carry.held).is_same(crate)
	assert_array(Objects.logged(&"carry.picked_up", "object", "SmallCrate")).has_size(1)
	await _driver.frames(30)
	# Ghost: frozen kinematic, no layer or mask, exactly at the hold point (0.75 m for a 0.6 m crate).
	assert_float(crate.global_position.distance_to(_hold_point(0.3))).is_less(0.001)
	assert_bool(crate.freeze).is_true()
	assert_int(crate.collision_layer).is_equal(0)
	assert_int(crate.collision_mask).is_equal(0)

	await _driver.hold(&"move_forward", 40)
	await _driver.frames(20)
	assert_float(_player.global_position.z).is_less(-1.0)
	assert_float(crate.global_position.distance_to(_hold_point(0.3))).is_less(0.001)

	await _driver.hold(&"use", 2)
	assert_bool(_player.carry.is_carrying()).is_false()
	assert_array(Objects.logged(&"carry.dropped", "how", &"put_down")).has_size(1)
	assert_bool(crate.freeze).is_false()
	assert_int(crate.collision_layer).is_equal(PhysicsLayers.OBJECTS)
	assert_int(crate.collision_mask).is_equal(PhysicsLayers.OBJECT_MASK)
	await _driver.frames(90)
	# Landed upright on the floor.
	assert_float(crate.global_position.y).is_equal_approx(0.3, 0.05)
	assert_float(crate.global_basis.y.dot(Vector3.UP)).is_greater(0.99)


func test_drop_key_lets_go() -> void:
	await _load()
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 0.3, -1.5))
	await _place_aiming(Vector3.ZERO, crate.global_position)
	await _driver.hold(&"use", 2)

	await _driver.hold(&"drop_throw", 2)

	assert_bool(_player.carry.is_carrying()).is_false()
	assert_array(Objects.logged(&"carry.dropped", "how", &"drop")).has_size(1)


func test_throw_speed_is_impulse_over_mass() -> void:
	await _load()
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 0.3, -1.5))
	await _place_aiming(Vector3.ZERO, crate.global_position)
	await _driver.hold(&"use", 2)
	await _driver.frames(20)
	_player.look(Vector2(0, _player.pitch / CONFIG.mouse_sensitivity))

	_driver.runner.simulate_action_press(&"fire")
	await _driver.frames(2)
	var velocity := crate.linear_velocity
	_driver.runner.simulate_action_release(&"fire")
	assert_int(crate.collision_layer).is_equal(PhysicsLayers.OBJECTS)

	var thrown := Objects.logged(&"carry.threw", "object", "SmallCrate")
	assert_array(thrown).has_size(1)
	assert_float(thrown[0].data["speed"]).is_equal_approx(4.0, 0.0001)
	assert_bool(_player.carry.is_carrying()).is_false()
	# One physics step after the throw: 4 m/s forward (-Z), gravity has just started.
	assert_float(Vector2(velocity.x, velocity.z).length()).is_equal_approx(4.0, 0.05)
	assert_float(velocity.z).is_less(-3.9)


func test_too_heavy_object_is_refused() -> void:
	await _load()
	var crate := _spawn(Objects.METAL_CRATE, Vector3(0, 0.4, -1.5))
	await _place_aiming(Vector3.ZERO, crate.global_position)

	await _driver.hold(&"use", 2)

	assert_bool(_player.carry.is_carrying()).is_false()
	var refused := Objects.logged(&"carry.pickup_refused", "object", "MetalCrate")
	assert_array(refused).has_size(1)
	assert_float(refused[0].data["mass"]).is_equal(25.0)
	assert_float(refused[0].data["limit"]).is_equal(20.0)


func test_carry_limit_comes_from_the_attribute() -> void:
	await _load()
	var crate := _spawn(Objects.METAL_CRATE, Vector3(0, 0.4, -1.5))
	await _place_aiming(Vector3.ZERO, crate.global_position)
	var attributes := _player.get_node("Attributes") as Attributes
	attributes.attribute_set.add_modifier(Modifier.create(&"carry_mass_limit", Modifier.Op.ADD, 10.0, &"test"))

	await _driver.hold(&"use", 2)

	assert_float(_player.carry.mass_limit()).is_equal(30.0)
	assert_object(_player.carry.held).is_same(crate)


func test_heavy_load_slows_walking() -> void:
	await _load()
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 0.3, -1.5))
	await _place_aiming(Vector3.ZERO, crate.global_position)
	await _driver.hold(&"use", 2)

	_driver.runner.simulate_action_press(&"move_back")
	await _driver.frames(60)
	var speed := _player.horizontal_speed()
	_driver.runner.simulate_action_release(&"move_back")

	assert_float(speed).is_equal_approx(CONFIG.walk_speed * CARRY.heavy_carry_speed_factor, 0.01)


func test_no_mantle_while_carrying() -> void:
	await _load()
	# The ledge (1.5 m) face is at z = -1 in front of x = 8.
	await _driver.place(Vector3(8, 0, -0.4))
	var box := _spawn(Objects.CARDBOARD_BOX, Vector3(8, 1.4, -0.2))
	_player.carry.pick_up(box)

	await _driver.hold(&"jump", 30)
	await _driver.frames(40)

	assert_array(EventLog.find(&"player.mantled")).is_empty()
	assert_bool(_player.carry.is_carrying()).is_true()
	assert_float(_player.global_position.y).is_less(0.5)


func test_carrying_a_burning_object_hurts_the_carrier() -> void:
	await _load()
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 1.35, -1.2))
	_player.carry.pick_up(crate)
	await _driver.frames(2)
	EventLog.clear()

	Flammable.of(crate).ignite(null)
	await _driver.frames(3)

	# The carrier gets damage.fire 2.0 CONTACT per pulse, split evenly over the six body parts.
	var contact := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["shape"] == "contact" and entry.target == "Player"
	)
	assert_array(contact).has_size(1)
	assert_str(contact[0].data["type"]).is_equal("damage.fire")
	var id: int = contact[0].data["id"]
	var hurt := Objects.logged(&"actor.damaged", "by", id)
	assert_array(hurt).has_size(6)
	for entry in hurt:
		assert_str(entry.target).is_equal("Player")
		assert_float(entry.data["amount"]).is_equal_approx(2.0 / 6.0, 0.0001)
	assert_float(_player.body.health(&"torso")).is_less(100.0)


func test_held_object_follows_the_hold_point_instead_of_dropping() -> void:
	await _load()
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 1.25, -0.75))
	_player.carry.pick_up(crate)
	await _driver.frames(2)

	# Knocked far away (formerly a "stuck" drop): it is simply placed back at the hold point.
	crate.global_position = Vector3(0, 0.3, 5)
	await _driver.frames(2)

	assert_bool(_player.carry.is_carrying()).is_true()
	assert_float(crate.global_position.distance_to(_hold_point(0.3))).is_less(0.001)
	assert_array(EventLog.find(&"carry.dropped")).is_empty()


func test_picking_up_the_bottom_crate_drops_the_one_on_top() -> void:
	# 2-crate column; settled long enough to sleep (ADR 0055): the top crate lands on the floor.
	await _load()
	var bottom := _spawn(Objects.SMALL_CRATE, Vector3(0, 0.3, -1.5))
	var top := _spawn(Objects.SMALL_CRATE, Vector3(0, 0.9, -1.5))
	await _driver.frames(120)
	assert_bool(top.sleeping).is_true()
	await _place_aiming(Vector3.ZERO, bottom.global_position)

	await _driver.hold(&"use", 2)
	assert_object(_player.carry.held).is_same(bottom)
	await _driver.frames(90)

	assert_float(top.global_position.y).is_equal_approx(0.3, 0.05)


# The base 20 kg carry limit (Combat Strength is off by default).
func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()


func _spawn(path: String, position: Vector3) -> RigidBody3D:
	return Objects.spawn(_driver.runner.scene(), path, position) as RigidBody3D


func _place_aiming(feet: Vector3, target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, feet, target))
	await _driver.frames(5)
	EventLog.clear()


func _hold_point(half_extent: float) -> Vector3:
	return CarryRules.hold_point(_player.eye_transform(), half_extent, CARRY)
