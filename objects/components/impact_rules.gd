class_name ImpactRules
extends RefCounted
## Pure impact formulas (see ImpactSettings).


## Loudness in audible metres of an impact at `speed` m/s by a body of `mass` kg.
static func loudness(speed: float, mass: float, material_multiplier: float, settings: ImpactSettings) -> float:
	var base := clampf(
		speed * sqrt(maxf(mass, 0.0)) * settings.loudness_factor, settings.min_loudness, settings.max_loudness
	)
	return base * material_multiplier


## Blunt damage: kinetic energy / divisor.
static func damage(speed: float, mass: float, settings: ImpactSettings) -> float:
	return 0.5 * mass * speed * speed / settings.damage_divisor


## 0 light, 1 medium, 2 heavy.
static func tier(p_loudness: float, settings: ImpactSettings) -> int:
	if p_loudness >= settings.heavy_loudness:
		return 2
	if p_loudness >= settings.medium_loudness:
		return 1
	return 0


static func volume_db(p_loudness: float, settings: ImpactSettings) -> float:
	var ratio := maxf(p_loudness, 0.001) / settings.audio_reference_loudness
	return clampf(10.0 * log(ratio) / log(10.0), settings.audio_min_db, settings.audio_max_db)
