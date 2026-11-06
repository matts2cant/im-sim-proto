class_name ImpactSettings
extends Resource
## Shared impact tuning for physics objects (`objects/components/impact_settings.tres`).
## loudness = clamp(speed x sqrt(mass) x loudness_factor, min, max) x material multiplier;
## blunt damage = kinetic energy (0.5 m v^2) / damage_divisor, to itself and to what it hit.

## Impacts slower than this (m/s, along the contact normal) are silent.
@export var min_speed: float
@export var loudness_factor: float
@export var min_loudness: float
@export var max_loudness: float
@export var damage_divisor: float
## Minimum seconds between two impact events of one object.
@export var throttle: float
## Loudness (after the material multiplier) from which the medium / heavy sounds play.
@export var medium_loudness: float
@export var heavy_loudness: float
## Loudness that plays at 0 dB; 10 dB per decade, clamped.
@export var audio_reference_loudness: float
@export var audio_min_db: float
@export var audio_max_db: float
