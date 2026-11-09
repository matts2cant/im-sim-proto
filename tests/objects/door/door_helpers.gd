extends RefCounted
## Test helper (not a suite): sets up the door fixtures (tests/objects/fixtures/door_wall*.tscn: a
## 20 m wall along z = 0, 0.25 m thick, with a 1.2 x 2.2 m doorway at x = 0 holding `Door`, floor
## 20 x 20, LevelNavigation) with synchronous navigation, and adds locks to a door in code. The
## fixtures stand at ORIGIN, far from the origin, so a late-freed navmesh of theirs never joins
## another suite's (M8a: barrel_chain_test).

const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const WALL := "res://tests/objects/fixtures/door_wall.tscn"
const WALL_PLAYER := "res://tests/objects/fixtures/door_wall_player.tscn"
const WALL_GUARD := "res://tests/objects/fixtures/door_wall_guard.tscn"
## Where the door fixtures stand (door_wall_player / door_wall_guard place it there; suites that
## instance door_wall.tscn themselves move it there before adding it).
const ORIGIN := Vector3(-200, 0, 200)

var _map: RID
var _map_was_async: bool = true


## Synchronous navigation for the region under `scene`, re-baked, other regions switched off.
func sync_navigation(scene: Node) -> void:
	var region := scene.find_child("LevelNavigation", true, false) as LevelNavigation
	_map = region.get_navigation_map()
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(_map)
	await GuardHelpers.use_sync_iterations(_map, region)
	GuardHelpers.isolate_region(_map, region)
	region.bake()
	for i in 3:
		await scene.get_tree().physics_frame


func teardown() -> void:
	if _map.is_valid():
		NavigationServer3D.map_set_use_async_iterations(_map, _map_was_async)


## The scene's door entity (the StaticBody3D named `door_name`).
static func door_entity(scene: Node, door_name: String = "Door") -> StaticBody3D:
	return scene.find_child(door_name, true, false) as StaticBody3D


static func door_of(scene: Node, door_name: String = "Door") -> Door:
	return Door.of(door_entity(scene, door_name))


static func add_keypad(entity: Node, code_id: StringName, code: String) -> KeypadLock:
	var keypad := KeypadLock.new()
	keypad.name = "KeypadLock"
	keypad.data = KeypadLockData.new()
	keypad.data.code_id = code_id
	keypad.data.code = code
	entity.add_child(keypad)
	return keypad


static func add_keycard(entity: Node, access_id: StringName) -> KeycardLock:
	var reader := KeycardLock.new()
	reader.name = "KeycardLock"
	reader.data = KeycardLockData.new()
	reader.data.access_id = access_id
	entity.add_child(reader)
	return reader


static func add_mechanical(entity: Node, pins: int) -> MechanicalLock:
	var lock := MechanicalLock.new()
	lock.name = "MechanicalLock"
	lock.data = MechanicalLockData.new()
	lock.data.pins.clear()
	for i in pins:
		lock.data.pins.append(&"standard")
	entity.add_child(lock)
	return lock


## Locks the door (through its Lockable, so the door updates its link and light).
static func lock(entity: Node) -> void:
	Lockable.of(entity).lock(null, &"test")


static func frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame


## The middle of the front face of the door's wall box `index` (top first) on its front (+Z) or back
## face (world): where to look to use it (ADR 0098).
static func box_point(door: Door, front: bool = true, index: int = 0) -> Vector3:
	var box := door.hardware.controls(front)[index]
	var shape := box.get_node("Shape") as CollisionShape3D
	var depth := (shape.shape as BoxShape3D).size.z
	return box.global_transform * Vector3(0.0, 0.0, depth)


## The DoorControl of the door's wall box `index` on its front or back face.
static func control(door: Door, front: bool = true, index: int = 0) -> DoorControl:
	return Usable.of(door.hardware.controls(front)[index]) as DoorControl
