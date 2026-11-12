class_name CombatModel
extends RefCounted
## Pure combat timing and accuracy of one fighter (ADR 0070), no scene tree: CombatBehaviour feeds
## it whether the target is in sight and how fast it moves, and asks when it may attack, how wide
## its aim cone is and which way to move to keep its preferred range.
## - Reaction: `seen_time` (sight of the target during this engagement) must reach reaction_time.
## - Rate: after each shot a random pause in [shot_interval_min, shot_interval_max]; an automatic
##   weapon fires a burst of burst_length() shots first.
## - Lost: out of sight for lose_grace ends the engagement.
## - Flinch (a hit taken, HitReaction, ADR 0127): while `flinching` it does not fire and the pause
##   before the next shot does not run down, so the next shot comes that much later.
## - Accuracy (cone half-angle, degrees): spread_deg(), added to the weapon's own cone.

enum Move { HOLD, ADVANCE, RETREAT }

const MOVE_NAMES: Array[String] = ["hold", "advance", "retreat"]

var config: CombatConfig
## Seconds of sight of the target in this engagement.
var seen_time: float = 0.0
## Seconds the target has been seen standing still (the aim settles).
var settle: float = 0.0
## Seconds until the next shot is allowed.
var shot_wait: float = 0.0
## Seconds since the target was last seen.
var unseen_time: float = 0.0
## Smoothed speed of the target (m/s).
var target_speed: float = 0.0
## The fighter is flinching from a hit this tick (step()).
var flinching: bool = false
var rng := RandomNumberGenerator.new()


func _init(p_config: CombatConfig, seed_value: int = 0) -> void:
	config = p_config
	rng.seed = seed_value


## A new engagement: reaction, settle and timers start again.
func begin() -> void:
	seen_time = 0.0
	settle = 0.0
	shot_wait = 0.0
	unseen_time = 0.0
	target_speed = 0.0
	flinching = false


## One tick. `seen`: the target is in sight now; `raw_speed`: its speed measured this tick;
## `p_flinching`: the fighter flinches from a hit (the shot pause holds).
func step(delta: float, seen: bool, raw_speed: float, p_flinching: bool = false) -> void:
	flinching = p_flinching
	if not flinching:
		shot_wait = maxf(shot_wait - delta, 0.0)
	if not seen:
		unseen_time += delta
		settle = 0.0
		return
	unseen_time = 0.0
	seen_time += delta
	var blend := 1.0 - exp(-delta / maxf(config.target_speed_smoothing, 0.001))
	target_speed = lerpf(target_speed, raw_speed, blend)
	if target_speed < config.still_target_speed:
		settle += delta
	else:
		settle = 0.0


## True once the reaction time has passed.
func reacted() -> bool:
	return seen_time >= config.reaction_time


## True when the reaction is over, the pause after the last shot too, and it is not flinching.
func ready_to_fire() -> bool:
	return reacted() and shot_wait <= 0.0 and not flinching


## A shot (or a burst) went off: the next waits a random interval.
func fired() -> void:
	shot_wait = rng.randf_range(config.shot_interval_min, config.shot_interval_max)


## Shots in the next burst of an automatic weapon: random in [burst_shots_min, burst_shots_max],
## at least 1.
func burst_length() -> int:
	var low := maxi(config.burst_shots_min, 1)
	return rng.randi_range(low, maxi(config.burst_shots_max, low))


## Out of sight long enough to give up the engagement.
func lost() -> bool:
	return unseen_time >= config.lose_grace


## The cone now at a target `distance` metres away.
func spread(distance: float) -> float:
	return spread_deg(config, distance, target_speed, settle)


## Cone half-angle (degrees) at a target `distance` away moving at `speed`, seen still for
## `settled_for` seconds: (base + per_metre x metres beyond near + fast-target add) x the settle
## factor, which falls linearly from 1 to settled_factor over settle_time.
static func spread_deg(p_config: CombatConfig, distance: float, speed: float, settled_for: float) -> float:
	var spread_value := p_config.spread_base_deg
	spread_value += p_config.spread_per_metre * maxf(distance - p_config.spread_near_distance, 0.0)
	if speed > p_config.fast_target_speed:
		spread_value += p_config.fast_target_add_deg
	var progress := clampf(settled_for / maxf(p_config.settle_time, 0.001), 0.0, 1.0)
	return spread_value * lerpf(1.0, p_config.settled_factor, progress)


## Which way to move to keep the preferred range: out of [min, max] it moves, and keeps moving
## (`current`) until `distance_margin` inside the band.
static func range_move(p_config: CombatConfig, distance: float, current: Move) -> Move:
	if distance > p_config.max_distance:
		return Move.ADVANCE
	if distance < p_config.min_distance:
		return Move.RETREAT
	if current == Move.ADVANCE and distance > p_config.max_distance - p_config.distance_margin:
		return Move.ADVANCE
	if current == Move.RETREAT and distance < p_config.min_distance + p_config.distance_margin:
		return Move.RETREAT
	return Move.HOLD
