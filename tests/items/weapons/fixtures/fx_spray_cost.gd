extends Node3D
## Measurement helper (not a test, ADR 0126): the frame cost of the shot feedback during a 30-round
## assault rifle spray at the shooting range's spray wall in the hub. The player stands on the
## firing line in lane 5 and holds the trigger; it measures the physics and process frame times
## (Performance monitors) over a second of idle, then over the spray, prints a MEASURED line and
## quits. Run it twice, `-- fx=on` and `-- fx=off` (off: the holder's ShotFeedback replaced by one
## that does nothing), to isolate the effects' share:
## tools/run_windowed.sh 60 --path . res://tests/items/weapons/fixtures/fx_spray_cost.tscn -- fx=on


## A ShotFeedback that leaves nothing (the `fx=off` run).
class SilentFeedback:
	extends ShotFeedback

	func shot(
		_data: WeaponData, _muzzle: Vector3, _ends: Array[Vector3], _hits: Array[Dictionary], _every: int
	) -> void:
		rounds += 1


## The real ShotFeedback, timing each shot's effects (the `fx=on` run).
class TimedFeedback:
	extends ShotFeedback

	var usec: int = 0
	var slowest: int = 0

	func shot(data: WeaponData, muzzle: Vector3, ends: Array[Vector3], hits: Array[Dictionary], every: int) -> void:
		var start := Time.get_ticks_usec()
		super.shot(data, muzzle, ends, hits, every)
		var spent := Time.get_ticks_usec() - start
		usec += spent
		slowest = maxi(slowest, spent)


const RIFLE_ITEM: ItemData = preload("res://items/weapons/assault_rifle/assault_rifle_item.tres")
const RIFLE_ROUNDS: ItemData = preload("res://items/rifle_rounds/rifle_rounds.tres")
## Room-local feet and aim (lane 5 of the firing line, the spray wall's mark).
const FEET := Vector3(12.5, 0, -7.45)
const LOOK := Vector3(12.5, 1.4, -18)
const IDLE_START: float = 1.0
const IDLE_END: float = 2.0

var _time: float = 0.0
var _fx_on: bool = true
var _idle_physics: Array[float] = []
var _idle_process: Array[float] = []
var _spray_physics: Array[float] = []
var _spray_process: Array[float] = []
var _spraying: bool = false
var _done: bool = false
var _start_magazine: int = 0

@onready var _room: Node3D = $Hub/ShootingRangeRoom
@onready var _player: Player = $Hub/Player


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "fx=off":
			_fx_on = false
	get_window().size = Vector2i(1152, 648)


func _physics_process(delta: float) -> void:
	_time += delta
	var physics_time := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var process_time := Performance.get_monitor(Performance.TIME_PROCESS)
	if not _spraying:
		_place()
	if _time > 0.3 and not _player.weapons.is_armed():
		_arm()
	if _time >= IDLE_START and _time < IDLE_END:
		_idle_physics.append(physics_time)
		_idle_process.append(process_time)
	elif _time >= IDLE_END and not _spraying:
		_spraying = true
		_player.weapons.settle()
		_start_magazine = _player.weapons.state().magazine
		_player.weapons.trigger()
	elif _spraying and not _done:
		# The trigger kept down: the next shot each cycle (the player's LMB does this in the game).
		_player.weapons.trigger(true)
		_spray_physics.append(physics_time)
		_spray_process.append(process_time)
		var fired := _start_magazine - _player.weapons.state().magazine
		if fired >= 30 or _time > IDLE_END + 6.0:
			_done = true
			_report(fired)


func _arm() -> void:
	var inventory := _player.inventory
	inventory.give(RIFLE_ITEM, 1)
	inventory.give(RIFLE_ROUNDS, 60)
	inventory.hold(inventory.inventory.stacks[0])
	var holder := _player.weapons
	holder.feedback.queue_free()
	holder.feedback = TimedFeedback.new() if _fx_on else SilentFeedback.new()
	holder.add_child(holder.feedback)


func _place() -> void:
	var feet := _room.to_global(FEET)
	var eye := feet + Vector3.UP * _player.config.standing_eye_height
	var to := _room.to_global(LOOK) - eye
	var state := {
		"position": feet,
		"yaw": atan2(-to.x, -to.z),
		"pitch": atan2(to.y, Vector2(to.x, to.z).length()),
		"crouched": false,
		"velocity": Vector3.ZERO,
	}
	_player.load_state(state)


func _report(fired: int) -> void:
	var fx := ShotFx.in_world(self)
	print(
		(
			(
				"MEASURED fx=%s rounds=%d frames=%d physics idle %.3f ms spray %.3f ms (max %.3f); process idle %.3f ms "
				+ "spray %.3f ms (max %.3f); puffs %s tracers %d holes %d"
			)
			% [
				"on" if _fx_on else "off",
				fired,
				_spray_physics.size(),
				_mean(_idle_physics) * 1000.0,
				_mean(_spray_physics) * 1000.0,
				_spray_physics.max() * 1000.0,
				_mean(_idle_process) * 1000.0,
				_mean(_spray_process) * 1000.0,
				_spray_process.max() * 1000.0,
				fx.puffs_played,
				fx.tracers_started,
				fx.hole_count(),
			]
		)
	)
	var timed := _player.weapons.feedback as TimedFeedback
	if timed != null:
		print(
			(
				"MEASURED effects inside the physics step: %.3f ms per shot (slowest %.3f ms), %.3f ms over the spray"
				% [timed.usec / 1000.0 / maxf(fired, 1.0), timed.slowest / 1000.0, timed.usec / 1000.0]
			)
		)
	get_tree().quit()


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(values.size(), 1.0)
