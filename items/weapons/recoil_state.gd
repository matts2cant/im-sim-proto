class_name RecoilState
extends RefCounted
## Pure recoil of one WeaponHolder (ADR 0123): the climb `offset` in degrees (x to the right, y up)
## that every shot adds to (RecoilConfig: a pattern step or a kick, plus noise) and that returns to
## zero by itself after firing stops. `heat` is how far into the pattern the next shot is; it decays
## with the climb, so a burst after a short pause starts part-way along the pattern again.

## Climb (degrees) below which the return snaps to zero.
const SNAP_DEG: float = 0.01

## Current climb: degrees right (x) and up (y).
var offset: Vector2 = Vector2.ZERO
## Shots into the pattern (fractional while it returns); the next shot uses step floor(heat).
var heat: float = 0.0
## Seconds since the last shot.
var since_shot: float = INF
## Share (0-1) of the climb the eye's owner turns the eye by (view_recoil(): the player's camera,
## scaled by the camera motion setting); the shots get the rest (unfollowed()). 0: nobody turns.
var view_share: float = 0.0
var rng := RandomNumberGenerator.new()

# The part of the climb the eye's owner was last told to turn the eye by (view_recoil()).
var _view_applied := Vector2.ZERO
# Seconds left of a scope blackout after a scoped shot, and its length.
var _blackout_left: float = 0.0
var _blackout_time: float = 0.0


func _init(p_seed: int = 0) -> void:
	if p_seed != 0:
		rng.seed = p_seed
	else:
		rng.randomize()


## One shot of a weapon with `config`: adds its climb step (x `size_mult`) and noise (x
## `noise_mult`) to the offset. Returns the step added.
func add_shot(config: RecoilConfig, size_mult: float = 1.0, noise_mult: float = 1.0) -> Vector2:
	var step := Vector2.ZERO
	if config.has_pattern():
		step = config.pattern_step(floori(heat))
	else:
		step = Vector2(rng.randf_range(-1.0, 1.0) * config.kick_side_deg, config.kick_up_deg)
	step *= config.pattern_scale * size_mult
	var noise := config.noise_deg * noise_mult
	if noise > 0.0:
		step += Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * noise
	offset += step
	heat = floorf(heat) + 1.0
	since_shot = 0.0
	return step


## Advances `delta` seconds: once `recover_delay` has passed since the last shot, the climb and the
## heat decay with time constant `recover_time` x `recover_mult`.
func step(delta: float, config: RecoilConfig, recover_mult: float = 1.0) -> void:
	since_shot += delta
	_blackout_left = maxf(_blackout_left - delta, 0.0)
	if offset == Vector2.ZERO and heat == 0.0:
		return
	if config == null:
		reset()
		return
	if since_shot < config.recover_delay:
		return
	var time := config.recover_time * recover_mult
	var keep := exp(-delta / time) if time > 0.0 else 0.0
	offset *= keep
	heat *= keep
	if offset.length() < SNAP_DEG:
		reset()


## Back to rest at once (a level start, tests).
func reset() -> void:
	offset = Vector2.ZERO
	heat = 0.0


## The climb the eye's owner should turn the eye by now (degrees, x right, y up): `view_share` of
## it. Owners that call this every tick turn the eye by exactly what it returns (the player's
## camera); unfollowed() is the rest, which the shots add.
func view_recoil() -> Vector2:
	_view_applied = offset * clampf(view_share, 0.0, 1.0)
	return _view_applied


## The part of the climb the eye has not turned by (degrees): the shots and the reticle add it.
func unfollowed() -> Vector2:
	return offset - _view_applied


## Starts a scope blackout of `time` seconds (a scoped shot).
func black_out(time: float) -> void:
	_blackout_time = time
	_blackout_left = time


## The scope blackout now: 1 right after the shot, fading to 0 (HUD).
func blackout() -> float:
	return _blackout_left / _blackout_time if _blackout_time > 0.0 else 0.0


## The climb a whole spray of `shots` would add without noise (x `size_mult`): what a player who
## learned the pattern pulls against.
static func pattern_climb(config: RecoilConfig, shots: int, size_mult: float = 1.0) -> Vector2:
	var total := Vector2.ZERO
	for i in shots:
		total += config.pattern_step(i)
	return total * config.pattern_scale * size_mult
