class_name WeaponMotion
extends RefCounted
## Pure first-person weapon motion (ADR 0128): what WeaponView adds to the grip pivot's rest pose,
## from a WeaponMotionConfig. Each physics step takes the shooter's ground speed, whether it stands
## on the ground or crouches, and the reload's progress; shots (kick()), mouse turns (add_turn()),
## draws and holsters come as events. The result is `offset` (metres, camera frame) added to the
## grip's position and `turn` (Euler degrees: pitch up, yaw left, roll left) applied about the grip.
## - Kick: a critically damped spring per shot (peak after `kick_time`), automatic shots stack up to
##   `kick_stack_max`; back, nose up, a roll to a random side.
## - Sway: the model lags mouse turns (`sway_per_deg`, capped) and returns with `sway_return_time`.
## - Bob: footstep dips and a side swing whose phase follows the distance walked and whose size
##   follows the speed (none when still or airborne, smaller crouched).
## - Reload: dips down and out of view over the first `reload_ease_share` of the reload, comes back
##   over the last.
## - Draw: rises from lowered over `draw_time`; a holster lowers it over `holster_time`.

## Added to the grip pivot's position (camera frame, metres).
var offset := Vector3.ZERO
## Euler degrees about the grip (pitch up, yaw left, roll left), applied before the rest pose.
var turn := Vector3.ZERO
## Null: no motion (offset and turn stay zero).
var config: WeaponMotionConfig
var rng := RandomNumberGenerator.new()

# Kick spring: position (in single-shot peaks) and its speed; the roll side of the last shot.
var _kick: float = 0.0
var _kick_speed: float = 0.0
var _kick_side: float = 0.0
# Sway: the lag in screen degrees (x right, y up).
var _sway := Vector2.ZERO
# Bob: phase (radians, one cycle per stride) and size (x the config's bob).
var _bob_phase: float = 0.0
var _bob_amount: float = 0.0
# Reload dip 0..1.
var _dip: float = 0.0
# Raised 0 (lowered) ..1 (ready) and where it is heading: +1 drawing, -1 holstering, 0 still.
var _raised: float = 1.0
var _raise_dir: int = 0


func _init(p_config: WeaponMotionConfig = null, p_seed: int = 0) -> void:
	config = p_config
	if p_seed != 0:
		rng.seed = p_seed
	else:
		rng.randomize()


## Back to the ready pose at once (a new weapon shown).
func reset() -> void:
	_kick = 0.0
	_kick_speed = 0.0
	_sway = Vector2.ZERO
	_bob_amount = 0.0
	_dip = 0.0
	_raised = 1.0
	_raise_dir = 0
	_compose()


## Starts raising the weapon from lowered (it was just drawn).
func start_draw() -> void:
	_raised = 0.0
	_raise_dir = 1
	_compose()


## Starts lowering the weapon (holstered); is_lowered() once it is out of view.
func start_holster() -> void:
	_raise_dir = -1


## A holster's lowering has finished.
func is_lowered() -> bool:
	return _raise_dir < 0 and _raised <= 0.0


## Share (0-1) the weapon is raised: 0 lowered, 1 ready.
func raised() -> float:
	return _raised


## One shot's kick (ranged weapons).
func kick() -> void:
	if config == null:
		return
	# A unit impulse peaks at 1 after kick_time: x(t) = v t e^(-t / T) peaks at v T / e.
	_kick_speed += exp(1.0) / config.kick_time
	_kick_side = rng.randf_range(-1.0, 1.0)


## The view turned by `turn_deg` (degrees, x right, y up) by mouse look: the model lags behind.
func add_turn(turn_deg: Vector2) -> void:
	if config == null:
		return
	_sway = (_sway - turn_deg * config.sway_per_deg).limit_length(config.sway_max_deg)


## Advances `delta` seconds: `speed` is the ground speed (m/s), `grounded` false while airborne,
## `crouched`, `reload_progress` 0..1 through a running reload (negative: none).
func step(delta: float, speed: float, grounded: bool, crouched: bool, reload_progress: float) -> void:
	if config == null:
		return
	_step_kick(delta)
	_sway *= exp(-delta / config.sway_return_time)
	var target := 0.0
	if grounded:
		target = clampf(speed / config.bob_reference_speed, 0.0, config.bob_max_scale)
		if crouched:
			target *= config.bob_crouch_scale
		_bob_phase = fposmod(_bob_phase + speed * delta / config.bob_stride * TAU, TAU)
	_bob_amount += (target - _bob_amount) * (1.0 - exp(-delta / config.bob_ease_time))
	_dip = reload_dip(reload_progress, config.reload_ease_share)
	if _raise_dir > 0:
		_raised = minf(_raised + delta / config.draw_time, 1.0)
		if _raised >= 1.0:
			_raise_dir = 0
	elif _raise_dir < 0:
		_raised = maxf(_raised - delta / config.holster_time, 0.0)
	_compose()


## The kick now, in single-shot peaks (0: at rest).
func kick_amount() -> float:
	return _kick


## The bob's size now (x the config's bob height and side; 1 walking).
func bob_amount() -> float:
	return _bob_amount


## The reload dip now (0: none, 1: at the bottom).
func dip() -> float:
	return _dip


## The sway lag now (screen degrees, x right, y up).
func sway() -> Vector2:
	return _sway


## The dip (0-1) at `progress` (0..1) through a reload whose way down and way up each take
## `share` of it; 0 outside a reload.
static func reload_dip(progress: float, share: float) -> float:
	if progress < 0.0 or progress > 1.0 or share <= 0.0:
		return 0.0
	return minf(smoothstep(0.0, share, progress), 1.0 - smoothstep(1.0 - share, 1.0, progress))


# Exact step of a critically damped spring (natural frequency 1 / kick_time), capped at the stack.
func _step_kick(delta: float) -> void:
	if _kick == 0.0 and _kick_speed == 0.0:
		return
	var omega := 1.0 / config.kick_time
	var decay := exp(-omega * delta)
	var drive := _kick_speed + omega * _kick
	_kick = (_kick + drive * delta) * decay
	_kick_speed = (_kick_speed - omega * drive * delta) * decay
	if _kick > config.kick_stack_max:
		_kick = config.kick_stack_max
		_kick_speed = minf(_kick_speed, 0.0)
	if absf(_kick) < 0.0005 and absf(_kick_speed) < 0.01:
		_kick = 0.0
		_kick_speed = 0.0


func _compose() -> void:
	offset = Vector3.ZERO
	turn = Vector3.ZERO
	if config == null:
		return
	# Kick: back, nose up, roll to the shot's side.
	offset.z += config.kick_back * _kick
	turn.x += config.kick_pitch_deg * _kick
	turn.z += config.kick_roll_deg * _kick * _kick_side
	# Sway: turned and shifted towards the lag (yaw is positive to the left).
	turn.x += _sway.y
	turn.y -= _sway.x
	offset.x += _sway.x * config.sway_shift
	offset.y += _sway.y * config.sway_shift
	# Bob: one side swing and two footstep dips per cycle.
	var swing := sin(_bob_phase)
	offset.x += config.bob_side * _bob_amount * swing
	offset.y -= config.bob_height * _bob_amount * swing * swing
	# Reload: down, nose down, rolled inwards.
	offset.y -= config.reload_drop * _dip
	turn.x -= config.reload_pitch_deg * _dip
	turn.z += config.reload_roll_deg * _dip
	# Draw / holster: lowered and nose down while not raised.
	var lowered := 1.0 - smoothstep(0.0, 1.0, _raised)
	offset.y -= config.draw_drop * lowered
	turn.x -= config.draw_pitch_deg * lowered
