class_name AimModel
extends RefCounted
## Pure aiming model (ADR 0048): the spread cone in degrees widens at once when the floor rises
## (moving, jumping, arm injury), grows with mouse look and shots, and relaxes exponentially back
## to the floor with time constant `settle_time` (snapping onto it within 0.005 degrees). Shots land
## uniformly inside the current cone (disk sampling) from a seedable RandomNumberGenerator. The HUD
## reticle draws the same cone.

enum Stance { STILL, CROUCH_STILL, WALK, SPRINT, AIR }

## Excess spread (degrees) below which the cone snaps to its floor: the exponential decay would
## otherwise approach it forever and the reticle would never be exactly the settled cone.
const SNAP_DEG: float = 0.005

var config: AimConfig
## Current spread: half-angle of the cone in degrees.
var spread: float = 0.0
var rng := RandomNumberGenerator.new()

var _time: float = 0.0


func _init(p_config: AimConfig, p_seed: int = 0) -> void:
	config = p_config
	spread = config.base_min_deg
	if p_seed != 0:
		rng.seed = p_seed
	else:
		rng.randomize()


## The spread the cone settles to in `stance`, plus `spread_add` (arm injuries), capped at max.
func floor_for(stance: Stance, spread_add: float = 0.0) -> float:
	var base := config.base_min_deg
	match stance:
		Stance.CROUCH_STILL:
			base *= config.crouch_still_factor
		Stance.WALK:
			base += config.walk_add_deg
		Stance.SPRINT:
			base += config.sprint_add_deg
		Stance.AIR:
			base += config.air_add_deg
	return minf(base + spread_add, config.max_spread_deg)


## Advances `delta` seconds toward `floor_deg`: below it the cone snaps up to it, above it the
## excess decays by exp(-delta / settle_time).
func step(delta: float, floor_deg: float) -> void:
	_time += delta
	if spread - floor_deg <= SNAP_DEG or config.settle_time <= 0.0:
		spread = floor_deg
		return
	spread = floor_deg + (spread - floor_deg) * exp(-delta / config.settle_time)


## Mouse look bloom for one physics frame's worth of movement (`pixels` moved in total).
func add_look(pixels: float) -> void:
	var bloom := minf(absf(pixels) * config.look_bloom_per_px, config.look_bloom_max_per_frame)
	spread = minf(spread + bloom, config.max_spread_deg)


func add_shot() -> void:
	spread = minf(spread + config.shot_bloom_deg, config.max_spread_deg)


## A shot direction uniformly inside the cone around -Z of `basis` (sampled on the disk at unit
## distance: radius tan(spread) x sqrt(u), angle 2 pi v).
func sample_direction(basis: Basis) -> Vector3:
	var radius := tan(deg_to_rad(spread)) * sqrt(rng.randf())
	var angle := rng.randf() * TAU
	var offset := basis.x.normalized() * cos(angle) + basis.y.normalized() * sin(angle)
	return (-basis.z.normalized() + offset * radius).normalized()


## Aim sway now, in degrees (x: yaw to the right, y: pitch up), scaled by `sway_mult`.
func sway(sway_mult: float = 1.0) -> Vector2:
	var phase := TAU * config.sway_frequency * _time
	return Vector2(sin(phase), sin(phase * 2.0) * 0.5) * config.sway_deg * sway_mult


## `basis` turned by a sway offset in degrees (yaw right, pitch up).
static func swayed(basis: Basis, offset_deg: Vector2) -> Basis:
	var turned := basis.rotated(basis.y.normalized(), -deg_to_rad(offset_deg.x))
	return turned.rotated(turned.x.normalized(), deg_to_rad(offset_deg.y))


## Screen radius in pixels of a cone of `spread_deg` for a camera with vertical `fov_deg` on a
## viewport `height` pixels tall: tan(spread) / tan(fov / 2) x height / 2.
static func reticle_radius(spread_deg: float, fov_deg: float, height: float) -> float:
	return tan(deg_to_rad(spread_deg)) / tan(deg_to_rad(fov_deg) * 0.5) * height * 0.5


## Angle in degrees between a shot direction and the -Z axis of `basis`.
static func angle_off(basis: Basis, direction: Vector3) -> float:
	return rad_to_deg((-basis.z).angle_to(direction))
