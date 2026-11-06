extends RefCounted
## Test helper (not a suite): spawns crates and samples them every physics tick for the stacking
## tests: drift from the start position, tilt, peak speed, peak upward speed; plus the player's
## lowest and highest feet height. Call `sample()` once per physics frame (see `frames()`).

const Objects := preload("res://tests/objects/object_test_helpers.gd")
## Half the small crate's edge (0.6 m cube).
const SMALL_HALF := 0.3

var crates: Array[RigidBody3D] = []
var starts: Array[Vector3] = []
var peak_speed: Array[float] = []
var peak_up_speed: Array[float] = []
var player: Player
var player_low: float = INF
var player_high: float = -INF


func _init(p_player: Player = null) -> void:
	player = p_player


## Small crate centred at (x, centre_y, z).
func small(parent: Node, x: float, centre_y: float, z: float) -> RigidBody3D:
	var crate := Objects.spawn(parent, Objects.SMALL_CRATE, Vector3(x, centre_y, z)) as RigidBody3D
	crates.append(crate)
	starts.append(crate.global_position)
	peak_speed.append(0.0)
	peak_up_speed.append(0.0)
	return crate


## Column of `count` small crates standing on the floor at (x, z); returns the top height.
func column(parent: Node, x: float, z: float, count: int) -> float:
	for i in count:
		small(parent, x, SMALL_HALF + i * SMALL_HALF * 2.0, z)
	return count * SMALL_HALF * 2.0


## Restarts drift and peaks from where everything is now.
func reset() -> void:
	for i in crates.size():
		starts[i] = crates[i].global_position
		peak_speed[i] = 0.0
		peak_up_speed[i] = 0.0
	player_low = INF
	player_high = -INF


func sample() -> void:
	for i in crates.size():
		var crate := crates[i]
		if not is_instance_valid(crate):
			continue
		peak_speed[i] = maxf(peak_speed[i], crate.linear_velocity.length())
		peak_up_speed[i] = maxf(peak_up_speed[i], crate.linear_velocity.y)
	if player != null:
		player_low = minf(player_low, player.global_position.y)
		player_high = maxf(player_high, player.global_position.y)


## Waits `count` physics frames, sampling each one.
func frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame
		sample()


func drift(i: int) -> float:
	return crates[i].global_position.distance_to(starts[i])


func max_drift() -> float:
	var worst := 0.0
	for i in crates.size():
		worst = maxf(worst, drift(i))
	return worst


## Angle in degrees between a crate's up axis and world up.
func tilt(i: int) -> float:
	return rad_to_deg(crates[i].global_basis.y.angle_to(Vector3.UP))


func max_tilt() -> float:
	var worst := 0.0
	for i in crates.size():
		worst = maxf(worst, tilt(i))
	return worst


func max_peak_speed() -> float:
	var worst := 0.0
	for speed in peak_speed:
		worst = maxf(worst, speed)
	return worst


func max_end_speed() -> float:
	var worst := 0.0
	for crate in crates:
		worst = maxf(worst, crate.linear_velocity.length())
	return worst


## One line of measurements for the test log (before/after numbers in reports).
func summary(label: String) -> String:
	var line := (
		"%s: drift %.4f tilt %.2f peak %.3f end %.3f"
		% [label, max_drift(), max_tilt(), max_peak_speed(), max_end_speed()]
	)
	if player != null:
		line += " player y %.3f..%.3f" % [player_low, player_high]
	return line
