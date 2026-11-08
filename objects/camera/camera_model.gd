class_name CameraModel
extends RefCounted
## Pure sweep and pan of a security camera (ADR 0079). `yaw` is the turn from the rest yaw in
## degrees (positive: left, as seen from the camera). Sweeping, it turns at `sweep_speed` between
## -half and +half and holds `sweep_hold` seconds at each end; a pan step stops the sweep and turns
## it `pan_step` degrees, clamped to the same range; resume_sweep() carries on from where it points.
## No scene tree.

## Float slack on the timers (sums of 1/60 s ticks).
const EPSILON: float = 0.0001

var config: SecurityCameraConfig
var yaw: float = 0.0
## +1: turning left, -1: turning right.
var direction: float = 1.0
## Seconds left of the hold at an end.
var hold_left: float = 0.0
var sweeping: bool = true


func _init(p_config: SecurityCameraConfig) -> void:
	config = p_config


## Advances the sweep `delta` seconds; `paused` (a target in view) keeps it where it points.
func step(delta: float, paused: bool = false) -> void:
	if not sweeping or paused:
		return
	if hold_left > EPSILON:
		hold_left = maxf(hold_left - delta, 0.0)
		return
	var half := config.sweep_half_angle
	yaw += direction * config.sweep_speed * delta
	if yaw >= half - EPSILON:
		yaw = half
		direction = -1.0
		hold_left = config.sweep_hold
	elif yaw <= -half + EPSILON:
		yaw = -half
		direction = 1.0
		hold_left = config.sweep_hold


## Stops the sweep and turns `steps` pan steps (positive: left), clamped to the sweep range.
func pan(steps: int) -> void:
	sweeping = false
	hold_left = 0.0
	yaw = clampf(yaw + steps * config.pan_step, -config.sweep_half_angle, config.sweep_half_angle)


func stop_sweep() -> void:
	sweeping = false
	hold_left = 0.0


func resume_sweep() -> void:
	sweeping = true


func to_dict() -> Dictionary:
	return {"yaw": yaw, "direction": direction, "hold": hold_left, "sweeping": sweeping}


func from_dict(data: Dictionary) -> void:
	yaw = float(data.get("yaw", yaw))
	direction = float(data.get("direction", direction))
	hold_left = float(data.get("hold", hold_left))
	sweeping = bool(data.get("sweeping", sweeping))
