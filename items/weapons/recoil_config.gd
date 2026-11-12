class_name RecoilConfig
extends Resource
## One weapon's recoil (ADR 0120, ADR 0123), read by RecoilState. Angles in degrees: x to the right,
## y up. An automatic weapon climbs along a fixed `pattern` (one step per shot, learnable: the
## player pulls against it) plus random `noise_deg`; a semi-automatic one (empty pattern) kicks up
## by `kick_up_deg` and sideways by up to `kick_side_deg` per shot. The climb returns by itself:
## `recover_delay` seconds after the last shot it decays exponentially with time constant
## `recover_time`. The shooter's attributes scale it (`<class>_recoil_size_mult`,
## `<class>_recoil_noise_mult`, `<class>_recoil_recover_mult`: the Weapons skills, ADR 0061).
## Every number is an @export_range so the shooting range's sliders can list them generically.

## Per-shot climb of an automatic weapon, shot 1 first (the first shot itself flies straight: its
## step moves the aim for shot 2). Empty: a semi-automatic kick.
@export var pattern: PackedVector2Array = PackedVector2Array()
## After the last step the pattern repeats from this index.
@export_range(0, 60, 1) var loop_from: int = 0
## The whole pattern (or kick) times this.
@export_range(0.0, 3.0, 0.05) var pattern_scale: float = 1.0
## Semi-automatic kick per shot: up, and sideways (random between -side and +side).
@export_range(0.0, 10.0, 0.05) var kick_up_deg: float = 0.0
@export_range(0.0, 5.0, 0.05) var kick_side_deg: float = 0.0
## Random noise per shot on each axis (uniform in -noise..+noise), on top of the pattern or kick.
@export_range(0.0, 2.0, 0.01) var noise_deg: float = 0.0
## Seconds after the last shot before the climb starts to return (an automatic weapon's spray keeps
## climbing between shots).
@export_range(0.0, 1.0, 0.01) var recover_delay: float = 0.0
## Time constant (s) of the return once it starts: 95 % back after three of them.
@export_range(0.01, 1.0, 0.01) var recover_time: float = 0.1
## Seconds the scope view blacks out after a scoped shot (fading out); 0: none.
@export_range(0.0, 1.0, 0.01) var scope_blackout_time: float = 0.0


## The climb step of shot `index` (0 = the first shot) before scaling, for an automatic weapon's
## pattern (looping from `loop_from` past its end); zero without a pattern.
func pattern_step(index: int) -> Vector2:
	if pattern.is_empty():
		return Vector2.ZERO
	if index < pattern.size():
		return pattern[maxi(index, 0)]
	var start := clampi(loop_from, 0, pattern.size() - 1)
	var span := pattern.size() - start
	return pattern[start + (index - pattern.size()) % span]


func has_pattern() -> bool:
	return not pattern.is_empty()
