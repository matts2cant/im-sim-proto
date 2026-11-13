extends RefCounted
## Test helper (not a suite): the real player in the door fixture (tests/objects/fixtures/
## door_wall_player.tscn: a wall along z = 0 at Helpers.ORIGIN, 0.25 m thick, a doorway at x = 0)
## picking locks through its LockpickScreen. Adds a door lock, a practice lock or a minimal lock
## entity (Node3D + Lockable + MechanicalLock, no door) on the wall, and solves a lock through the
## running screen like a careful player (the screen steps the model; the helper only moves the aim,
## as the mouse does, tension held at a set value).

const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const LockpickHelpers := preload("res://tests/objects/locks/lockpicking/lockpick_helpers.gd")
const PRACTICE: PackedScene = preload("res://objects/locks/practice_lock/practice_lock.tscn")
## In front of the door (relative to Helpers.ORIGIN), facing its panel.
const DOOR_FEET := Vector3(0, 0, 1.2)
const DOOR_PANEL := Vector3(0, 1.4, 0)
## A wall-mounted lock 2.5 m right of the doorway at 1.3 m, its front face on the wall's face; the
## player stands 0.9 m in front of it.
const WALL_LOCK := Vector3(2.5, 1.3, 0.125)
const WALL_FEET := Vector3(2.5, 0, 1.0)

var driver: PlayerDriver
var player: Player
var screen: LockpickScreen
var door_entity: StaticBody3D
var door: Door


func setup(runner: GdUnitSceneRunner) -> void:
	driver = PlayerDriver.new(runner)
	player = driver.player
	player.reload_on_reset = false
	screen = LockpickScreen.of(player)
	door_entity = Helpers.door_entity(runner.scene())
	door = Door.of(door_entity)
	await driver.settle()


func teardown() -> void:
	if is_instance_valid(screen):
		screen.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## `count` lockpicks given and one in hand.
func hold_picks(count: int) -> void:
	player.inventory.add(Items.LOCKPICK, count)
	player.inventory.hold(player.inventory.grid.stacks_of(&"lockpick")[0])
	await driver.frames(2)


## Stands at `feet` (relative to the fixture) looking at `target` (relative), then clicks LMB.
func click_at(feet: Vector3, target: Vector3) -> void:
	player.load_state(Objects.aiming_state(player, Helpers.ORIGIN + feet, Helpers.ORIGIN + target))
	await driver.frames(3)
	await driver.hold(&"fire", 2)
	await driver.frames(1)


## A practice lock of `tier` on the wall at WALL_LOCK.
func add_practice(tier: MechanicalLockData.Tier) -> StaticBody3D:
	var lock_body := PRACTICE.instantiate() as StaticBody3D
	var lock := lock_body.get_node("MechanicalLock") as MechanicalLock
	lock.data = lock.data.duplicate() as MechanicalLockData
	lock.data.practice_tier = tier
	lock_body.position = Helpers.ORIGIN + WALL_LOCK
	driver.runner.scene().add_child(lock_body)
	await driver.frames(2)
	return lock_body


## A minimal lock entity (a StaticBody3D box, Lockable locked, MechanicalLock of `pins` standard
## pins) on the wall at WALL_LOCK: no door, no practice.
func add_box_lock(pins: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Locker"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.1)
	shape.shape = box
	shape.position = Vector3(0, 0, 0.05)
	body.add_child(shape)
	var lockable := Lockable.new()
	lockable.name = "Lockable"
	lockable.locked = true
	body.add_child(lockable)
	var lock := Helpers.add_mechanical(body, pins)
	lock.position = Vector3(0, 0, 0.1)
	body.position = Helpers.ORIGIN + WALL_LOCK
	driver.runner.scene().add_child(body)
	await driver.frames(2)
	return body


## Moves the pick to each binding pin in turn and lifts it to its shear line at `tension`, through
## the running screen. True once the lock opens (within `limit` physics frames).
func pick_open(tension: float = 0.45, limit: int = 900) -> bool:
	return await set_pins(1000, tension, limit)


## Like pick_open(), until `count` pins are set (or the lock opens).
func set_pins(count: int, tension: float = 0.45, limit: int = 900) -> bool:
	for i in limit:
		var model := screen.model
		if model == null:
			return false
		if model.opened or model.set_count() >= count:
			return true
		model.tension = tension
		LockpickHelpers.drive(model, model.binding_index())
		await driver.frames(1)
	return false


## Forces the binding pin at high tension until the pick snaps (the binding pin's shear line out of
## reach). True when a pick broke within `limit` frames.
func force_snap(limit: int = 240) -> bool:
	var before := EventLog.find(&"lock.pick_broke").size()
	for i in limit:
		var model := screen.model
		if model == null or EventLog.find(&"lock.pick_broke").size() > before:
			break
		var index := model.binding_index()
		model.pins[index].shear = 0.74
		if not LockpickHelpers.at_pin(model, index):
			LockpickHelpers.drive(model, index)
		else:
			model.tension = 0.9
			model.aim = 1.0
		await driver.frames(1)
	return EventLog.find(&"lock.pick_broke").size() > before


func seconds(value: float) -> void:
	await driver.frames(roundi(value * 60.0))
