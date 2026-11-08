class_name TurretModel
extends RefCounted
## Pure engagement timing of a turret (ADR 0079). IDLE: watching. When its meter is full and it sees
## the target it winds up (WINDUP, `windup_time`), then fires in bursts (FIRING: `burst_time` firing,
## `pause_time` pausing, again). Out of sight for `lose_time` it stops (back to IDLE). No scene tree.

enum State { IDLE, WINDUP, FIRING }

## Float slack on the timers (sums of 1/60 s ticks).
const EPSILON: float = 0.0001

var config: TurretConfig
var state: State = State.IDLE
## Seconds left of the wind-up, or of the current burst or pause.
var phase_left: float = 0.0
## FIRING: true during a burst, false during a pause.
var bursting: bool = false
## Seconds since the target was last seen (WINDUP, FIRING).
var unseen_time: float = 0.0


func _init(p_config: TurretConfig) -> void:
	config = p_config


## Advances `delta` seconds. `seen`: the target is in sight this tick; `alert`: the meter is full.
## Returns true on the tick it stops because the target was lost.
func step(delta: float, seen: bool, alert: bool) -> bool:
	if state == State.IDLE:
		if seen and alert:
			state = State.WINDUP
			phase_left = config.windup_time
			unseen_time = 0.0
		return false
	unseen_time = 0.0 if seen else unseen_time + delta
	if unseen_time >= config.lose_time - EPSILON:
		stop()
		return true
	phase_left -= delta
	if phase_left > EPSILON:
		return false
	if state == State.WINDUP:
		state = State.FIRING
		bursting = true
		phase_left += config.burst_time
	else:
		bursting = not bursting
		phase_left += config.burst_time if bursting else config.pause_time
	return false


## True while it may pull the trigger (a burst is on).
func may_fire() -> bool:
	return state == State.FIRING and bursting


func is_engaged() -> bool:
	return state != State.IDLE


func stop() -> void:
	state = State.IDLE
	phase_left = 0.0
	bursting = false
	unseen_time = 0.0


## Cone half-angle in degrees at `distance` m: spread_base + spread_per_metre x metres beyond
## spread_from.
static func spread_deg(p_config: TurretConfig, distance: float) -> float:
	return p_config.spread_base + p_config.spread_per_metre * maxf(distance - p_config.spread_from, 0.0)
