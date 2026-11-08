extends GdUnitTestSuite
## Integration: the player walks across downed guards (ADR 0082) in the carry room
## (tests/objects/fixtures/carry_room.tscn). The guard lies along +X from its feet at (-0.9, 0, 0)
## (yaw 90 degrees), its middle on the player's path along -Z at x = 0; the lying capsule is 0.71 m
## high (above the 0.35 m step, below a mantle), so before the fix the player stopped against it.
## The player starts 2.5 m (centre to centre) in front of the body and walks 90 frames at 4 m/s
## (about 5.8 m: z = -3.3; the wall face is at z = -5.8). A woken guard blocks again.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const GUARD_SCENE: PackedScene = preload("res://actors/guard/guard.tscn")
const BODY_FEET := Vector3(-0.9, 0, 0)
const PLAYER_START := Vector3(0, 0, 2.5)
const WALK_FRAMES: int = 90

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_the_player_walks_across_a_dead_guard() -> void:
	await _load()
	var guard := _guard(BODY_FEET, [&"actor.guard", &"state.dead"])
	await _driver.frames(40)
	assert_int(guard.collision_layer).is_equal(PhysicsLayers.DOWNED)
	await _walk()
	assert_float(_player.global_position.z).is_less(-2.5)
	assert_float(_player.global_position.y).is_equal_approx(0.0, 0.05)
	# The body stayed where it fell, on the floor.
	assert_float(guard.global_position.y).is_equal_approx(0.0, 0.05)
	assert_float(guard.global_position.distance_to(BODY_FEET)).is_less(0.05)


func test_the_player_walks_across_an_unconscious_guard() -> void:
	await _load()
	_guard(BODY_FEET, [&"actor.guard", &"state.unconscious"])
	await _driver.frames(40)
	await _walk()
	assert_float(_player.global_position.z).is_less(-2.5)


func test_a_woken_guard_blocks_the_player_again() -> void:
	await _load()
	# Feet on the player's line, facing -X: standing, it is in the way and does not see the player
	# coming from +Z (90 degrees off, outside its cones).
	var guard := _guard(Vector3.ZERO, [&"actor.guard", &"state.unconscious"])
	await _driver.frames(40)
	assert_int(guard.collision_layer).is_equal(PhysicsLayers.DOWNED)
	assert_bool(BodyParts.of(guard).revive("Test")).is_true()
	await _driver.frames(3)
	assert_int(guard.collision_layer).is_equal(PhysicsLayers.ACTORS)
	await _walk()
	# Stopped against it: about z = 0.7 (two 0.35 m radii, centre to centre).
	assert_float(_player.global_position.z).is_greater(0.5)


func test_weapon_and_interaction_rays_still_hit_a_downed_guard_where_it_lies() -> void:
	await _load()
	var guard := _guard(BODY_FEET, [&"actor.guard", &"state.dead"])
	await _driver.frames(60)
	var torso := (Hitboxes.of(guard).box(&"torso") as Node3D).global_position
	var space := guard.get_world_3d().direct_space_state
	for mask: int in [PhysicsLayers.WEAPON_MASK, PhysicsLayers.INTERACT_MASK]:
		var query := PhysicsRayQueryParameters3D.create(torso + Vector3.UP * 1.5, torso + Vector3.DOWN, mask)
		var hit := space.intersect_ray(query)
		assert_bool(hit.is_empty()).is_false()
		assert_object(Interactor.entity_of(hit["collider"] as Node)).is_same(guard)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()
	await _driver.place(PLAYER_START)


func _walk() -> void:
	await _driver.hold(&"move_forward", WALK_FRAMES)


## A guard with `tags` at `feet`, facing -X (it falls onto +X when downed).
func _guard(feet: Vector3, tags: Array[StringName]) -> NavWalker:
	var guard := GUARD_SCENE.instantiate() as NavWalker
	guard.name = "Downed"
	(guard.get_node("Tags") as Tags).initial_tags = tags
	guard.position = feet
	guard.rotation.y = PI * 0.5
	_driver.runner.scene().add_child(guard)
	return guard
