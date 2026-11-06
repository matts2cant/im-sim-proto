class_name MovementNoiseRules
extends RefCounted
## Pure noise math for character movement. Loudness unit = audible distance in metres (ADR 0032).

enum Stance { WALK, SPRINT, CROUCH }

const STANCE_NAMES: Dictionary[Stance, StringName] = {
	Stance.WALK: &"walk",
	Stance.SPRINT: &"sprint",
	Stance.CROUCH: &"crouch",
}


static func stance_name(stance: Stance) -> StringName:
	return STANCE_NAMES[stance]


## Stance from the stance tags: crouching wins over sprinting.
static func stance_of(crouching: bool, sprinting: bool) -> Stance:
	if crouching:
		return Stance.CROUCH
	if sprinting:
		return Stance.SPRINT
	return Stance.WALK


static func stride(stance: Stance, config: MovementNoiseConfig) -> float:
	match stance:
		Stance.SPRINT:
			return config.sprint_stride
		Stance.CROUCH:
			return config.crouch_stride
		_:
			return config.walk_stride


static func base_loudness(stance: Stance, config: MovementNoiseConfig) -> float:
	match stance:
		Stance.SPRINT:
			return config.sprint_loudness
		Stance.CROUCH:
			return config.crouch_loudness
		_:
			return config.walk_loudness


static func footstep_loudness(stance: Stance, surface: StringName, config: MovementNoiseConfig) -> float:
	return base_loudness(stance, config) * config.surfaces.multiplier(surface)


## Loudness of a touchdown at `impact_speed` (downward, m/s); 0 when below the noise threshold.
static func landing_loudness(impact_speed: float, surface: StringName, config: MovementNoiseConfig) -> float:
	if impact_speed < config.landing_min_impact_speed:
		return 0.0
	var factor := clampf(impact_speed / config.landing_reference_speed, 1.0, config.landing_max_factor)
	return config.landing_loudness * factor * config.surfaces.multiplier(surface)


## Playback volume for a noise: 0 dB at the reference loudness, 10 dB per decade, clamped.
static func volume_db(loudness: float, config: MovementNoiseConfig) -> float:
	if loudness <= 0.0:
		return config.audio_min_db
	var db := 10.0 * log(loudness / config.audio_reference_loudness) / log(10.0)
	return clampf(db, config.audio_min_db, config.audio_max_db)
