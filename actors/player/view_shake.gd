class_name ViewShake
extends RefCounted
## Pure camera shake of a first-person view (ADR 0128): add() starts a short wobble of `amplitude`
## degrees in a random direction (mostly up, a little sideways and rolled) that oscillates at
## FREQUENCY_HZ and dies out over `time` seconds; a shake still stronger than a new one keeps
## running. offset() is the turn now in degrees: x right, y up, z roll (to the left). The player
## turns its camera by it, scaled by the camera motion setting, and the shots take it back out
## (WeaponHolder.eye_shake).

const FREQUENCY_HZ: float = 18.0

var rng := RandomNumberGenerator.new()

var _amplitude: float = 0.0
var _time: float = 0.0
var _age: float = 0.0
var _direction := Vector3.ZERO
var _offset := Vector3.ZERO


func _init(p_seed: int = 0) -> void:
	if p_seed != 0:
		rng.seed = p_seed
	else:
		rng.randomize()


## Starts a shake of `amplitude` degrees lasting `time` seconds, unless the one running is stronger
## now.
func add(amplitude: float, time: float) -> void:
	if amplitude <= 0.0 or time <= 0.0 or remaining() >= amplitude:
		return
	_amplitude = amplitude
	_time = time
	_age = 0.0
	_direction = Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.6, 1.0), rng.randf_range(-0.6, 0.6)).normalized()
	_offset = _direction * _amplitude


## Advances `delta` seconds.
func step(delta: float) -> void:
	if _time <= 0.0:
		return
	_age += delta
	if _age >= _time:
		_time = 0.0
		_amplitude = 0.0
		_offset = Vector3.ZERO
		return
	_offset = _direction * remaining() * cos(TAU * FREQUENCY_HZ * _age)


## The shake's turn now: degrees right (x), up (y) and rolled left (z).
func offset() -> Vector3:
	return _offset


## The running shake's envelope now (degrees; 0 when none).
func remaining() -> float:
	if _time <= 0.0:
		return 0.0
	var left := 1.0 - _age / _time
	return _amplitude * left * left
