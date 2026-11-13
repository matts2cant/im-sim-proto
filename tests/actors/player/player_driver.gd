extends RefCounted
## Test helper (not a suite): drives the Player of a GdUnit scene runner with simulated input
## actions over a fixed number of physics frames. Physics delta stays 1/60 s with the time factor.

const TIME_FACTOR := 4.0
const FRAME := 1.0 / 60.0

var runner: GdUnitSceneRunner
var player: Player


func _init(p_runner: GdUnitSceneRunner) -> void:
	runner = p_runner
	runner.set_time_factor(TIME_FACTOR)
	player = runner.find_child("Player") as Player


## Lets CSG build its (deferred) collision before the test starts.
func settle() -> void:
	await frames(5)


## Puts the player at rest at `position` facing `yaw` (0 = -Z), lets it land, then clears the log.
func place(position: Vector3, yaw: float = 0.0) -> void:
	player.load_state(state(position, yaw))
	await frames(5)
	EventLog.clear()


func hold(action: StringName, count: int) -> void:
	runner.simulate_action_press(action)
	await frames(count)
	runner.simulate_action_release(action)


## A tap: holds `action` for 2 physics frames, then waits 1 (the action's handler has run).
func press(action: StringName) -> void:
	await hold(action, 2)
	await frames(1)


func frames(count: int) -> void:
	for i in count:
		await player.get_tree().physics_frame


static func state(position: Vector3, yaw: float) -> Dictionary:
	return {"position": position, "yaw": yaw, "pitch": 0.0, "crouched": false, "velocity": Vector3.ZERO}


## Distance covered in `count` frames from rest, accelerating at `acceleration` up to `speed`.
static func ramped_distance(speed: float, acceleration: float, count: int) -> float:
	return speed * count * FRAME - speed * (speed / acceleration) * 0.5
