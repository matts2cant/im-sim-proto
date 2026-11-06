class_name MantleRules
extends RefCounted
## Pure mantle rules (ADR 0035): decides from probe results whether a ledge can be climbed,
## whether the player ends crouched, how long it takes and where the player is along the way.


## What PlayerProbe found in front of the player.
class Probe:
	extends RefCounted
	var found: bool = false
	## Ledge top above the feet.
	var height: float = 0.0
	## Ledge top above the ground the player last stood on (a jump neither extends the maximum nor lowers the minimum).
	var rise: float = 0.0
	## Horizontal distance from the capsule axis to the ledge face.
	var distance: float = 0.0
	## Feet position on top of the ledge where the mantle ends.
	var end_position: Vector3 = Vector3.ZERO
	## A standing (or crouched) capsule can rise, move over the ledge and fit at the end.
	var standing_clear: bool = false
	var crouched_clear: bool = false


## A scripted mantle move: rise vertically to the ledge top, then move horizontally onto it.
class Plan:
	extends RefCounted
	var start: Vector3
	var end: Vector3
	var height: float
	var end_crouched: bool
	var duration: float


## Tolerance on the height limits so a ledge of exactly the limit is not lost to float noise.
const HEIGHT_TOLERANCE: float = 0.01


static func in_range(height: float, rise: float, distance: float, config: PlayerConfig) -> bool:
	return (
		height > 0.0
		and rise >= config.mantle_min_height - HEIGHT_TOLERANCE
		and height <= config.mantle_max_height + HEIGHT_TOLERANCE
		and rise <= config.mantle_max_height + HEIGHT_TOLERANCE
		and distance <= config.mantle_reach
	)


static func duration(height: float, config: PlayerConfig) -> float:
	return config.mantle_base_duration + config.mantle_duration_per_metre * height


## Returns a plan, or null when the ledge cannot be mantled.
static func evaluate(probe: Probe, start: Vector3, config: PlayerConfig) -> Plan:
	if probe == null or not probe.found or not in_range(probe.height, probe.rise, probe.distance, config):
		return null
	if not probe.standing_clear and not probe.crouched_clear:
		return null
	var plan := Plan.new()
	plan.start = start
	plan.end = probe.end_position
	plan.height = probe.height
	plan.end_crouched = not probe.standing_clear
	plan.duration = duration(probe.height, config)
	return plan


## Feet position at normalised time t (0..1): eased, vertical first, then horizontal.
static func position_at(plan: Plan, t: float) -> Vector3:
	var top := Vector3(plan.start.x, plan.end.y, plan.start.z)
	var rise := absf(plan.end.y - plan.start.y)
	var across := top.distance_to(plan.end)
	var total := rise + across
	if total <= 0.0:
		return plan.end
	var travelled := smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0)) * total
	if travelled <= rise:
		return plan.start.lerp(top, travelled / rise)
	return top.lerp(plan.end, (travelled - rise) / across)
