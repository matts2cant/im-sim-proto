class_name PlayerNoiseRules
extends RefCounted
## Pure noise math for player movement. Loudness unit = audible distance in metres (ADR 0032).


static func stride(mode: PlayerMotion.Mode, config: PlayerConfig) -> float:
	match mode:
		PlayerMotion.Mode.SPRINT:
			return config.sprint_stride
		PlayerMotion.Mode.CROUCH:
			return config.crouch_stride
		_:
			return config.walk_stride


static func base_loudness(mode: PlayerMotion.Mode, config: PlayerConfig) -> float:
	match mode:
		PlayerMotion.Mode.SPRINT:
			return config.sprint_loudness
		PlayerMotion.Mode.CROUCH:
			return config.crouch_loudness
		_:
			return config.walk_loudness


static func footstep_loudness(mode: PlayerMotion.Mode, surface: StringName, config: PlayerConfig) -> float:
	return base_loudness(mode, config) * config.surfaces.multiplier(surface)


## Loudness of a touchdown at `impact_speed` (downward, m/s); 0 when below the noise threshold.
static func landing_loudness(impact_speed: float, surface: StringName, config: PlayerConfig) -> float:
	if impact_speed < config.landing_min_impact_speed:
		return 0.0
	var factor := clampf(impact_speed / config.landing_reference_speed, 1.0, config.landing_max_factor)
	return config.walk_loudness * factor * config.surfaces.multiplier(surface)


## Playback volume for a noise: 0 dB at the reference loudness, 10 dB per decade, clamped.
static func volume_db(loudness: float, config: PlayerConfig) -> float:
	if loudness <= 0.0:
		return config.audio_min_db
	var db := 10.0 * log(loudness / config.audio_reference_loudness) / log(10.0)
	return clampf(db, config.audio_min_db, config.audio_max_db)
