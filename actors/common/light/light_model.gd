class_name LightModel
extends RefCounted
## Pure logic of the light level (ADR 0065): how lit an entity is, from its body sample points and
## the lights that reach them. No scene access: LightExposure gathers the lights (as Sources) and
## answers the shadow-ray question through a Callable.
##
## Per light and point: energy x colour luminance x Godot's own distance attenuation (range window
## times distance^-decay) x the spot cone factor, 0 when the shadow ray is blocked. Per point:
## 1 - exp(-gain x sum), so lights add up but saturate. Level: ambient + (1 - ambient) x the
## weighted average of the points.


## One light as the model sees it (world space).
class Source:
	extends RefCounted
	var position: Vector3 = Vector3.ZERO
	## light_energy x light_color luminance.
	var energy: float = 1.0
	var light_range: float = 5.0
	## Godot's omni_attenuation / spot_attenuation (distance exponent; 1 by default).
	var decay: float = 1.0
	var is_spot: bool = false
	## Spot: unit direction the light points (-Z of the light).
	var direction: Vector3 = Vector3.FORWARD
	## Spot: half-angle of the cone in degrees (spot_angle).
	var spot_angle: float = 45.0
	## Spot: spot_angle_attenuation (cone edge exponent).
	var spot_angle_attenuation: float = 1.0

	static func omni(p_position: Vector3, p_energy: float, p_range: float, p_decay: float = 1.0) -> Source:
		var source := Source.new()
		source.position = p_position
		source.energy = p_energy
		source.light_range = p_range
		source.decay = p_decay
		return source

	static func spot(
		p_position: Vector3,
		p_direction: Vector3,
		p_energy: float,
		p_range: float,
		p_angle: float,
		p_decay: float = 1.0,
		p_angle_attenuation: float = 1.0,
	) -> Source:
		var source := omni(p_position, p_energy, p_range, p_decay)
		source.is_spot = true
		source.direction = p_direction.normalized()
		source.spot_angle = p_angle
		source.spot_angle_attenuation = p_angle_attenuation
		return source


## Godot's omni/spot distance attenuation (the forward renderer's get_omni_attenuation()):
## (1 - (d / range)^4)^2 x d^-decay, 0 at and beyond the range.
static func attenuation(distance: float, light_range: float, decay: float = 1.0) -> float:
	if light_range <= 0.0 or distance >= light_range:
		return 0.0
	var nd := distance / light_range
	nd *= nd
	nd *= nd
	var window := maxf(1.0 - nd, 0.0)
	return window * window * pow(maxf(distance, 0.0001), -decay)


## Godot's spot cone factor for a point in direction `to_point` (from the light): 1 on the axis,
## falling to 0 at the cone edge (`angle` degrees from the axis), 0 outside.
static func spot_factor(direction: Vector3, to_point: Vector3, angle: float, angle_attenuation: float = 1.0) -> float:
	var cone_cos := cos(deg_to_rad(clampf(angle, 0.01, 180.0)))
	var scos := maxf(direction.normalized().dot(to_point.normalized()), cone_cos)
	if is_equal_approx(cone_cos, 1.0):
		return 0.0
	var rim := maxf(0.0001, (1.0 - scos) / (1.0 - cone_cos))
	return maxf(1.0 - pow(rim, angle_attenuation), 0.0)


## What `source` adds at `point`, before shadows (0 out of range or outside a spot cone).
static func contribution(source: Source, point: Vector3) -> float:
	var offset := point - source.position
	var distance := offset.length()
	var value := source.energy * attenuation(distance, source.light_range, source.decay)
	if value <= 0.0:
		return 0.0
	if source.is_spot:
		value *= spot_factor(source.direction, offset, source.spot_angle, source.spot_angle_attenuation)
	return value


## Light at one point from the summed contributions, in [0, 1): 1 - exp(-gain x sum).
static func point_level(irradiance: float, gain: float) -> float:
	return 1.0 - exp(-gain * maxf(irradiance, 0.0))


## Ambient plus the weighted average of the point levels (missing weights count 1).
static func combine(point_levels: PackedFloat32Array, weights: PackedFloat32Array, ambient: float) -> float:
	var total := 0.0
	var weight_sum := 0.0
	for i in point_levels.size():
		var weight := weights[i] if i < weights.size() else 1.0
		total += weight * point_levels[i]
		weight_sum += weight
	var lit := total / weight_sum if weight_sum > 0.0 else 0.0
	return clampf(ambient + (1.0 - ambient) * lit, 0.0, 1.0)


## World sample points at `heights` above `feet` along `up`.
static func sample_points(feet: Vector3, heights: PackedFloat32Array, up: Vector3 = Vector3.UP) -> PackedVector3Array:
	var points := PackedVector3Array()
	for height in heights:
		points.append(feet + up * height)
	return points


## The light level of `points` lit by `sources`. `visible` is called as
## visible.call(source_index, point_index) -> bool for contributions above 0 only (the shadow ray);
## an invalid Callable means nothing is shadowed.
static func level(
	sources: Array[Source],
	points: PackedVector3Array,
	weights: PackedFloat32Array,
	ambient: float,
	gain: float,
	visible: Callable = Callable(),
) -> float:
	var levels := PackedFloat32Array()
	for p in points.size():
		var sum := 0.0
		for s in sources.size():
			var value := contribution(sources[s], points[p])
			if value <= 0.0:
				continue
			if visible.is_valid() and not bool(visible.call(s, p)):
				continue
			sum += value
		levels.append(point_level(sum, gain))
	return combine(levels, weights, ambient)
