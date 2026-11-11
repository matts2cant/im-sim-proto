extends RefCounted
## Test helper (not a suite): loads the security showcase (security_showcase.tscn, its root 200 m
## west of the origin so leftovers of other suites never come into view; showcase-local coordinates)
## in a scene runner. Back wall face at z -8 (x -12..24); on it: Console (-6, 1.45, a computer), Switch (-4, 1.6,
## circuit `showcase_net`), Controller (-2.5, 1.5), Siren (-1, 2.6), Camera (4, 2.6) facing +Z
## (lens about 0.47 m out, 2.47 m up). Turret at (8, 0, -3) facing +X (eye 1.21 m up, 0.27 m in
## front of its pivot). A door (door.tscn) at (-10.5, 0, -3) in a partition wall across x -12..-8.4
## (it slides +X). The switch carries console, camera, turret, controller, siren and door. Lamps on
## circuit `showcase_lights` light the camera spot (4, 0, -1.5) (6 m in front of the lens, 0 degrees)
## and the turret spot (14.3, 0, -3) (6 m in front of its eye). The datapad on the desk carries the
## console's login (`showcase_console`: "jmercer:falcon7"; its account in its DeviceAccounts).

const SHOWCASE := "res://tests/objects/fixtures/showcase/security_showcase.tscn"
const TIME_FACTOR := 9.0
## 6 m in front of the camera's lens, on its rest axis.
const CAMERA_SPOT := Vector3(4, 0, -1.5)
## 6 m in front of the turret's eye, on its rest axis.
const TURRET_SPOT := Vector3(14.3, 0, -3)

var runner: GdUnitSceneRunner
var scene: Node3D
var player: Player


func setup(p_runner: GdUnitSceneRunner) -> void:
	runner = p_runner
	runner.set_time_factor(TIME_FACTOR)
	scene = runner.scene() as Node3D
	player = scene.get_node("Player") as Player
	player.input_enabled = false
	player.reload_on_reset = false
	await frames(6)
	EventLog.clear()


func node(path: String) -> Node3D:
	return scene.get_node(path) as Node3D


func device(path: String) -> Device:
	return Device.of(node(path))


func camera() -> SecurityCamera:
	return SecurityCamera.of(node("Camera"))


func turret() -> Turret:
	return Turret.of(node("Turret"))


func computer() -> Computer:
	return Computer.of(node("Console"))


## A showcase-local point in world space.
func at(local: Vector3) -> Vector3:
	return scene.to_global(local)


## Puts the player at showcase-local `local` facing `yaw` and lets it land.
func place_player(local: Vector3, yaw: float = 0.0) -> void:
	player.load_state({"position": at(local), "yaw": yaw, "pitch": 0.0, "crouched": false, "velocity": Vector3.ZERO})
	await frames(4)


func frames(count: int) -> void:
	for i in count:
		await scene.get_tree().physics_frame


func seconds(value: float) -> void:
	await frames(roundi(value * 60.0))


## Sends `command` straight at `path`'s device, as the debug panel does (no network reach).
func command(command_type: StringName, path: String) -> void:
	StimulusSystem.emit(Device.command_stimulus(command_type, node(path)))
	await frames(2)


## Waits up to `limit` seconds for an EventLog entry of `kind`; returns the seconds waited, or -1.
func wait_for(kind: StringName, limit: float) -> float:
	for tick in roundi(limit * 60.0):
		if not EventLog.find(kind).is_empty():
			return tick / 60.0
		await frames(1)
	return -1.0 if EventLog.find(kind).is_empty() else limit
